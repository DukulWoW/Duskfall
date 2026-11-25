-- Duskfall Slash.lua: /dusk (main), /duskfall, /df.
local ADDON, ns = ...
local C, S, D = ns.Channels, ns.Situations, ns.Detect

local Y = "|cffffd100"   -- command colour
local G = "|cff9d9d9d"   -- grey

local PERIODS = { dawn = true, day = true, dusk = true, night = true }
local KINDS = { sub = true, zone = true, instance = true }

-- Helpers ----------------------------------------------------------------------------------------
local function words(msg)
  local out = {}
  for w in (msg or ""):gmatch("%S+") do out[#out + 1] = w end
  return out
end

local function fmtValue(key, v)
  if v == nil then return "-" end
  return C.Format(key, v)
end

local function fmtOffset(key, v, absolute)
  if absolute then return fmtValue(key, v) end
  local s = C.Format(key, v)
  if v >= 0 then s = "+" .. s end
  return s
end

local function lookLine(i, look)
  local vals = {}
  for _, ch in ipairs(C.list) do
    local v = look.values and look.values[ch.key]
    if v ~= nil then vals[#vals + 1] = (ch.short or ch.label) .. " " .. fmtOffset(ch.key, v, look.absolute) end
  end
  local when = ""
  if look.when and #look.when > 0 then when = " [" .. table.concat(look.when, ", ") .. "]" end
  local off = ""
  if look.on == false then off = G .. " (off)|r" end
  local scope = ""
  if ns.ScopeOf(look.scope) == nil then scope = G .. " (characters)|r" end
  return string.format("%d. %s%s: %s%s%s", i, look.name or "?", when, table.concat(vals, ", "), off, scope)
end

-- "night", "21:00-05:30", "indoors", "!combat" -> situation strings. nil + bad word on error.
local function parseWhen(list, from)
  local out = {}
  for i = from, #list do
    local w = list[i]:lower()
    local neg, bare = "", w
    if w:sub(1, 1) == "!" then neg, bare = "!", w:sub(2) end
    if PERIODS[bare] then
      out[#out + 1] = neg .. "time:" .. bare
    elseif bare:match("^%d%d?:%d%d%-%d%d?:%d%d$") then
      out[#out + 1] = neg .. "time:" .. bare
    elseif S.FLAGS[bare] then
      out[#out + 1] = neg .. bare
    else
      return nil, list[i]
    end
  end
  table.sort(out)
  return out
end

local function sameList(a, b)
  a, b = a or {}, b or {}
  if #a ~= #b then return false end
  local x, y = {}, {}
  for i = 1, #a do x[i] = a[i] end
  for i = 1, #b do y[i] = b[i] end
  table.sort(x)
  table.sort(y)
  for i = 1, #x do if x[i] ~= y[i] then return false end end
  return true
end

-- The Global Look in the style whose Where is exactly { key } and whose When equals `when`.
local function findLook(style, key, when)
  for i, look in ipairs(style.looks) do
    if ns.ScopeOf(look.scope) == "global" and sameList(look.where, { key }) and sameList(look.when, when) then
      return look, i
    end
  end
  return nil
end

local function roundTo(key, v)
  return tonumber(C.Format(key, v))
end

-- Commands ---------------------------------------------------------------------------------------
local function status()
  local st = D.state
  local env = st.env or S.Snapshot()
  local style = ns.Resolver.ActiveStyle()
  local onoff = "|cff40ff40on|r"
  if not ns.cfg.enabled then onoff = "|cffff4040off|r" end
  local tr = style.transition or {}
  ns.Print("%s %s  Style: %s  %s(%s)|r", onoff, G .. ns.VERSION .. "|r", style.name or "?", G, tr.mode or "adapt")
  local place = {}
  if env.instance then place[#place + 1] = string.format("%s (instance %s, %s)", env.instanceName or "?", env.instance, env.itype or "?") end
  if env.zone then place[#place + 1] = string.format("%s (zone %s)", env.zoneName or "?", env.zone) end
  if env.sub then place[#place + 1] = env.sub end
  if #place == 0 then place[1] = "unknown" end
  local flags = {}
  for _, f in ipairs({ "indoors", "resting", "combat", "mounted", "swimming", "underwater", "ghost" }) do
    if env[f] then flags[#flags + 1] = f end
  end
  if not env.indoors then table.insert(flags, 1, "outdoors") end
  flags[#flags + 1] = string.format("%s %02d:%02d", env.period, env.hour, env.min)
  print("  " .. table.concat(place, " > ") .. "  " .. G .. "[" .. table.concat(flags, ", ") .. "]|r")
  local cur = C.ReadAll() or {}
  local base = ns.db.baseline or {}
  for _, ch in ipairs(C.list) do
    local k = ch.key
    local src = st.source and st.source[k]
    local from = "baseline"
    if src then from = "Look \"" .. (src.name or "?") .. "\"" end
    local held = ""
    if st.held[k] ~= nil then held = "  |cffff9f40held at " .. fmtValue(k, st.held[k]) .. "|r" end
    print(string.format("  %s: %s  %s(target %s, base %s, from %s)|r%s", ch.label, fmtValue(k, cur[k]), G,
      fmtValue(k, st.target and st.target[k]), fmtValue(k, base[k]), from, held))
  end
end

local function help()
  ns.Print("commands (%s/dusk|r, %s/duskfall|r, %s/df|r):", Y, Y, Y)
  print("  " .. Y .. "/dusk|r status")
  print("  " .. Y .. "/dusk save sub||zone||instance [when...]|r save the current values here")
  print("    " .. G .. "when: dawn day dusk night, 21:00-05:30, indoors outdoors resting combat mounted swimming underwater ghost; ! in front = not|r")
  print("  " .. Y .. "/dusk clear sub||zone||instance [when...]|r remove that Look")
  print("  " .. Y .. "/dusk looks|r list the Looks of your Style")
  print("  " .. Y .. "/dusk on||off|r automatic adjusting on or off")
  print("  " .. Y .. "/dusk baseline|r make the current values your baseline")
  print("  " .. Y .. "/dusk mode instant||fade||adapt|r how changes happen (this Style)")
  print("  " .. Y .. "/dusk fade <seconds>|r fade time")
  print("  " .. Y .. "/dusk adapt dark||light <seconds> [strength 0-1]|r eye adaptation per direction")
  print("  " .. Y .. "/dusk timefade <seconds>|r time of day changes (all modes)")
  print("  " .. Y .. "/dusk transition|r show the current transition settings")
  print("  " .. Y .. "/dusk style [use <n> || new <name>]|r list, switch or create Styles")
  print("  " .. Y .. "/dusk chars [remove <name>]|r list or remove known characters")
  print("  " .. Y .. "/dusk debug|r debug output on or off")
end

local function save(args)
  local kind = args[2] and args[2]:lower()
  if not KINDS[kind] then ns.Print("which place? %s/dusk save sub||zone||instance|r", Y) return end
  local env = S.Snapshot()
  local key = S.PlaceKey(kind, env)
  if not key then
    if kind == "instance" then ns.Print("you are not in an instance.")
    elseif env.instance then ns.Print("inside instances there is no zone or subzone; use %s/dusk save instance|r.", Y)
    else ns.Print("there is no %s here.", kind) end
    return
  end
  local when, bad = parseWhen(args, 3)
  if not when then ns.Print("unknown condition \"%s\" (see %s/dusk help|r).", bad, Y) return end
  local cur = C.ReadAll()
  local base = ns.db.baseline
  if not cur or not base then ns.Print("no values to save yet.") return end
  local style = ns.Resolver.ActiveStyle()
  local look = findLook(style, key, when)
  local target = D.state.target or base
  local values, n = {}, 0
  for _, ch in ipairs(C.list) do
    local k = ch.key
    local setsIt = look and look.values and look.values[k] ~= nil
    if setsIt or not C.Same(k, cur[k], target[k]) then
      if look and look.absolute then values[k] = roundTo(k, cur[k])
      else values[k] = roundTo(k, cur[k] - base[k]) end
      n = n + 1
    end
  end
  if n == 0 then
    ns.Print("nothing differs from what Duskfall already shows here. Move a slider first.")
    return
  end
  local name = S.PlaceName(kind, env) or key
  if #when > 0 then name = name .. " (" .. table.concat(when, ", ") .. ")" end
  if look then
    look.values = values
    ns.Print("updated Look \"%s\".", look.name or name)
  else
    look = { id = ns.NewID("l"), name = name, on = true, scope = { global = true }, absolute = false,
             where = { key }, when = when, values = values }
    table.insert(style.looks, look)
    ns.Print("saved Look \"%s\" in Style \"%s\".", name, style.name or "?")
  end
  D.ClearHolds()
  D.state.target = nil
  D.Evaluate("save")
end

local function clear(args)
  local kind = args[2] and args[2]:lower()
  if not KINDS[kind] then ns.Print("which place? %s/dusk clear sub||zone||instance|r", Y) return end
  local env = S.Snapshot()
  local key = S.PlaceKey(kind, env)
  if not key then ns.Print("there is no %s here.", kind) return end
  local when, bad = parseWhen(args, 3)
  if not when then ns.Print("unknown condition \"%s\".", bad) return end
  local style = ns.Resolver.ActiveStyle()
  local look, i = findLook(style, key, when)
  if not look then
    ns.Print("no Global Look for exactly this place and these conditions. %s/dusk looks|r lists them.", Y)
    return
  end
  table.remove(style.looks, i)
  ns.Print("removed Look \"%s\".", look.name or key)
  D.ClearHolds()
  D.state.target = nil
  D.Evaluate("clear")
end

local function looks()
  local style = ns.Resolver.ActiveStyle()
  if #style.looks == 0 then ns.Print("Style \"%s\" has no Looks yet. Try %s/dusk save zone|r.", style.name or "?", Y) return end
  ns.Print("Looks in Style \"%s\" (offsets from baseline):", style.name or "?")
  for i, look in ipairs(style.looks) do print("  " .. lookLine(i, look)) end
end

local function styleCmd(args)
  local sub = args[2] and args[2]:lower()
  local styles = ns.db.styles
  local guid = ns.charKey
  if sub == "use" then
    local n = tonumber(args[3])
    local target = n and styles[n]
    if not target then ns.Print("which Style? %s/dusk style|r lists them.", Y) return end
    for _, st in ipairs(styles) do
      if st ~= target and type(st.scope) == "table" and st.scope.chars then st.scope.chars[guid] = nil end
    end
    if not ns.IsGlobalStyle(target) then
      target.scope = type(target.scope) == "table" and target.scope or {}
      target.scope.global = nil
      target.scope.chars = target.scope.chars or {}
      target.scope.chars[guid] = true
    end
    ns.Print("this character now uses Style \"%s\".", target.name or "?")
    D.state.target = nil
    D.Evaluate("style")
    return
  end
  if sub == "new" then
    local name = table.concat(args, " ", 3)
    if name == "" then name = "Style " .. (#styles + 1) end
    local st = ns.NewStyle(name)
    st.scope = { chars = {} }
    if guid then st.scope.chars[guid] = true end
    for _, other in ipairs(styles) do
      if type(other.scope) == "table" and other.scope.chars then other.scope.chars[guid] = nil end
    end
    styles[#styles + 1] = st
    ns.Print("created Style \"%s\" for this character.", name)
    D.state.target = nil
    D.Evaluate("style")
    return
  end
  local active = ns.Resolver.ActiveStyle()
  ns.Print("Styles:")
  for i, st in ipairs(styles) do
    local who
    if ns.IsGlobalStyle(st) then who = "Global"
    else
      local names = {}
      for g in pairs(st.scope.chars or {}) do names[#names + 1] = ns.CharName(g) end
      table.sort(names)
      who = table.concat(names, ", ")
      if who == "" then who = "unused" end
    end
    local mark = "  "
    if st == active then mark = "> " end
    print(string.format("  %s%d. %s %s(%s, %d Looks)|r", mark, i, st.name or "?", G, who, #st.looks))
  end
  print("  " .. G .. "/dusk style use <n>, /dusk style new <name>|r")
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

local function charsCmd(args)
  local chars = ns.db.chars
  if args[2] and args[2]:lower() == "remove" then
    local want = table.concat(args, " ", 3):lower()
    if want == "" then ns.Print("which character? %s/dusk chars|r lists them.", Y) return end
    local found
    for guid, c in pairs(chars) do
      local full = (c.name or ""):lower()
      local first = full:match("^(%S+)") or full
      if full == want or first == want then found = guid break end
    end
    if not found then ns.Print("no known character \"%s\".", want) return end
    if found == ns.charKey then ns.Print("you can't remove the character you are playing.") return end
    local emptied = 0
    for _, st in ipairs(ns.db.styles) do
      if dropFromScope(st.scope, found, true) then emptied = emptied + 1 end
      for _, look in ipairs(st.looks) do
        if dropFromScope(look.scope, found) then emptied = emptied + 1 end
      end
    end
    ns.Print("removed %s.", chars[found].name or "?")
    if emptied > 0 then ns.Print("|cffff9f40%d scope(s) named only that character: those Looks are now Global, those Styles unused.|r", emptied) end
    chars[found] = nil
    D.state.target = nil
    D.Evaluate("chars")
    return
  end
  local list = {}
  for guid, c in pairs(chars) do list[#list + 1] = { guid = guid, c = c } end
  table.sort(list, function(a, b) return (a.c.name or "") < (b.c.name or "") end)
  ns.Print("known characters:")
  for _, e in ipairs(list) do
    local mark = ""
    if e.guid == ns.charKey then mark = G .. " (you)|r" end
    print(string.format("  %s %s(%s, last seen %s)|r%s", e.c.name or "?", G, e.c.class or "?", date("%Y-%m-%d", e.c.last or 0), mark))
  end
  print("  " .. G .. "/dusk chars remove <name>|r")
end

local MODES = { instant = true, fade = true, adapt = true }

local function showTransition()
  local tr = ns.Resolver.ActiveStyle().transition
  local a = tr.adapt
  ns.Print("mode %s; fade %.1fs; adapt to dark %.1fs / %.2f, to light %.1fs / %.2f; time of day %ds; overshoot gap %ds",
    tr.mode, tr.fade.duration, a.toDark.duration, a.toDark.strength, a.toLight.duration, a.toLight.strength,
    ns.cfg.timeFade, ns.cfg.adaptGap)
end

local function transitionCmd(args)
  local cmd = args[1]:lower()
  local tr = ns.Resolver.ActiveStyle().transition
  if cmd == "mode" then
    local m = args[2] and args[2]:lower()
    if not MODES[m] then ns.Print("%s/dusk mode instant||fade||adapt|r", Y) return end
    tr.mode = m
  elseif cmd == "fade" then
    local s = tonumber(args[2])
    if not s or s < 0 or s > 30 then ns.Print("%s/dusk fade <0-30 seconds>|r", Y) return end
    tr.fade.duration = s
  elseif cmd == "adapt" then
    local dir = args[2] and args[2]:lower()
    local key = (dir == "dark" and "toDark") or (dir == "light" and "toLight") or nil
    local s, k = tonumber(args[3]), tonumber(args[4])
    if not key or not s or s < 0 or s > 30 or (args[4] and (not k or k < 0 or k > 1)) then
      ns.Print("%s/dusk adapt dark||light <0-30 seconds> [strength 0-1]|r", Y)
      return
    end
    tr.adapt[key].duration = s
    if k then tr.adapt[key].strength = k end
  elseif cmd == "timefade" then
    local s = tonumber(args[2])
    if not s or s < 0 or s > 600 then ns.Print("%s/dusk timefade <0-600 seconds>|r", Y) return end
    ns.cfg.timeFade = s
  end
  showTransition()
end

local function handler(msg)
  local args = words(msg)
  local cmd = args[1] and args[1]:lower() or ""
  if not ns.db or not D.state.started then ns.Print("not ready yet.") return end
  if cmd == "" or cmd == "status" then status()
  elseif cmd == "help" or cmd == "?" then help()
  elseif cmd == "save" then save(args)
  elseif cmd == "clear" then clear(args)
  elseif cmd == "looks" then looks()
  elseif cmd == "on" then D.SetEnabled(true) ns.Print("automatic adjusting on.")
  elseif cmd == "off" then D.SetEnabled(false) ns.Print("automatic adjusting off; your baseline is back.")
  elseif cmd == "baseline" then
    local b = D.SaveBaseline()
    if b then ns.Print("baseline saved: gamma %.2f, brightness %d, contrast %d, bloom %.2f.", b.gamma, b.brightness, b.contrast, b.bloom) end
  elseif cmd == "style" or cmd == "styles" then styleCmd(args)
  elseif cmd == "chars" or cmd == "characters" then charsCmd(args)
  elseif cmd == "mode" or cmd == "fade" or cmd == "adapt" or cmd == "timefade" then transitionCmd(args)
  elseif cmd == "transition" then showTransition()
  elseif cmd == "debug" then
    ns.cfg.debug = not ns.cfg.debug
    ns.Print("debug %s.", ns.cfg.debug and "on" or "off")
  else
    help()
  end
end

SLASH_DUSKFALL1 = "/dusk"
SLASH_DUSKFALL2 = "/duskfall"
SLASH_DUSKFALL3 = "/df"
SlashCmdList.DUSKFALL = function(msg) ns.Safe(handler, "slash", msg) end
