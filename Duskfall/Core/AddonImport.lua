-- Duskfall Core/AddonImport.lua: brings settings from other lighting addons into a new Style
-- "From <addon>" (Kim, 2026-11-27). Only the player's own saved data is read, never the addons'
-- code. A saved-variables table only exists while its addon is enabled, so an import has to run
-- before that addon is turned off (UI/Conflict.lua offers it in its dialog).
--
-- Each source turns its data into plain entries:
--   { zone = name, sub = name or "", place = "outdoor" / "indoor" / "instance",
--     time = "dawn" / "day" / "dusk" / "night" or nil, g = gamma, b = brightness, c = contrast }
-- (fixed values; nil = not set), and the shared part does the rest:
--   place     Subzone -> part of a zone, empty -> the zone (by name: Duskfall's places first, then
--             the game's map list); instance -> a dungeon Duskfall has been in (by name)
--   when      outdoor / indoor -> outdoors / indoors, the part of the day as it is
--   values    changes from the player's baseline (simple mode shows them), zero changes left out
-- Entries that match no place are skipped and named in chat.
--
-- Sources: iris (IrisDB.contexts["Zone|Subzone|outdoor/indoor/instance|dawn/day/dusk/night"] =
-- { g, b, c, n, last }). Add more in SOURCES.
-- Public: ns.AddonImport.For(folder) -> source or nil, .Available(src), .Run(src) -> style,
--         matched, skipped; .Use(style); .Report(style, matched, skipped)
local ADDON, ns = ...
local AI = {}
ns.AddonImport = AI

local PERIODS = { dawn = true, day = true, dusk = true, night = true }
local MAX_MAP = 3000   -- the map scan's upper id

-- Sources ----------------------------------------------------------------------------------------
local SOURCES = {
  {
    folder = "Iris", name = "Iris",
    entries = function()
      local db = rawget(_G, "IrisDB")
      if type(db) ~= "table" or type(db.contexts) ~= "table" then return nil end
      local out = {}
      for key, e in pairs(db.contexts) do
        local zone, sub, place, time = tostring(key):match("^(.-)|(.-)|(.-)|(.-)$")
        if zone and type(e) == "table" then
          out[#out + 1] = { zone = zone, sub = sub, place = place, time = time,
                            g = tonumber(e.g), b = tonumber(e.b), c = tonumber(e.c) }
        end
      end
      return out
    end,
  },
}

function AI.For(folder)
  for _, src in ipairs(SOURCES) do
    if src.folder == folder then return src end
  end
end

-- The first source whose data is loaded now (its addon is enabled), or nil.
function AI.FirstAvailable()
  for _, src in ipairs(SOURCES) do
    if AI.Available(src) then return src end
  end
end

function AI.Available(src)
  local list = src and src.entries()
  return list ~= nil and #list > 0
end

-- Places -----------------------------------------------------------------------------------------
local mapByName
local function zoneMap(name)
  -- Duskfall's own places first: those are the maps it really sees
  for key, p in pairs(ns.db.places or {}) do
    local id = key:match("^zone:(%d+)$")
    if id and p.name == name then return tonumber(id) end
  end
  if not mapByName then
    mapByName = {}
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone
    if C_Map and C_Map.GetMapInfo then
      for id = 1, MAX_MAP do
        local info = C_Map.GetMapInfo(id)
        if info and info.name and info.name ~= "" then
          local cur = mapByName[info.name]
          -- A zone map wins over a continent, dungeon floor or the like of the same name
          if not cur or (zoneType and info.mapType == zoneType and cur.type ~= zoneType) then
            mapByName[info.name] = { id = id, type = info.mapType }
          end
        end
      end
    end
  end
  local m = mapByName[name]
  return m and m.id
end

local function instanceKey(name)
  for key, p in pairs(ns.db.places or {}) do
    if key:match("^instance:") and p.name == name then return key end
  end
end

local function round(v, places)
  local m = 10 ^ (places or 0)
  return math.floor(v * m + 0.5) / m
end

-- Import -----------------------------------------------------------------------------------------
function AI.Run(src)
  local list = src and src.entries()
  if not list or #list == 0 then return nil, 0, {} end
  local base = ns.db.baseline or {}
  local st = ns.NewStyle("From " .. src.name)
  st.scope = { chars = {} }   -- not in use until the player says so
  local seen, matched, skipped = {}, 0, {}
  for _, e in ipairs(list) do
    local zone, sub, place, time = e.zone, e.sub or "", e.place, e.time
    local key
    if place == "instance" then
      key = instanceKey(zone)
    else
      local id = zoneMap(zone)
      if id then key = (sub ~= "" and ("sub:" .. id .. ":" .. sub)) or ("zone:" .. id) end
    end
    local name = (sub ~= "" and (sub .. ", " .. zone)) or zone or "?"
    if not key then
      skipped[#skipped + 1] = name
    else
      local when = {}
      if PERIODS[time] then when[#when + 1] = "time:" .. time end
      if place == "indoor" then when[#when + 1] = "indoors" elseif place == "outdoor" then when[#when + 1] = "outdoors" end
      local values = {}
      if e.g and base.gamma then
        local d = round(e.g - base.gamma, 2)
        if d ~= 0 then values.gamma = d end
      end
      if e.b and base.brightness then
        local d = round(e.b - base.brightness)
        if d ~= 0 then values.brightness = d end
      end
      if e.c and base.contrast then
        local d = round(e.c - base.contrast)
        if d ~= 0 then values.contrast = d end
      end
      local shapeKey = key .. "|" .. table.concat(when, ",")
      if next(values) and not seen[shapeKey] then
        seen[shapeKey] = true
        matched = matched + 1
        local label = name
        if place == "indoor" then label = label .. " indoors" elseif place == "outdoor" then label = label .. " outdoors" end
        if PERIODS[time] then label = label .. " (" .. time .. ")" end
        st.looks[#st.looks + 1] = { id = ns.NewID("l"), name = label, on = true, scope = { global = true },
          absolute = false, where = { key }, when = when, values = values }
      end
    end
  end
  if matched == 0 then return nil, 0, skipped end
  table.insert(ns.db.styles, st)
  return st, matched, skipped
end

-- Make st the Style every character uses (as picking it on the Styles tab).
function AI.Use(st)
  for _, o in ipairs(ns.db.styles) do
    if o ~= st and ns.UI.ScopeIsGlobal(o.scope, true) then o.scope = { chars = {} } end
  end
  st.scope = { global = true }
  ns.Detect.state.target = nil
  ns.Detect.Evaluate("style")
end

-- Chat summary, then "Use it now?".
function AI.Report(st, matched, skipped, from)
  if not st then
    ns.Print("nothing from %s could be matched to a place%s.", from or "the other addon",
      #skipped > 0 and (": " .. table.concat(skipped, "; ")) or "")
    return
  end
  ns.Print("imported %d setting%s into the Style \"%s\".", matched, matched == 1 and "" or "s", st.name)
  if #skipped > 0 then ns.Print("skipped (no matching place): %s.", table.concat(skipped, "; ")) end
  ns.UI.Confirm("Use \"" .. st.name .. "\" for every character now?", function() AI.Use(st) end)
end

-- Import, then turn the addon off: the interface reloads, so the summary comes after it.
function AI.RunBeforeReload(src)
  local st, matched, skipped = AI.Run(src)
  ns.db.addonImported = { id = st and st.id, matched = matched, skipped = skipped, from = src.name }
end

ns.Listen("ENABLE", function()
  local pending = ns.db and ns.db.addonImported
  if not pending then return end
  ns.db.addonImported = nil
  local st
  for _, o in ipairs(ns.db.styles) do if o.id == pending.id then st = o end end
  C_Timer.After(3, function() AI.Report(st, pending.matched or 0, pending.skipped or {}, pending.from) end)
end)
