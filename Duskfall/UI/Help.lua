-- Duskfall UI/Help.lua: how Duskfall works, in short topics (Kim, 2026-11-26). Opened by the help
-- button between Advanced and the close button; it lies over the tabs until closed (the button
-- again, Close, or ESC). Topics on the left, the text on the right.
-- Public: ns.Help.Toggle(), ns.Help.Open(key), ns.Help.Shown(), ns.Help.Hide()
local ADDON, ns = ...
local UI, W = ns.UI, ns.Window
local L = ns.L
local H = {}
ns.Help = H

-- Links (Kim, 2026-11-27, as BNB's help): Duskfall blue text that opens what it names (gold stays for
-- names that only stand out, Kim). Targets:
-- settings:<page>, tab:<id>, calibrate, notes (the OnHyperlinkClick in build)
local function LINK(target, text) return "|cff5c80ff|Hdusk:" .. target .. "|h" .. text .. "|h|r" end
-- Pictures in the text (Kim): our own art, inline
local ART = "Interface\\AddOns\\Duskfall\\Assets\\"
local function PIC(file, size) return "|T" .. ART .. file .. ":" .. (size or 16) .. "|t" end
-- Topic keys for ns.Help.Open (the "?" icons next to features)
local KEYS = { start = 1, wins = 2, time = 3, feel = 4, own = 5, modes = 6, sharing = 7, starter = 8, others = 9,
               compare = 10, hdr = 11, sounds = 12, commands = 13 }

-- The topics in KEYS order, from Locales/enUS.lua: HELP_<KEY> (the title) and HELP_<KEY>_1, _2, ...
-- (the paragraphs). In the text, [[target|text]] is a link and {pic:file} a picture (Assets/file).
local function expand(s)
  s = s:gsub("%[%[([^|%]]+)|([^%]]+)%]%]", function(target, text) return LINK(target, text) end)
  return (s:gsub("{pic:([^}]+)}", function(file) return PIC(file) end))
end
local TOPICS = {}
do
  local order = {}
  for key, i in pairs(KEYS) do order[i] = key end
  for i, key in ipairs(order) do
    local K = "HELP_" .. key:upper()
    local paras = {}
    local n = 1
    while ns.HasL(K .. "_" .. n) do
      paras[#paras + 1] = expand(L[K .. "_" .. n])
      n = n + 1
    end
    TOPICS[i] = { L[K], paras }
  end
end

local frame, buttons, body, heading = nil, {}, nil, nil
local current = 1

local function show(i)
  current = i
  heading:SetText(TOPICS[i][1])
  body:SetText(table.concat(TOPICS[i][2], "\n\n"))
  for n, b in ipairs(buttons) do
    b.pick:SetShown(n == i)
    -- Dark on the gold, without the drop shadow (it smeared the letters, Kim)
    if n == i then
      b.text:SetTextColor(0.14, 0.08, 0)
      b.text:SetShadowOffset(0, 0)
    else
      b.text:SetTextColor(1, 0.82, 0)
      b.text:SetShadowOffset(1, -1)
    end
  end
end

local function build()
  -- An overlay over the pages (W.NewOverlay: wood, title, Close, fades, hides the page and strip)
  local f = W.NewOverlay(L["HELP_TITLE"])
  -- Patch Notes next to Close (Kim)
  local notes = UI.Button(f, L["AB_PATCH"], 120, function() if ns.PatchNotes then ns.PatchNotes.Open() end end)
  notes:SetPoint("RIGHT", f.closeBtn, "LEFT", -8, 0)

  -- Topics
  local list = CreateFrame("Frame", nil, f)
  list:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -56)
  list:SetSize(200, #TOPICS * 34 + 12)
  UI.RoundBox(list, { radius = 10, bottom = { 0, 0, 0, 0.45 }, top = { 0.14, 0.11, 0.07, 0.4 },
    border = { 1, 0.82, 0, 0.25 } })
  for i, t in ipairs(TOPICS) do
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
    b.text = UI.Label(top, t[1], "GameFontNormal")
    b.text:SetPoint("LEFT", b, "LEFT", 12, 0)
    b.text:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    b.text:SetWordWrap(false)
    -- A long translated topic gets a smaller font, then two lines
    local _, base = b.text:GetFont()
    if UI.FitText(b.text, 164, base) then
      b.text:SetWordWrap(true)
      if b.text.SetMaxLines then b.text:SetMaxLines(2) end
    end
    b:SetScript("OnClick", function() show(i) end)
    buttons[i] = b
  end

  -- Text
  local page = CreateFrame("Frame", nil, f)
  page:SetPoint("TOPLEFT", list, "TOPRIGHT", 20, 0)
  page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 20)
  UI.RoundBox(page, { radius = 12, bottom = { 0, 0, 0, 0.4 }, top = { 0.16, 0.12, 0.08, 0.35 },
    border = { 1, 0.82, 0, 0.2 } })
  heading = UI.Label(page, "", "GameFontNormalLarge")
  heading:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -18)
  -- Blue links open what they name (LINK above)
  if page.SetHyperlinksEnabled then page:SetHyperlinksEnabled(true) end
  page:SetScript("OnHyperlinkClick", function(_, link)
    local target = type(link) == "string" and link:match("^dusk:(.+)$")
    if not target then return end
    local setting = target:match("^settings:(.+)$")
    local tab = target:match("^tab:(.+)$")
    if setting then
      if ns.OpenSettingsPage then ns.OpenSettingsPage(setting) end
    elseif tab then
      W.CloseOverlays(true)
      ns.OpenWindow(tab, true)
    elseif target == "calibrate" then
      if ns.OpenSettingsPage then ns.OpenSettingsPage("baseline") end
      if ns.Calibrate then ns.Calibrate.Open() end
    elseif target == "notes" then
      W.CloseOverlays(true)
      if ns.PatchNotes then ns.PatchNotes.Open() end
    end
  end)
  page:SetScript("OnHyperlinkEnter", function(self, _, text)
    local name = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:AddLine(L["HELP_OPEN"]:format(name), 1, 1, 1)
    GameTooltip:Show()
  end)
  page:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
  body = UI.Label(page, "", "GameFontHighlight")
  body:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -14)
  body:SetPoint("RIGHT", page, "RIGHT", -20, 0)
  body:SetJustifyV("TOP")
  body:SetSpacing(4)
  body:SetTextColor(0.9, 0.88, 0.84)

  frame = f
  show(current)
end

function H.Shown() return frame ~= nil and frame:IsOpen() end
function H.Open(key)
  if not W.frame then return end
  if not frame then build() end
  frame:Show()
  show(KEYS[key] or current)
end
function H.Hide() if frame then frame:FadeHide() end end
function H.Toggle()
  if not W.frame then return end
  if not frame then build() end
  if frame:IsOpen() then frame:FadeHide() else frame:Show() end
end
