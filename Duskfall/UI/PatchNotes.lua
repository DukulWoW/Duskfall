-- Duskfall UI/PatchNotes.lua: the patch notes as an overlay in the main window, as Help (Kim,
-- 2026-11-27). Versions on the left, the chosen version's notes on the right, each line with a
-- NEW / CHANGE / FIX chip (BigNoteBox's chips, its "skin" look). Only the notes list scrolls.
-- After an update a toast by the status display says so, once per version (ns.db.notesSeen):
-- left-click opens the notes, right-click closes it.
-- Public: ns.PatchNotes.Open(version), ns.PatchNotes.Toggle()
local ADDON, ns = ...
local L = ns.L
local UI, W = ns.UI, ns.Window
local PN = {}
ns.PatchNotes = PN

local CHIP = {   -- BNB's chip colours (HelpBook CHIP_KINDS, skin)
  new = { L["PN_NEW"], { 0.40, 0.80, 0.42 } },
  change = { L["PN_CHANGE"], { 0.42, 0.65, 1.00 } },
  fix = { L["PN_FIX"], { 0.95, 0.38, 0.35 } },
}
local CHIP_W, CHIP_H, CHIP_GAP, ROW_GAP = 60, 16, 10, 10
local TOAST_SECONDS = 10
local TOAST_DELAY = 6   -- after login; the welcome (first install) waits 4

local frame, buttons, heading, sub, box = nil, {}, nil, nil, nil
local current = 1
local measure

local function chipFont()
  if PN.font then return PN.font end
  local f = CreateFont("DuskfallChipFont")
  f:CopyFontObject(GameFontNormalSmall)
  local path, _, flags = f:GetFont()
  if path then f:SetFont(path, 10, flags or "") end
  PN.font = f
  return f
end

local function textWidth()
  return math.max(200, (box:GetWidth() or 440) - CHIP_W - CHIP_GAP - 8)
end

local function indexOf(version)
  for i, e in ipairs(ns.PATCH_NOTES) do
    if e.version == version then return i end
  end
end

local function show(i)
  local e = ns.PATCH_NOTES[i]
  if not e then return end
  current = i
  heading:SetText("Duskfall " .. e.version)   --noloc
  sub:SetText(e.date or L["PN_NOT_RELEASED"])
  for n, b in ipairs(buttons) do
    b.pick:SetShown(n == i)
    if n == i then
      b.text:SetTextColor(0.14, 0.08, 0)
      b.text:SetShadowOffset(0, 0)
      b.date:SetTextColor(0.25, 0.16, 0.03)
    else
      b.text:SetTextColor(1, 0.82, 0)
      b.text:SetShadowOffset(1, -1)
      b.date:SetTextColor(0.6, 0.6, 0.6)
    end
  end
  local w = textWidth()
  measure:SetWidth(w)
  local rows = {}
  for _, n in ipairs(e.notes) do
    measure:SetText(n[2])
    rows[#rows + 1] = { kind = n[1], text = n[2], h = math.max(CHIP_H, measure:GetStringHeight() or 14) + ROW_GAP }
  end
  box:SetDataProvider(CreateDataProvider(rows))
end

local function build()
  local f = W.NewOverlay(L["AB_PATCH"])
  -- Help next to Close, as Help has Patch Notes there (Kim)
  local help = UI.Button(f, L["BTN_HELP"], 120, function() if ns.Help then ns.Help.Open() end end)
  help:SetPoint("RIGHT", f.closeBtn, "LEFT", -8, 0)

  -- Versions
  local n = #ns.PATCH_NOTES
  local list = CreateFrame("Frame", nil, f)
  list:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -56)
  list:SetSize(200, math.min(n, 11) * 34 + 12)
  UI.RoundBox(list, { radius = 10, bottom = { 0, 0, 0, 0.45 }, top = { 0.14, 0.11, 0.07, 0.4 },
    border = { 1, 0.82, 0, 0.25 } })
  for i, e in ipairs(ns.PATCH_NOTES) do
    if i > 11 then break end   -- the newest eleven fit; older ones live in the CHANGELOG
    local b = CreateFrame("Button", nil, list)
    b:SetSize(184, 30)
    b:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -6 - (i - 1) * 34)
    local inner = CreateFrame("Frame", nil, b)
    inner:SetAllPoints()
    b.pick = UI.RoundBox(inner, { radius = 8, bottom = { 0.5, 0.33, 0.05, 0.95 }, top = { 0.93, 0.72, 0.24, 0.95 } })
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)
    local top = CreateFrame("Frame", nil, b)
    top:SetAllPoints()
    top:SetFrameLevel(inner:GetFrameLevel() + 2)
    b.text = UI.Label(top, L["VERSION_FMT"]:format(e.version), "GameFontNormal")
    b.text:SetPoint("LEFT", b, "LEFT", 12, 0)
    b.date = UI.Label(top, e.date or L["PN_NEXT"], "GameFontHighlightSmall")
    b.date:SetPoint("RIGHT", b, "RIGHT", -10, 0)
    b:SetScript("OnClick", function() show(i) end)
    buttons[i] = b
  end

  -- Notes
  local page = CreateFrame("Frame", nil, f)
  page:SetPoint("TOPLEFT", list, "TOPRIGHT", 20, 0)
  page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 20)
  UI.RoundBox(page, { radius = 12, bottom = { 0, 0, 0, 0.4 }, top = { 0.16, 0.12, 0.08, 0.35 },
    border = { 1, 0.82, 0, 0.2 } })
  heading = UI.Label(page, "", "GameFontNormalLarge")
  heading:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -18)
  sub = UI.Label(page, "", "GameFontHighlightSmall")
  sub:SetPoint("LEFT", heading, "RIGHT", 10, -1)
  sub:SetTextColor(0.6, 0.6, 0.6)

  box = CreateFrame("Frame", nil, page, "WowScrollBoxList")
  box:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -50)
  box:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -34, 16)
  local scroll = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
  scroll:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 0)
  scroll:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 8, 0)
  measure = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  measure:SetSpacing(3)
  measure:Hide()

  local view = CreateScrollBoxListLinearView()
  view:SetElementExtentCalculator(function(_, e) return e.h end)
  view:SetElementInitializer("Frame", function(row, e)
    if not row.chip then
      local chip = CreateFrame("Frame", nil, row)
      chip:SetSize(CHIP_W, CHIP_H)
      chip:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
      chip.bg = chip:CreateTexture(nil, "BACKGROUND")
      chip.bg:SetAllPoints()
      chip.edges = {}
      for _, p in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
                           { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = chip:CreateTexture(nil, "BORDER")
        t:SetPoint(p[1], chip, p[1])
        t:SetPoint(p[2], chip, p[2])
        chip.edges[#chip.edges + 1] = t
      end
      chip.edges[1]:SetHeight(1)
      chip.edges[2]:SetHeight(1)
      chip.edges[3]:SetWidth(1)
      chip.edges[4]:SetWidth(1)
      chip.fs = chip:CreateFontString(nil, "OVERLAY")
      chip.fs:SetFontObject(chipFont())
      chip.fs:SetPoint("CENTER", chip, "CENTER", 0, 0)
      chip.fs:SetShadowOffset(0, 0)
      row.chip = chip
      row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      row.text:SetPoint("TOPLEFT", chip, "TOPRIGHT", CHIP_GAP, 1)
      row.text:SetJustifyH("LEFT")
      row.text:SetJustifyV("TOP")
      row.text:SetSpacing(3)
      row.text:SetTextColor(0.9, 0.88, 0.84)
    end
    local k = CHIP[e.kind] or CHIP.change
    local c = k[2]
    row.chip.fs:SetText(k[1])
    row.chip.fs:SetTextColor(c[1], c[2], c[3])
    row.chip.bg:SetColorTexture(c[1], c[2], c[3], 0.15)
    for _, t in ipairs(row.chip.edges) do t:SetColorTexture(c[1], c[2], c[3], 0.85) end
    row.text:SetWidth(textWidth())
    row.text:SetText(e.text)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(box, scroll, view)
  UI.AutoHideScroll(box, scroll)

  -- Sizes are known once it shows: lay the notes out then
  f:HookScript("OnShow", function() C_Timer.After(0, function() if f:IsShown() then show(current) end end) end)
  frame = f
end

-- version: open on that version (default the newest). Opens the window on About if it is closed.
function PN.Open(version)
  if not ns.OpenWindow then return end
  if not (W.frame and W.frame:IsShown()) then ns.OpenWindow("about", true) end
  if not W.frame then return end
  if not frame then build() end
  current = indexOf(version) or current
  frame:Show()
  show(current)
end

function PN.Toggle()
  if frame and frame:IsOpen() then frame:FadeHide() else PN.Open() end
end

-- Toast ----------------------------------------------------------------------------------------------
local toast
local function buildToast()
  local t = CreateFrame("Button", "DuskfallWhatsNew", UIParent)
  t:SetSize(280, 46)
  t:SetFrameStrata("MEDIUM")
  t:SetClampedToScreen(true)
  t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  UI.RoundBox(t, { radius = 10, bottom = { 0.02, 0.02, 0.01, 0.72 }, top = { 0.14, 0.11, 0.07, 0.72 },
    border = { 1, 0.82, 0, 0.85 }, sweep = true })
  local icon = t:CreateTexture(nil, "ARTWORK")
  icon:SetSize(34, 34)
  icon:SetPoint("LEFT", t, "LEFT", 6, 0)
  icon:SetTexture(UI.ART .. "icon")
  local line = UI.Label(t, L["PN_TOAST"], "GameFontNormal")
  line:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
  line:SetPoint("RIGHT", t, "RIGHT", -8, 0)
  line:SetWordWrap(false)
  t.sub = UI.Label(t, "", "GameFontHighlightSmall")
  t.sub:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -4)
  t.sub:SetTextColor(0.7, 0.7, 0.7)
  t:SetScript("OnClick", function(self, mb)
    self:FadeHide()
    if mb ~= "RightButton" then PN.Open(ns.VERSION) end
  end)
  -- What the clicks do, on hover (Kim: the line itself stays short)
  t:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L["AB_PATCH"], 1, 1, 1)
    GameTooltip:AddLine(L["PN_TOAST_TIP"], 0.78, 0.78, 0.78, true)
    GameTooltip:Show()
  end)
  t:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
  t:HookScript("OnHide", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
  UI.Fader(t, { alpha = 1 })
  t:Hide()
  toast = t
end

function PN.Toast()
  if not toast then buildToast() end
  if ns.StatusDisplay and ns.StatusDisplay.Place then ns.StatusDisplay.Place(toast) end
  toast.sub:SetText(L["VERSION_FMT"]:format(ns.VERSION))
  toast:Show()
  local shown = toast
  C_Timer.After(TOAST_SECONDS, function() if shown:IsOpen() then shown:FadeHide(0.6) end end)
end

ns.Listen("ENABLE", function()
  local db = ns.db
  if not db then return end
  -- A new install gets the welcome, not the notes
  if not db.welcomed then db.notesSeen = ns.VERSION return end
  if db.notesSeen == ns.VERSION or not indexOf(ns.VERSION) then return end
  C_Timer.After(TOAST_DELAY, function()
    if db.notesSeen == ns.VERSION then return end
    db.notesSeen = ns.VERSION
    PN.Toast()
  end)
end)
