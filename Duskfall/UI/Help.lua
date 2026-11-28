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
local KEYS = { start = 1, indicator = 2, wins = 3, time = 4, feel = 5, own = 6, modes = 7, sharing = 8, starter = 9,
               others = 10, compare = 11, hdr = 12, sounds = 13, commands = 14 }
local PITCH, ROW_H = 32, 28   -- topic rows (14 topics fit the window: pages never scroll)

-- The topics in KEYS order, from Locales/enUS.lua: HELP_<KEY> (the title) and HELP_<KEY>_1, _2, ...
-- (the paragraphs). In the text, [[target|text]] is a link and {pic:file} a picture (Assets/file).
-- Link targets: settings:<page>, tab:<id>, calibrate, notes, help:<topic key>.
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
    TOPICS[i] = { L[K], paras, key = key }
  end
end

local frame, buttons, body, heading = nil, {}, nil, nil
local current = 1
local demos = {}   -- topic key -> live sample frame (above the text)

-- The Day/Night indicator topic's live sample (Kim, 1.3.0): the game's own indicator art as it is
-- now (sun by day, moon by night; from the client, not copied), Duskfall's badge on its rim at the
-- hour, as on the minimap, and the glow ring breathing behind it.
local SAMPLE = 1.7
local function indicatorDemo(parent)
  local d = CreateFrame("Frame", nil, parent)
  d:SetSize(120, 76)
  local disc = d:CreateTexture(nil, "ARTWORK")
  local ring = d:CreateTexture(nil, "ARTWORK", nil, 1)
  local badge = d:CreateTexture(nil, "OVERLAY")
  badge:SetTexture(ART .. "icon")
  badge:SetSize(15 * SAMPLE, 15 * SAMPLE)
  local glow = UI.GlowRing(d, badge, 36 * SAMPLE)
  function d.Refresh()
    local art = ns.Moon and ns.Moon.Art and ns.Moon.Art() or {}
    local env = ns.Situations.Snapshot()
    local atlas = art.disc
    if not atlas then
      atlas = (env.period == "night") and "UI-HUD-Minimap-NightCycle" or "UI-HUD-Minimap-DayCycle"   --noloc
    end
    local dw = (art.discW and art.discW > 4 and art.discW or 30) * SAMPLE
    disc:SetSize(dw, dw)
    disc:ClearAllPoints()
    disc:SetPoint("CENTER", d, "LEFT", 14 + dw / 2, 0)
    if not pcall(disc.SetAtlas, disc, atlas) then disc:SetTexture(nil) end
    local rw = (art.ringW and art.ringW > 4 and art.ringW or dw / SAMPLE + 6) * SAMPLE
    ring:SetSize(rw, rw)
    ring:ClearAllPoints()
    ring:SetPoint("CENTER", disc, "CENTER")
    if not pcall(ring.SetAtlas, ring, art.ring or "UI-HUD-Minimap-Frame-Cycle") then ring:SetTexture(nil) end   --noloc
    local a = ((env.hour % 12) + env.min / 60) / 12 * 2 * math.pi
    local r = dw / 2 + SAMPLE
    badge:ClearAllPoints()
    badge:SetPoint("CENTER", disc, "CENTER", r * math.sin(a), r * math.cos(a))
  end
  d:SetScript("OnShow", function() ns.Safe(d.Refresh, "help sample") glow.Set(true) end)
  d:SetScript("OnHide", function() glow.Set(false) end)
  d:Hide()
  return d
end
local DEMO = { indicator = indicatorDemo }

local function show(i)
  current = i
  heading:SetText(TOPICS[i][1])
  body:SetText(table.concat(TOPICS[i][2], "\n\n"))
  -- A live sample above the text, for the topics that have one
  local key = TOPICS[i].key
  for k, d in pairs(demos) do d:SetShown(k == key) end
  -- On the indicator page, the welcome's arrow points at the real one too (Kim, 1.3.0)
  if ns.Welcome and ns.Welcome.Point then ns.Safe(ns.Welcome.Point, "help arrow", key == "indicator") end
  body:ClearAllPoints()
  if demos[key] then
    body:SetPoint("TOPLEFT", demos[key], "BOTTOMLEFT", 0, -8)
  else
    body:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -14)
  end
  body:SetPoint("RIGHT", body:GetParent(), "RIGHT", -20, 0)
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
  list:SetSize(200, #TOPICS * PITCH + 10)
  UI.RoundBox(list, { radius = 10, bottom = { 0, 0, 0, 0.45 }, top = { 0.14, 0.11, 0.07, 0.4 },
    border = { 1, 0.82, 0, 0.25 } })
  for i, t in ipairs(TOPICS) do
    local b = CreateFrame("Button", nil, list)
    b:SetSize(184, ROW_H)
    b:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -6 - (i - 1) * PITCH)
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
    elseif target:match("^help:") then
      local i = KEYS[target:match("^help:(.+)$")]
      if i then show(i) end
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
  for key, make in pairs(DEMO) do
    local d = make(page)
    d:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    demos[key] = d
  end

  frame = f
  f:HookScript("OnHide", function()
    if ns.Welcome and ns.Welcome.Point then ns.Safe(ns.Welcome.Point, "help arrow", false) end
  end)
  f:HookScript("OnShow", function() show(current) end)
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
