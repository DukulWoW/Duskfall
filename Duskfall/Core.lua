-- Duskfall Core.lua: namespace, events, internal messages, saved variables, migrations,
-- character registry and scope helpers. Everything else builds on this file.
-- Public: ns.On(event, fn), ns.Listen(msg, fn), ns.Fire(msg, ...), ns.Print(fmt, ...),
--         ns.Debug(fmt, ...), ns.NewID(prefix), ns.ScopeOf(scope, guid), ns.CharName(guid),
--         ns.db (DuskfallDB), ns.cfg (DuskfallDB.settings), ns.charKey (player GUID)
-- Messages: READY (saved variables loaded), ENABLE (after PLAYER_LOGIN), EVALUATED (new target),
--           ONOFF (Duskfall switched on or off), MODE (simple / Advanced mode switched)
local ADDON, ns = ...
ns.name = ADDON
-- The TOC's Version line is the one place the version lives
local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata
ns.VERSION = (getMeta and getMeta(ADDON, "Version")) or "?"

local DB_VERSION = 2

ns.DEFAULTS = {
  enabled = true,     -- automatic adjusting on
  debounce = 0.5,     -- seconds a new state must hold before it is applied (doorways)
  clock = "server",   -- "server" (GetGameTime, matches the sky) or "local" (the computer's clock)
  clock24 = true,     -- display only
  buckets = { dawn = 5, day = 8, dusk = 17, night = 20 },   -- the hour each part of the day starts
  timeFade = 45,      -- seconds a change caused only by the clock takes, whatever the mode
  adaptGap = 2,       -- seconds after an Adapt overshoot before the next one may overshoot
  debug = false,
  minimap = { hide = true },    -- LibDBIcon's table (position, hide); hide follows minimapButton
  minimapButton = "auto",       -- "auto" (only when the minimap moon can't be used), "always", "never"
  moon = true,                  -- the minimap's day / night moon opens Duskfall (C-06)
  brokerText = "look",          -- broker bars: "look", "values", "both", "none"
  statusDisplay = "change",     -- floating display: "off", "change", "always"
  statusSeconds = 4,            -- "change": seconds it stays after the change is done
  advanced = false,             -- Places in Advanced mode (full list and Look editor), else simple
  ringGlow = true,              -- the glow ring on the moon badge and minimap button where a setting is in effect
}

-- Output ---------------------------------------------------------------------------------------
local function fmt(s, ...)
  if select("#", ...) == 0 then return tostring(s) end
  local ok, out = pcall(string.format, s, ...)
  if ok then return out end
  return tostring(s)
end

function ns.Print(s, ...)
  print("|cff9fb4ffDuskfall|r " .. fmt(s, ...))
end

function ns.Debug(s, ...)
  if ns.cfg and ns.cfg.debug then print("|cff7f7f7fDuskfall|r " .. fmt(s, ...)) end
end

-- An error inside a handler is printed once per place, never stops the other handlers.
local reported = {}
local function report(where, err)
  if reported[where] then return end
  reported[where] = true
  ns.Print("error in %s: %s", tostring(where), tostring(err))
end

function ns.Safe(fn, where, ...)
  local ok, err = pcall(fn, ...)
  if not ok then report(where, err) end
  return ok
end

-- Events ---------------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local handlers = {}

function ns.On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    if not pcall(frame.RegisterEvent, frame, event) then ns.Debug("unknown event %s", event) end
  end
  local list = handlers[event]
  list[#list + 1] = fn
end

frame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  if not list then return end
  for i = 1, #list do ns.Safe(list[i], event, ...) end
end)

-- Internal messages ----------------------------------------------------------------------------
local listeners = {}

function ns.Listen(msg, fn)
  listeners[msg] = listeners[msg] or {}
  local list = listeners[msg]
  list[#list + 1] = fn
end

function ns.Fire(msg, ...)
  local list = listeners[msg]
  if not list then return end
  for i = 1, #list do ns.Safe(list[i], msg, ...) end
end

-- Helpers --------------------------------------------------------------------------------------
function ns.NewID(prefix)
  ns.db.nextID = (ns.db.nextID or 0) + 1
  return (prefix or "x") .. ns.db.nextID
end

-- How a scope applies to a character: "char" (named), "global", or nil (not for this character).
-- scope = { global = true } or { chars = { [guid] = true } }. A Look scope naming no one counts as
-- Global; with strict (Styles) it means nobody: an unused Style, so two Globals never compete.
function ns.ScopeOf(scope, guid, strict)
  if type(scope) ~= "table" or scope.global then return "global" end
  local chars = scope.chars
  if type(chars) ~= "table" or next(chars) == nil then
    if strict then return nil end
    return "global"
  end
  if guid and chars[guid] then return "char" end
  return nil
end

function ns.CharName(guid)
  local c = ns.db and ns.db.chars[guid]
  return c and c.name or tostring(guid)
end

-- Removes a character from a scope. An emptied Look scope becomes Global; an emptied Style scope
-- (isStyle) stays empty = unused. Returns true when it emptied.
local function dropFromScope(scope, guid, isStyle)
  if type(scope) ~= "table" or type(scope.chars) ~= "table" or not scope.chars[guid] then return false end
  scope.chars[guid] = nil
  if next(scope.chars) == nil then
    if isStyle then return true end
    scope.chars = nil
    scope.global = true
    return true
  end
  return false
end

-- How many Styles and Looks name this character.
function ns.CharUse(guid)
  local styles, looks = 0, 0
  for _, st in ipairs(ns.db.styles) do
    if type(st.scope) == "table" and type(st.scope.chars) == "table" and st.scope.chars[guid] then styles = styles + 1 end
    for _, look in ipairs(st.looks) do
      if type(look.scope) == "table" and type(look.scope.chars) == "table" and look.scope.chars[guid] then looks = looks + 1 end
    end
  end
  return styles, looks
end

-- Forgets a character and strips it from every scope. Returns the number of scopes it emptied,
-- or nil when it is the character being played or unknown.
function ns.RemoveCharacter(guid)
  if not guid or guid == ns.charKey or not ns.db.chars[guid] then return nil end
  local emptied = 0
  for _, st in ipairs(ns.db.styles) do
    if dropFromScope(st.scope, guid, true) then emptied = emptied + 1 end
    for _, look in ipairs(st.looks) do
      if dropFromScope(look.scope, guid) then emptied = emptied + 1 end
    end
  end
  ns.db.chars[guid] = nil
  return emptied
end

function ns.IsGlobalStyle(st)
  return ns.ScopeOf(st.scope, nil, true) == "global"
end

-- Saved variables ------------------------------------------------------------------------------
local function fill(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      fill(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

-- MIGRATIONS[n] upgrades a version n-1 table to version n. Add one with every schema change.
local MIGRATIONS = {}

-- v2 (B-02/B-03, 2026-11-25): transitions exist now. Nobody could pick a mode before, so the old
-- default "instant" becomes the new default "adapt", and the untouched 1.0 s fade becomes 1.5 s.
MIGRATIONS[2] = function(db)
  for _, st in ipairs(db.styles or {}) do
    local tr = st.transition
    if type(tr) == "table" then
      if tr.mode == "instant" then tr.mode = "adapt" end
      if type(tr.fade) == "table" and tr.fade.duration == 1.0 then tr.fade.duration = 1.5 end
    end
  end
end

local function newStyle(name)
  return {
    id = ns.NewID("s"), name = name, scope = { global = true },
    transition = {
      mode = "adapt",
      fade = { duration = 1.5 },
      adapt = { toDark = { duration = 4.0, strength = 0.3 }, toLight = { duration = 1.0, strength = 0.3 } },
    },
    looks = {},
  }
end
ns.NewStyle = newStyle

ns.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  DuskfallDB = DuskfallDB or {}
  local db = DuskfallDB
  ns.db = db
  local from = tonumber(db.version) or DB_VERSION
  for v = from + 1, DB_VERSION do
    if MIGRATIONS[v] then MIGRATIONS[v](db) end
  end
  db.version = DB_VERSION
  db.settings = db.settings or {}
  fill(db.settings, ns.DEFAULTS)
  db.chars = db.chars or {}
  db.places = db.places or {}
  db.lastApplied = db.lastApplied or {}
  db.styles = db.styles or {}
  if #db.styles == 0 then db.styles[1] = newStyle("My Style") end
  ns.cfg = db.settings
  ns.Fire("READY")
end)

-- Characters are keyed by GUID: Forever names carry a surname in the realm slot, so a name is no key.
ns.On("PLAYER_LOGIN", function()
  local guid = UnitGUID("player")
  ns.charKey = guid
  local first, second = UnitName("player")
  local display = first or "?"
  if second and second ~= "" then display = display .. " " .. second end
  local _, class = UnitClass("player")
  if guid then
    local c = ns.db.chars[guid] or {}
    c.name, c.class, c.last = display, class, time()
    ns.db.chars[guid] = c
  end
  ns.Fire("ENABLE")
end)
