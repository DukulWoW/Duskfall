-- Duskfall UI/Share.lua: Export and Import of one setting (a Look) or a whole Style as a line of
-- text, to keep or to give to a friend (Kim, 2026-11-26).
--   Look:  Duskfall:1:look:<name>^<where,...>^<when,...>^<absolute 0/1>^g=0.05,b=6,c=8,bl=-0.8
--   Style: Duskfall:1:style:<name>^<mode>^<fade s>^<to dark s>^<dark dip>^<to light s>^<light glare>;<look>;<look>...
--          (each <look> as above, without the "Duskfall:1:look:" in front)
-- Fields are %-escaped for ^ , ; | and %. No "|" anywhere: edit boxes read it as a colour code. Place keys are map / instance IDs (the same for every
-- player); subzone names are in the game's language. Import checks every part and drops what it
-- does not know. An imported Look replaces the values of the same setting in the active Style
-- (same places and conditions), else it is added. An imported Style is added unused (as
-- Duplicate does), with an offer to use it for every character.
-- Public: ns.Share.ExportLook(look), ns.Share.ExportStyle(st), ns.Share.Import(text) ->
--         ok, message; ns.Share.ImportDialog(onDone)
local ADDON, ns = ...
local L = ns.L
local UI, C, R, D = ns.UI, ns.Channels, ns.Resolver, ns.Detect
local Share = {}
ns.Share = Share

local PREFIX = "Duskfall:1:"   --noloc
local SHORT = { gamma = "g", brightness = "b", contrast = "c", bloom = "bl" }
local LONG = { g = "gamma", b = "brightness", c = "contrast", bl = "bloom" }
local MODES = { instant = true, fade = true, adapt = true }
local FLAGS = { indoors = true, outdoors = true, resting = true, combat = true, mounted = true, swimming = true,
                underwater = true, ghost = true }

local function esc(s)
  return (tostring(s or ""):gsub("[%%^,;|]", function(c) return string.format("%%%02X", c:byte()) end))
end

local function unesc(s)
  return (tostring(s or ""):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function split(s, sep)
  local out = {}
  if s == "" then return out end
  for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
  return out
end

local function num(v)
  local s = string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", "")
  return s
end

-- Export ------------------------------------------------------------------------------------------
local function lookBody(look)
  local where, when, vals = {}, {}, {}
  for _, s in ipairs(look.where or {}) do where[#where + 1] = esc(s) end
  for _, s in ipairs(look.when or {}) do when[#when + 1] = esc(s) end
  for _, ch in ipairs(C.list) do
    local v = look.values and tonumber(look.values[ch.key])
    if v ~= nil then vals[#vals + 1] = SHORT[ch.key] .. "=" .. num(v) end
  end
  return table.concat({ esc(look.name or ""), table.concat(where, ","), table.concat(when, ","),
    look.absolute and "1" or "0", table.concat(vals, ",") }, "^")
end

function Share.ExportLook(look)
  return PREFIX .. "look:" .. lookBody(look)
end

function Share.ExportStyle(st)
  local tr = st.transition or {}
  local fade = tr.fade or {}
  local a = tr.adapt or {}
  local dk, lt = a.toDark or {}, a.toLight or {}
  local head = table.concat({ esc(st.name or L["STYLE_DEFAULT"]), tr.mode or "adapt", num(fade.duration or 1.5),
    num(dk.duration or 4), num(dk.strength or 0.3), num(lt.duration or 1), num(lt.strength or 0.3) }, "^")
  local parts = { PREFIX .. "style:" .. head }
  for _, look in ipairs(st.looks or {}) do parts[#parts + 1] = lookBody(look) end
  return table.concat(parts, ";")
end

-- Import ------------------------------------------------------------------------------------------
local function validWhere(s)
  local k = s:gsub("^~", "")
  return k:match("^zone:%d+$") or k:match("^sub:%d+:.+$") or k:match("^instance:%d+$")
    or k:match("^itype:%a+$")
end

local function validWhen(s)
  local k = s:gsub("^~", ""):gsub("^!", "")
  if FLAGS[k] then return true end
  local t = k:match("^time:(.+)$")
  if not t then return false end
  return t == "dawn" or t == "day" or t == "dusk" or t == "night" or t:match("^%d%d?:%d%d%-%d%d?:%d%d$") ~= nil
end

-- A Look from its body, or nil.
local function parseLook(body)
  local f = split(body, "^")
  if #f < 5 then return nil end
  local look = { id = ns.NewID("l"), name = unesc(f[1]), on = true, scope = { global = true },
                 absolute = f[4] == "1", where = {}, when = {}, values = {} }
  for _, s in ipairs(split(f[2], ",")) do
    s = unesc(s)
    if validWhere(s) then look.where[#look.where + 1] = s end
  end
  for _, s in ipairs(split(f[3], ",")) do
    s = unesc(s)
    if validWhen(s) then look.when[#look.when + 1] = s end
  end
  for _, kv in ipairs(split(f[5], ",")) do
    local k, v = kv:match("^(%a+)=(%-?[%d%.]+)$")
    local key = k and LONG[k]
    v = tonumber(v)
    if key and v then
      local ch = C.byKey[key]
      local span = ch.max - ch.min
      if look.absolute then v = C.Clamp(key, v) else v = math.max(-span, math.min(span, v)) end
      look.values[key] = tonumber(C.Format(key, v))
    end
  end
  if next(look.values) == nil then return nil end
  if look.name == "" then look.name = L["SH_IMPORTED_LOOK"] end
  return look
end

local function sameList(a, b)
  if #a ~= #b then return false end
  local x, y = {}, {}
  for i = 1, #a do x[i] = a[i] end
  for i = 1, #b do y[i] = b[i] end
  table.sort(x)
  table.sort(y)
  for i = 1, #x do if x[i] ~= y[i] then return false end end
  return true
end

local function changed()
  D.ClearHolds()
  D.state.target = nil
  D.Evaluate("places")
end

-- Returns ok, message.
function Share.Import(text)
  text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text:sub(1, #PREFIX) ~= PREFIX then return false, L["SH_NOT_EXPORT"] end
  local rest = text:sub(#PREFIX + 1)
  local kind, body = rest:match("^(%a+):(.*)$")
  if kind == "look" then
    local look = parseLook(body)
    if not look then return false, L["SH_NOTHING"] end
    local style = R.ActiveStyle()
    for _, l in ipairs(style.looks) do
      if UI.ScopeIsGlobal(l.scope) and (l.absolute and true or false) == look.absolute
        and sameList(l.where or {}, look.where) and sameList(l.when or {}, look.when) then
        l.values = look.values
        changed()
        return true, L["SH_UPDATED"]:format(l.name or "?")
      end
    end
    table.insert(style.looks, look)
    changed()
    return true, L["SH_ADDED"]:format(look.name)
  elseif kind == "style" then
    local parts = split(body, ";")
    local h = split(parts[1] or "", "^")
    if #h < 7 then return false, L["SH_CUT_SHORT"] end
    local st = ns.NewStyle(L["SH_IMPORTED_STYLE"]:format(unesc(h[1])))
    st.scope = { chars = {} }
    local tr = st.transition
    if MODES[h[2]] then tr.mode = h[2] end
    local function dur(v, lo, hi, d) v = tonumber(v) or d return math.max(lo, math.min(hi, v)) end
    tr.fade.duration = dur(h[3], 0, 10, 1.5)
    tr.adapt.toDark.duration = dur(h[4], 0, 15, 4)
    tr.adapt.toDark.strength = dur(h[5], 0, 1, 0.3)
    tr.adapt.toLight.duration = dur(h[6], 0, 10, 1)
    tr.adapt.toLight.strength = dur(h[7], 0, 1, 0.3)
    for i = 2, #parts do
      local look = parseLook(parts[i])
      if look then st.looks[#st.looks + 1] = look end
    end
    table.insert(ns.db.styles, st)
    return true, (#st.looks == 1 and L["SH_STYLE_ADDED_ONE"]:format(st.name) or L["SH_STYLE_ADDED_MANY"]:format(st.name, #st.looks)), st
  end
  return false, L["SH_NOT_EXPORT"]
end

-- Import dialog -----------------------------------------------------------------------------------
local dialog

local function useStyle(st)
  UI.Confirm("Use \"" .. (st.name or "?") .. "\" for every character now?", function()
    for _, o in ipairs(ns.db.styles) do
      if o ~= st and UI.ScopeIsGlobal(o.scope, true) then o.scope = { chars = {} } end
    end
    st.scope = { global = true }
    changed()
  end)
end

function Share.ImportDialog(onDone)
  if not dialog then
    local f = CreateFrame("Frame", "DuskfallImportDialog", UIParent)
    f:SetSize(440, 150)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:Hide()
    UI.RoundBox(f, { radius = 12, bottom = { 0.04, 0.03, 0.02, 0.97 }, top = { 0.16, 0.12, 0.08, 0.97 },
      border = { 1, 0.82, 0, 0.45 } })
    local title = UI.Label(f, L["BTN_IMPORT"], "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -16)
    local help = UI.Label(f, L["SH_HELP"])
    help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    help:SetTextColor(0.7, 0.7, 0.7)
    local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    eb:SetSize(396, 22)
    eb:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 6, -10)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(0)
    local msg = UI.Label(f, "")
    msg:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", -6, -8)
    msg:SetTextColor(1, 0.4, 0.4)
    local go = UI.Button(f, L["BTN_IMPORT"], 110, function()
      local ok, text, st = Share.Import(eb:GetText())
      if not ok then msg:SetText(text) return end
      f:FadeHide()
      ns.Print(text)
      if f.onDone then ns.Safe(f.onDone, "import") end
      if st then useStyle(st) end
    end)
    go:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    local cancel = UI.Button(f, L["BTN_CANCEL"], 110, function() f:FadeHide() end)
    cancel:SetPoint("RIGHT", go, "LEFT", -8, 0)
    eb:SetScript("OnEnterPressed", function() go:Click() end)
    eb:SetScript("OnEscapePressed", function() eb:ClearFocus() f:FadeHide() end)
    f.eb, f.msg = eb, msg
    tinsert(UISpecialFrames, "DuskfallImportDialog")
    UI.Fader(f, { esc = true })
    dialog = f
  end
  dialog.onDone = onDone
  dialog.msg:SetText("")
  dialog.eb:SetText("")
  dialog:Show()
  dialog:Raise()
  dialog.eb:SetFocus()
end
