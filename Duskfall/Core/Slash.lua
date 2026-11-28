-- Duskfall Slash.lua: /dusk (main), /duskfall, /df.
local ADDON, ns = ...
local C, S, D = ns.Channels, ns.Situations, ns.Detect
local L = ns.L

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
  if look.on == false then off = G .. " " .. L["SL_LOOK_OFF"] .. "|r" end
  local scope = ""
  if ns.ScopeOf(look.scope) == nil then scope = G .. " " .. L["SL_LOOK_CHARS"] .. "|r" end
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
ns.FindLook = findLook

local function roundTo(key, v)
  return tonumber(C.Format(key, v))
end

-- Commands ---------------------------------------------------------------------------------------
local function status()
  local st = D.state
  local env = st.env or S.Snapshot()
  local style = ns.Resolver.ActiveStyle()
  local onoff = "|cff40ff40" .. L["SL_ON"] .. "|r"
  if not ns.cfg.enabled then onoff = "|cffff4040" .. L["SL_OFF"] .. "|r" end
  local tr = style.transition or {}
  ns.Print("%s %s  %s  %s(%s)|r", onoff, G .. ns.VERSION .. "|r", L["SL_STATUS_STYLE"]:format(style.name or "?"), G, tr.mode or "adapt")
  local place = {}
  if env.instance then place[#place + 1] = string.format(L["SL_INSTANCE"], env.instanceName or "?", env.instance, env.itype or "?") end
  if env.zone then place[#place + 1] = string.format(L["SL_ZONE"], env.zoneName or "?", env.zone) end
  if env.sub then place[#place + 1] = env.sub end
  if #place == 0 then place[1] = L["SL_UNKNOWN"] end
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
    local from = L["SL_FROM_BASELINE"]
    if src then from = L["SL_FROM_LOOK"]:format(src.name or "?") end
    local held = ""
    if st.held[k] ~= nil then held = "  |cffff9f40" .. L["SL_HELD"]:format(fmtValue(k, st.held[k])) .. "|r" end
    print(string.format("  %s: %s  %s%s|r%s", ch.label, fmtValue(k, cur[k]), G,
      L["SL_CHANNEL_LINE"]:format(fmtValue(k, st.target and st.target[k]), fmtValue(k, base[k]), from), held))
  end
end

-- /dusk help opens the Help window on Getting started (Kim); its Commands topic lists the commands.
local function help()
  local W = ns.Window
  if not (W and W.frame and W.frame:IsShown()) then
    if not ns.OpenWindow then return end
    ns.OpenWindow("places", true)
  end
  if ns.Help and ns.Help.Open then ns.Help.Open("start") end
end

local function save(args)
  local kind = args[2] and args[2]:lower()
  if not KINDS[kind] then ns.Print(L["SL_WHICH_PLACE_SAVE"]) return end
  local env = S.Snapshot()
  local key = S.PlaceKey(kind, env)
  if not key then
    if kind == "instance" then ns.Print(L["SL_NOT_INSTANCE"])
    elseif env.instance then ns.Print(L["SL_NO_ZONE_IN_INSTANCE"])
    else ns.Print(L["SL_NONE_HERE"], kind) end
    return
  end
  local when, bad = parseWhen(args, 3)
  if not when then ns.Print(L["SL_BAD_CONDITION"], bad) return end
  local cur = C.ReadAll()
  local base = ns.db.baseline
  if not cur or not base then ns.Print(L["SL_NO_VALUES"]) return end
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
    ns.Print(L["SL_NOTHING_DIFFERS"])
    return
  end
  local name = S.PlaceName(kind, env) or key
  if #when > 0 then name = name .. " (" .. table.concat(when, ", ") .. ")" end
  if look then
    look.values = values
    ns.Print(L["SL_LOOK_UPDATED"], look.name or name)
  else
    look = { id = ns.NewID("l"), name = name, on = true, scope = { global = true }, absolute = false,
             where = { key }, when = when, values = values }
    table.insert(style.looks, look)
    ns.Print(L["SL_LOOK_SAVED"], name, style.name or "?")
  end
  D.ClearHolds()
  D.state.target = nil
  D.Evaluate("save")
end

local function clear(args)
  local kind = args[2] and args[2]:lower()
  if not KINDS[kind] then ns.Print(L["SL_WHICH_PLACE_CLEAR"]) return end
  local env = S.Snapshot()
  local key = S.PlaceKey(kind, env)
  if not key then ns.Print(L["SL_NONE_HERE"], kind) return end
  local when, bad = parseWhen(args, 3)
  if not when then ns.Print(L["SL_BAD_CONDITION"], bad) return end
  local style = ns.Resolver.ActiveStyle()
  local look, i = findLook(style, key, when)
  if not look then
    ns.Print(L["SL_NO_GLOBAL_LOOK"])
    return
  end
  table.remove(style.looks, i)
  ns.Print(L["SL_LOOK_REMOVED"], look.name or key)
  D.ClearHolds()
  D.state.target = nil
  D.Evaluate("clear")
end

local function looks()
  local style = ns.Resolver.ActiveStyle()
  if #style.looks == 0 then ns.Print(L["SL_NO_LOOKS"], style.name or "?") return end
  ns.Print(L["SL_LOOKS_HEAD"], style.name or "?")
  for i, look in ipairs(style.looks) do print("  " .. lookLine(i, look)) end
end

local function styleCmd(args)
  local sub = args[2] and args[2]:lower()
  local styles = ns.db.styles
  local guid = ns.charKey
  if sub == "use" then
    local n = tonumber(args[3])
    local target = n and styles[n]
    if not target then ns.Print(L["SL_WHICH_STYLE"]) return end
    for _, st in ipairs(styles) do
      if st ~= target and type(st.scope) == "table" and st.scope.chars then st.scope.chars[guid] = nil end
    end
    if not ns.IsGlobalStyle(target) then
      target.scope = type(target.scope) == "table" and target.scope or {}
      target.scope.global = nil
      target.scope.chars = target.scope.chars or {}
      target.scope.chars[guid] = true
    end
    ns.Print(L["SL_STYLE_USED"], target.name or "?")
    D.state.target = nil
    D.Evaluate("style")
    return
  end
  if sub == "new" then
    local name = table.concat(args, " ", 3)
    if name == "" then name = L["SL_STYLE_NEW_NAME"]:format(#styles + 1) end
    local st = ns.NewStyle(name)
    st.scope = { chars = {} }
    if guid then st.scope.chars[guid] = true end
    for _, other in ipairs(styles) do
      if type(other.scope) == "table" and other.scope.chars then other.scope.chars[guid] = nil end
    end
    styles[#styles + 1] = st
    ns.Print(L["SL_STYLE_CREATED"], name)
    D.state.target = nil
    D.Evaluate("style")
    return
  end
  local active = ns.Resolver.ActiveStyle()
  ns.Print(L["SL_STYLES_HEAD"])
  for i, st in ipairs(styles) do
    local who
    if ns.IsGlobalStyle(st) then who = L["SCOPE_GLOBAL"]
    else
      local names = {}
      for g in pairs(st.scope.chars or {}) do names[#names + 1] = ns.CharName(g) end
      table.sort(names)
      who = table.concat(names, ", ")
      if who == "" then who = L["SL_UNUSED"] end
    end
    local mark = "  "
    if st == active then mark = "> " end
    print(string.format("  %s%d. %s %s%s|r", mark, i, st.name or "?", G, L["SL_STYLE_LINE"]:format(who, #st.looks)))
  end
  print("  " .. G .. L["SL_STYLE_USAGE"] .. "|r")
end

local function charsCmd(args)
  local chars = ns.db.chars
  if args[2] and args[2]:lower() == "remove" then
    local want = table.concat(args, " ", 3):lower()
    if want == "" then ns.Print(L["SL_WHICH_CHAR"]) return end
    local found
    for guid, c in pairs(chars) do
      local full = (c.name or ""):lower()
      local first = full:match("^(%S+)") or full
      if full == want or first == want then found = guid break end
    end
    if not found then ns.Print(L["SL_NO_CHAR"], want) return end
    if found == ns.charKey then ns.Print(L["SL_CANT_REMOVE_SELF"]) return end
    local name = chars[found].name or "?"
    local emptied = ns.RemoveCharacter(found) or 0
    ns.Print(L["SL_CHAR_REMOVED"], name)
    if emptied > 0 then ns.Print("|cffff9f40" .. L["SL_SCOPES_EMPTIED"] .. "|r", emptied) end
    D.state.target = nil
    D.Evaluate("chars")
    return
  end
  local list = {}
  for guid, c in pairs(chars) do list[#list + 1] = { guid = guid, c = c } end
  table.sort(list, function(a, b) return (a.c.name or "") < (b.c.name or "") end)
  ns.Print(L["SL_CHARS_HEAD"])
  for _, e in ipairs(list) do
    local mark = ""
    if e.guid == ns.charKey then mark = G .. " " .. L["SL_YOU"] .. "|r" end
    print(string.format("  %s %s%s|r%s", e.c.name or "?", G, L["SL_CHAR_LINE"]:format(e.c.class or "?", date("%Y-%m-%d", e.c.last or 0)), mark))
  end
  print("  " .. G .. L["SL_CHARS_USAGE"] .. "|r")
end

local MODES = { instant = true, fade = true, adapt = true }

local function showTransition()
  local tr = ns.Resolver.ActiveStyle().transition
  local a = tr.adapt
  ns.Print(L["SL_TRANSITION"],
    tr.mode, tr.fade.duration, a.toDark.duration, a.toDark.strength, a.toLight.duration, a.toLight.strength,
    ns.cfg.timeFade, ns.cfg.adaptGap)
end

local function transitionCmd(args)
  local cmd = args[1]:lower()
  local tr = ns.Resolver.ActiveStyle().transition
  if cmd == "mode" then
    local m = args[2] and args[2]:lower()
    if not MODES[m] then ns.Print(Y .. L["SL_USAGE_MODE"] .. "|r") return end
    tr.mode = m
  elseif cmd == "fade" then
    local s = tonumber(args[2])
    if not s or s < 0 or s > 30 then ns.Print(Y .. L["SL_USAGE_FADE"] .. "|r") return end
    tr.fade.duration = s
  elseif cmd == "adapt" then
    local dir = args[2] and args[2]:lower()
    local key = (dir == "dark" and "toDark") or (dir == "light" and "toLight") or nil
    local s, k = tonumber(args[3]), tonumber(args[4])
    if not key or not s or s < 0 or s > 30 or (args[4] and (not k or k < 0 or k > 1)) then
      ns.Print(Y .. L["SL_USAGE_ADAPT"] .. "|r")
      return
    end
    tr.adapt[key].duration = s
    if k then tr.adapt[key].strength = k end
  elseif cmd == "timefade" then
    local s = tonumber(args[2])
    if not s or s < 0 or s > 600 then ns.Print(Y .. L["SL_USAGE_TIMEFADE"] .. "|r") return end
    ns.cfg.timeFade = s
  end
  showTransition()
end

-- Translation testing (Locales/enUS.lua reads DuskfallDB.lang / .pseudo while it loads, so both
-- take a reload). The client's own fonts may lack CJK / Korean / Cyrillic letters.
local function langCmd(args)
  local want = args[2] and args[2]:lower()
  local code
  if want == "client" then code = "client" end
  for _, c in ipairs(ns.LANGS) do if c:lower() == want then code = c end end
  if not code then
    ns.Print(L["LANG_USAGE"], table.concat(ns.LANGS, ", "))
    return
  end
  ns.db.lang = code ~= "client" and code or nil
  ns.Print(L["LANG_NOW"], ns.db.lang or GetLocale(), GetLocale())
  ReloadUI()
end

local function pseudoCmd(args)
  local want = args[2] and args[2]:lower()
  if want ~= "off" and want ~= "mark" and want ~= "long" then
    ns.Print(L["PSEUDO_USAGE"])
    return
  end
  ns.db.pseudo = want ~= "off" and want or nil
  ns.Print(L["PSEUDO_NOW"], want)
  ReloadUI()
end

-- Testing the winter snow out of season (UI/Winter.lua; not in help)
local function winterCmd(args)
  local want = args[2] and args[2]:lower()
  if want ~= "on" and want ~= "off" and want ~= "auto" then
    ns.Print("/dusk winter on | off | auto")   --noloc
    return
  end
  ns.db.debugWinter = want ~= "auto" and want or nil
  if ns.Winter then ns.Winter.Refresh() end
  ns.Print("Winter season: " .. want)   --noloc
end

local function handler(msg)
  local args = words(msg)
  local cmd = args[1] and args[1]:lower() or ""
  if not ns.db or not D.state.started then ns.Print(L["SL_NOT_READY"]) return end
  if cmd == "" then
    if ns.OpenWindow then ns.OpenWindow("places") else status() end
  elseif cmd == "status" then status()
  elseif cmd == "help" or cmd == "?" then help()
  elseif cmd == "save" then save(args)
  elseif cmd == "clear" then clear(args)
  elseif cmd == "looks" then looks()
  elseif cmd == "on" then D.SetEnabled(true) ns.Print(L["SL_ADJUST_ON"])
  elseif cmd == "off" then D.SetEnabled(false) ns.Print(L["SL_ADJUST_OFF"])
  elseif cmd == "baseline" then
    local b = D.SaveBaseline()
    if b then ns.Print(L["SL_BASELINE_SAVED"], b.gamma, b.brightness, b.contrast, b.bloom) end
  elseif cmd == "style" or cmd == "styles" then styleCmd(args)
  elseif cmd == "chars" or cmd == "characters" then charsCmd(args)
  elseif cmd == "mode" or cmd == "fade" or cmd == "adapt" or cmd == "timefade" then transitionCmd(args)
  elseif cmd == "transition" then showTransition()
  elseif cmd == "config" or cmd == "settings" or cmd == "options" then
    if ns.OpenWindow then ns.OpenWindow("settings") end
  elseif cmd == "refresh" or cmd == "fix" then
    D.Refresh()
    ns.Print(L["SL_REFRESHED"])
  elseif cmd == "notes" or cmd == "patchnotes" then
    if ns.PatchNotes then ns.PatchNotes.Open() end
  elseif cmd == "whatsnew" then   -- shows the update toast (testing)
    if ns.PatchNotes then ns.PatchNotes.Toast() end
  elseif cmd == "welcome" then
    if ns.Welcome then ns.Welcome.Show() end
  elseif cmd == "moon" then
    if ns.Moon then ns.Moon.Report() end
  elseif cmd == "lang" then langCmd(args)       -- testing translations (not in help)
  elseif cmd == "pseudo" then pseudoCmd(args)   -- testing: strings that skip ns.L, overflow
  elseif cmd == "winter" then winterCmd(args)   -- testing: the snow out of season
  elseif cmd == "debug" then
    ns.cfg.debug = not ns.cfg.debug
    ns.Print(L["SL_DEBUG"], ns.cfg.debug and L["SL_ON"] or L["SL_OFF"])
  else
    help()
  end
end

SLASH_DUSKFALL1 = "/dusk"
SLASH_DUSKFALL2 = "/duskfall"
SLASH_DUSKFALL3 = "/df"
SlashCmdList.DUSKFALL = function(msg) ns.Safe(handler, "slash", msg) end
