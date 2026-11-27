-- Duskfall UI/Conflict.lua: warns once when another addon also changes Gamma, Brightness or
-- Contrast (Kim, 2026-11-27). Two ways:
--   known    an addon from KNOWN is loaded (by its folder name only; nothing of it is read)
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

-- Folder names of addons that change the same settings. Kim adds more from _work/Dump.
local KNOWN = { "Iris" }
local FOREIGN_MAX, FOREIGN_WINDOW = 3, 10
local DELAY = 8   -- after login: after the welcome (4 s) and the update toast (6 s)

local Y = "|cffffd100"
local frame, queue, sessionWarned = nil, {}, false
local hits = {}

local function titleOf(name)
  local info = C_AddOns and C_AddOns.GetAddOnInfo and select(2, C_AddOns.GetAddOnInfo(name))
  if type(info) == "string" and info ~= "" then
    return (info:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
  end
  return name
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
  f.main = UI.Button(f, "", 200, nil, 26)
  f.main:SetKind("main")
  f.main:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
  f.other = UI.Button(f, "", 140, nil, 26)
  f.other:SetPoint("RIGHT", f.main, "LEFT", -8, 0)
  tinsert(UISpecialFrames, "DuskfallConflict")
  UI.Fader(f, { esc = true })
  f:HookScript("OnHide", function() C_Timer.After(0.5, CF.Next) end)
  f:Hide()
  frame = f
end

local function showWarning(w)
  if not frame then build() end
  frame.title:SetText(w.title)
  frame.body:SetText(w.body)
  frame.main:SetText(w.main)
  frame.main:SetScript("OnClick", function() frame:FadeHide() ns.Safe(w.onMain, "conflict") end)
  frame.other:SetText(w.other)
  frame.other:SetScript("OnClick", function() frame:FadeHide() if w.onOther then ns.Safe(w.onOther, "conflict") end end)
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

local function knownWarning(name)
  local title = titleOf(name)
  return {
    title = title .. " is on too",
    body = title .. " also changes " .. WHAT .. ". Two addons changing the same settings fight over them, "
      .. "and the screen can flicker or jump. Use only one of them.\n\nTurning " .. title .. " off reloads "
      .. "the interface.",
    main = "Turn off " .. title .. " and reload",
    other = "Keep both",
    chat = Y .. title .. "|r also changes " .. WHAT .. "; the two will fight over them. Use only one.",
    onMain = function()
      -- For this character, then saved: the addon list only keeps a change after SaveAddOns
      -- (the game's AddOns window does the same on Okay; without it the reload forgot it, Kim)
      if C_AddOns and C_AddOns.DisableAddOn then
        pcall(C_AddOns.DisableAddOn, name, UnitName("player"))
        if C_AddOns.GetAddOnEnableState and (C_AddOns.GetAddOnEnableState(name, UnitName("player")) or 0) > 0 then
          pcall(C_AddOns.DisableAddOn, name)   -- the character form did nothing: every character
        end
      end
      if C_AddOns and C_AddOns.SaveAddOns then pcall(C_AddOns.SaveAddOns) end
      ReloadUI()
    end,
    onOther = function() setOk(name) end,
  }
end

local function unknownWarning()
  return {
    title = "Another addon is changing your screen",
    body = "Something besides Duskfall keeps changing " .. WHAT .. ", most likely another addon. Two addons "
      .. "changing the same settings fight over them, and the screen can flicker or jump.\n\nIf you use "
      .. "another lighting or graphics addon, turn one of them off.",
    main = "OK",
    other = "Don't warn again",
    chat = "something besides Duskfall keeps changing " .. WHAT .. ", most likely another addon.",
    onMain = function() end,
    onOther = function() setOk("*") end,
  }
end

function CF.Check()
  if not (C_AddOns and C_AddOns.IsAddOnLoaded) then return end
  for _, name in ipairs(KNOWN) do
    if not okFor(name) and C_AddOns.IsAddOnLoaded(name) then queue[#queue + 1] = knownWarning(name) end
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
  if #hits < FOREIGN_MAX then return end
  -- A known addon already explains it
  for _, name in ipairs(KNOWN) do
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name) then return end
  end
  sessionWarned = true
  queue[#queue + 1] = unknownWarning()
  CF.Next()
end)
