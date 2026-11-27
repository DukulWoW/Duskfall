-- Duskfall UI/Conflict.lua: warns once when another addon also changes Gamma, Brightness or
-- Contrast (Kim, 2026-11-27). Two ways:
--   known    a loaded addon's folder name or title (colour codes stripped) is in KNOWN; nothing of
--            it is read. Titles, because most folder names are unknown (Kim's research,
--            _work/Research/addon-research.md: every one of these writes the same CVars)
--   unknown  someone else writes our CVars FOREIGN_MAX times within FOREIGN_WINDOW seconds while
--            the game's settings window is closed (Core/Detect.lua fires FOREIGN_CVAR)
-- A dialog (in the welcome's style) and a chat line, never in combat. Known: "Turn off <name> and
-- reload" or "Keep both" (remembered per addon in db.conflictOk). Unknown: once per session,
-- "Don't warn again" remembers it (db.conflictOk["*"]).
-- Public: ns.Conflict.Check()
local ADDON, ns = ...
local UI = ns.UI
local CF = {}
ns.Conflict = CF

-- Addons that change the same settings, lower case: folder names and titles.
local KNOWN = {
  "iris", "forever bright", "foreverbright", "adaptive brightness", "adaptivebrightness",
  "dynamic ambiance", "dynamicambiance", "earendil", "advanced graphics tuner", "advancedgraphicstuner",
  "panorama forever", "panoramaforever", "mac-ever", "macever", "hdr tuner", "hdr tuner (forever)", "hdrtuner",
  "forever visuals", "forevervisuals", "lighternights", "lighter nights", "lighter_nights",
  "dynamic light", "true-night", "truenight", "az set map", "azsetmap", "nightlight",
}
local isKnown = {}
for _, k in ipairs(KNOWN) do isKnown[k] = true end
local FOREIGN_MAX, FOREIGN_WINDOW = 3, 10
local DELAY = 8   -- after login: after the welcome (4 s) and the update toast (6 s)

local Y = "|cffffd100"
local frame, queue, sessionWarned = nil, {}, false
local hits = {}

local function plain(t)
  if type(t) ~= "string" then return nil end
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")
  return t
end

local function titleOf(name)
  local info = C_AddOns and C_AddOns.GetAddOnInfo and select(2, C_AddOns.GetAddOnInfo(name))
  local t = plain(info)
  if t and t ~= "" then return t end
  return name
end

-- Loaded addons from KNOWN: their folder names (never Duskfall itself).
local function loadedKnown()
  local out = {}
  if not (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo and C_AddOns.IsAddOnLoaded) then return out end
  for i = 1, C_AddOns.GetNumAddOns() do
    local name, title = C_AddOns.GetAddOnInfo(i)
    if name and name ~= ADDON and C_AddOns.IsAddOnLoaded(name) then
      local t = (plain(title) or ""):lower()
      if isKnown[name:lower()] or isKnown[t] then out[#out + 1] = name end
    end
  end
  return out
end

local function okFor(key) return ns.db and ns.db.conflictOk and ns.db.conflictOk[key] end
local function setOk(key)
  ns.db.conflictOk = ns.db.conflictOk or {}
  ns.db.conflictOk[key] = true
end

local function build()
  local f = CreateFrame("Frame", "DuskfallConflict", UIParent)
  f:SetSize(480, 196)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  UI.RoundBox(f, { radius = 12, bottom = { 0.04, 0.03, 0.02, 0.97 }, top = { 0.16, 0.12, 0.08, 0.97 },
    border = { 1, 0.82, 0, 0.85 }, sweep = true })
  local badge = CreateFrame("Frame", nil, f)
  badge:SetSize(52, 52)
  badge:SetPoint("TOPLEFT", f, "TOPLEFT", -16, 16)
  badge:SetFrameLevel(f:GetFrameLevel() + 10)
  local icon = badge:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture(UI.ART .. "icon")
  f.title = UI.Label(f, "", "GameFontNormalLarge")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 46, -16)
  f.body = UI.Label(f, "", "GameFontHighlight")
  f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -50)
  f.body:SetPoint("RIGHT", f, "RIGHT", -20, 0)
  f.body:SetJustifyV("TOP")
  f.body:SetSpacing(3)
  f.body:SetTextColor(0.9, 0.88, 0.84)
  -- Up to three buttons, right to left; the first is the main one (gold)
  f.buttons = {}
  for i = 1, 3 do
    local b = UI.Button(f, "", 120, nil, 26)
    if i == 1 then
      b:SetKind("main")
      b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    else
      b:SetPoint("RIGHT", f.buttons[i - 1], "LEFT", -8, 0)
    end
    f.buttons[i] = b
  end
  tinsert(UISpecialFrames, "DuskfallConflict")
  UI.Fader(f, { esc = true })
  f:HookScript("OnHide", function() C_Timer.After(0.5, CF.Next) end)
  f:Hide()
  frame = f
end

-- w.buttons = { { text, width, fn }, ... } right to left
local function showWarning(w)
  if not frame then build() end
  frame.title:SetText(w.title)
  frame.body:SetText(w.body)
  local total = 32
  for i, b in ipairs(frame.buttons) do
    local spec = w.buttons[i]
    b:SetShown(spec ~= nil)
    if spec then
      b:SetText(spec[1])
      b:SetWidth(spec[2])
      b:SetScript("OnClick", function() frame:FadeHide() if spec[3] then ns.Safe(spec[3], "conflict") end end)
      total = total + spec[2] + (i > 1 and 8 or 0)
    end
  end
  frame:SetWidth(math.max(480, total))
  frame:Show()
  ns.Print(w.chat)
end

-- One dialog at a time; waits for the end of combat.
function CF.Next()
  if #queue == 0 or (frame and frame:IsShown()) then return end
  if InCombatLockdown() then return end
  showWarning(table.remove(queue, 1))
end
ns.On("PLAYER_REGEN_ENABLED", function() CF.Next() end)

local WHAT = "Gamma, Brightness and Contrast"

-- For this character, then saved: the addon list only keeps a change after SaveAddOns (the
-- game's AddOns window does the same on Okay; without it the reload forgot it, Kim). Reloads.
local function turnOff(name)
  if C_AddOns and C_AddOns.DisableAddOn then
    pcall(C_AddOns.DisableAddOn, name, UnitName("player"))
    if C_AddOns.GetAddOnEnableState and (C_AddOns.GetAddOnEnableState(name, UnitName("player")) or 0) > 0 then
      pcall(C_AddOns.DisableAddOn, name)   -- the character form did nothing: every character
    end
  end
  if C_AddOns and C_AddOns.SaveAddOns then pcall(C_AddOns.SaveAddOns) end
  ReloadUI()
end

local function knownWarning(name)
  local title = titleOf(name)
  local AI = ns.AddonImport
  local src = AI and AI.For(name)
  local canImport = src and AI.Available(src)
  local body = title .. " also changes " .. WHAT .. ". Two addons changing the same settings fight over them, "
    .. "and the screen can flicker or jump. Use only one of them."
  if canImport then
    body = body .. "\n\nDuskfall can bring " .. title .. "'s settings along first, as a new Style. Turning "
      .. title .. " off reloads the interface."
  else
    body = body .. "\n\nTurning " .. title .. " off reloads the interface."
  end
  local buttons = {}
  if canImport then
    buttons[#buttons + 1] = { "Import, then turn off " .. title, 230, function()
      AI.RunBeforeReload(src)
      turnOff(name)
    end }
    buttons[#buttons + 1] = { "Turn off " .. title, 150, function() turnOff(name) end }
  else
    buttons[#buttons + 1] = { "Turn off " .. title .. " and reload", 220, function() turnOff(name) end }
  end
  buttons[#buttons + 1] = { "Keep both", 110, function() setOk(name) end }
  return {
    title = title .. " is on too",
    body = body,
    buttons = buttons,
    chat = Y .. title .. "|r also changes " .. WHAT .. "; the two will fight over them. Use only one.",
  }
end

local function unknownWarning()
  return {
    title = "Another addon is changing your screen",
    body = "Something besides Duskfall keeps changing " .. WHAT .. ", most likely another addon. Two addons "
      .. "changing the same settings fight over them, and the screen can flicker or jump.\n\nIf you use "
      .. "another lighting or graphics addon, turn one of them off.",
    buttons = { { "OK", 110 }, { "Don't warn again", 150, function() setOk("*") end } },
    chat = "something besides Duskfall keeps changing " .. WHAT .. ", most likely another addon.",
  }
end

function CF.Check()
  if not (C_AddOns and C_AddOns.IsAddOnLoaded) then return end
  for _, name in ipairs(loadedKnown()) do
    if not okFor(name) then queue[#queue + 1] = knownWarning(name) end
  end
  CF.Next()
end

ns.Listen("ENABLE", function()
  C_Timer.After(DELAY, function() ns.Safe(CF.Check, "conflict check") end)
end)

-- Unknown writers: only outside the game's own settings window (the player's own slider moves)
ns.Listen("FOREIGN_CVAR", function()
  if sessionWarned or okFor("*") then return end
  if SettingsPanel and SettingsPanel:IsShown() then return end
  local now = GetTime()
  hits[#hits + 1] = now
  while hits[1] and now - hits[1] > FOREIGN_WINDOW do table.remove(hits, 1) end
  ns.Debug("foreign write (%d in %d s)", #hits, FOREIGN_WINDOW)
  if #hits < FOREIGN_MAX then return end
  -- A known addon already explains it
  if #loadedKnown() > 0 then return end
  sessionWarned = true
  queue[#queue + 1] = unknownWarning()
  CF.Next()
end)
