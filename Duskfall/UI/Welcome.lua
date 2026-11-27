-- Duskfall UI/Welcome.lua: a small welcome on the first login after a new install (Kim, 2026-11-26:
-- "nothing fancy"). Shown once, a few seconds after login, then db.welcomed is set; tables from
-- before v3 count as welcomed (Core.lua migration). /dusk welcome shows it again.
-- Public: ns.Welcome.Show()
local ADDON, ns = ...
local UI = ns.UI
local WL = {}
ns.Welcome = WL

local Y = "|cffffd100"
local DELAY = 4   -- seconds after login, so it does not land in the loading-screen rush
local frame

local function build()
  local f = CreateFrame("Frame", "DuskfallWelcome", UIParent)
  f:SetSize(480, 244)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  -- As the main window (Kim): the slate, cut round (Assets/round-rect-mask, made for this 2:1
  -- panel), at its own scale; the thin border sweeping gold to blue
  local slate = f:CreateTexture(nil, "BACKGROUND", nil, 0)
  slate:SetAllPoints()
  slate:SetTexture(UI.ART .. UI.BACKGROUND)
  slate:SetTexCoord(0, 480 / 512, 0, 244 / 512)
  local cut = f:CreateMaskTexture()
  cut:SetAllPoints()
  cut:SetTexture(UI.ART .. "round-rect-mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  slate:AddMaskTexture(cut)
  if ns.CursorLight then
    local lit = ns.CursorLight.Copy(slate, "fill")
    if lit then lit:AddMaskTexture(cut) end
  end
  UI.RoundBox(f, { radius = 12, bottom = { 0, 0, 0, 0 }, top = { 0, 0, 0, 0 },
    border = { 1, 0.82, 0, 0.85 }, sweep = true })
  -- The round icon half out of the top-left corner, as on the main window
  local badge = CreateFrame("Frame", nil, f)
  badge:SetSize(56, 56)
  badge:SetPoint("TOPLEFT", f, "TOPLEFT", -16, 16)
  badge:SetFrameLevel(f:GetFrameLevel() + 10)
  local icon = badge:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture(UI.ART .. "icon")

  local title = UI.Label(f, "Welcome to Duskfall", "GameFontNormalHuge")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 52, -16)
  local body = UI.Label(f, "Duskfall sets Gamma, Brightness, Contrast and Bloom for where you are: a dark "
    .. "cave, a city at night, a dungeon.\n\n"
    .. "Nothing changes until you ask. Open Duskfall where you stand, move a slider, and this place "
    .. "keeps that look.\n\n"
    .. "Find it later on the minimap's moon, or type " .. Y .. "/dusk|r.", "GameFontHighlight")
  body:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -58)
  body:SetPoint("RIGHT", f, "RIGHT", -20, 0)
  body:SetJustifyV("TOP")
  body:SetSpacing(2)
  body:SetTextColor(0.9, 0.88, 0.84)

  local open = UI.Button(f, "Open Duskfall", 140, function()
    f:FadeHide()
    if ns.OpenWindow then ns.OpenWindow("places", true) end
  end, 26)
  open:SetKind("main")
  open:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
  local later = UI.Button(f, "Later", 90, function() f:FadeHide() end, 26)
  later:SetPoint("RIGHT", open, "LEFT", -8, 0)

  -- The About tab's link buttons (sites and bug reports), bottom left (Kim)
  local SZ, GAP = 28, 8
  local n = 0
  for _, l in ipairs(ns.LINKS or {}) do
    if l.url then
      local b = UI.IconButton(f, SZ, l.key, {
        tip = l.name, tipSub = l.sub or ("Copy the " .. l.name .. " link"),
        onClick = function(self) UI.Copy(l.name, l.url, self) end,
      })
      b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16 + n * (SZ + GAP), 13)
      n = n + 1
    end
  end

  tinsert(UISpecialFrames, "DuskfallWelcome")
  if ns.CursorLight then ns.CursorLight.Attach(f) end
  UI.Fader(f, { esc = true })
  f:Hide()
  frame = f
end

function WL.Show()
  if not frame then build() end
  frame:Show()
  if ns.db then ns.db.welcomed = true end
end

ns.Listen("ENABLE", function()
  if not ns.db or ns.db.welcomed then return end
  C_Timer.After(DELAY, function()
    if ns.db and not ns.db.welcomed and not InCombatLockdown() then WL.Show() end
  end)
end)
