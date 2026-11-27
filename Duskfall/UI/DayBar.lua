-- Duskfall UI/DayBar.lua: the parts of the day as a 24 hour bar.
--
--   Now 21:38 - Night
--   |## Night ##|== Dawn ==|------ Day ------|== Dusk ==|## Night ##|
--   0           5          8                17         20          24
--
-- Drag an edge to move when a part starts (whole hours; an edge never passes its neighbours, so
-- the order Dawn < Day < Dusk < Night always holds). Under the bar a 2 x 2 grid of cards, one per part, with its icon
-- (BNB's ui-dawn / day / dusk / night) and from - to. Reset puts back 5, 8, 17, 20.
-- Public: UI.DayBar(parent, width) -> holder with :Refresh()
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

local ORDER = { "dawn", "day", "dusk", "night" }
local NAME = { dawn = L["PERIOD_DAWN"], day = L["PERIOD_DAY"], dusk = L["PERIOD_DUSK"], night = L["PERIOD_NIGHT"] }
local COLOR = {
  night = { 0.13, 0.17, 0.42 },
  dawn  = { 0.86, 0.47, 0.52 },
  day   = { 0.98, 0.88, 0.52 },
  dusk  = { 0.86, 0.56, 0.24 },
}
local TEXT_COLOR = { night = { 0.85, 0.88, 1 }, dawn = { 0.15, 0.05, 0.05 }, day = { 0.2, 0.15, 0.05 }, dusk = { 0.15, 0.07, 0 } }
local DEFAULT = { dawn = 5, day = 8, dusk = 17, night = 20 }
local BAR_H, HANDLE_W = 26, 10
local GRID_TOP = 20 + BAR_H + 34          -- the cards start under the hour ticks
local CARD_H, CARD_GAP = 72, 12

function UI.DayBar(parent, width)
  local h = CreateFrame("Frame", nil, parent)
  h:SetSize(width, GRID_TOP + 2 * CARD_H + CARD_GAP)

  local nowText = UI.Label(h, "", "GameFontHighlight")
  nowText:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)

  local bar = CreateFrame("Frame", nil, h)
  bar:SetPoint("TOPLEFT", h, "TOPLEFT", 0, -20)
  bar:SetSize(width, BAR_H)
  local frameTex = bar:CreateTexture(nil, "BACKGROUND")
  frameTex:SetPoint("TOPLEFT", -1, 1)
  frameTex:SetPoint("BOTTOMRIGHT", 1, -1)
  frameTex:SetColorTexture(0, 0, 0, 0.8)

  -- Five segments: night before dawn, dawn, day, dusk, night after. Each is two halves shaded
  -- from the halfway colour at its edge to its own colour in the middle, so the parts of the
  -- day melt into each other (Kim: not flat).
  local SEQ = { "night", "dawn", "day", "dusk", "night" }
  local function mix(a, b) return { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2 } end
  local segs = {}
  for i, key in ipairs(SEQ) do
    local own = COLOR[key]
    local before = mix(COLOR[SEQ[i - 1] or "night"], own)
    local after = mix(own, COLOR[SEQ[i + 1] or "night"])
    local l = bar:CreateTexture(nil, "ARTWORK")
    UI.Gradient(l, "HORIZONTAL", before, own)
    local r = bar:CreateTexture(nil, "ARTWORK")
    UI.Gradient(r, "HORIZONTAL", own, after)
    local fs = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetTextColor(TEXT_COLOR[key][1], TEXT_COLOR[key][2], TEXT_COLOR[key][3])
    fs:SetShadowOffset(0, 0)
    segs[i] = { key = key, l = l, r = r, text = fs }
  end
  -- Light from above: a soft shine on the top half, a little shade on the bottom
  local shine = bar:CreateTexture(nil, "ARTWORK", nil, 3)
  shine:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
  shine:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
  shine:SetHeight(BAR_H / 2)
  UI.Gradient(shine, "VERTICAL", { 1, 1, 1, 0 }, { 1, 1, 1, 0.28 })
  local shade = bar:CreateTexture(nil, "ARTWORK", nil, 3)
  shade:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  shade:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  shade:SetHeight(BAR_H / 2)
  UI.Gradient(shade, "VERTICAL", { 0, 0, 0, 0.3 }, { 0, 0, 0, 0 })

  -- Hour ticks every 3 hours
  local ticks = {}
  for hr = 0, 24, 3 do
    local fs = UI.Label(h, "", "GameFontHighlightSmall")
    fs:SetTextColor(0.7, 0.7, 0.7)
    ticks[#ticks + 1] = { hr = hr, fs = fs }
  end

  -- Now marker
  local now = bar:CreateTexture(nil, "OVERLAY", nil, 2)
  now:SetColorTexture(1, 1, 1, 0.95)
  now:SetSize(2, BAR_H + 6)

  local function x(hour) return width * hour / 24 end
  local function buckets() return ns.cfg.buckets end

  -- Under the bar: the four parts as a 2 x 2 grid of cards, each tinted with its own colour (Kim)
  local lines = {}
  local cardW = math.floor((width - CARD_GAP) / 2)
  for i, key in ipairs(ORDER) do
    local card = CreateFrame("Frame", nil, h)
    card:SetSize(cardW, CARD_H)
    local cx = ((i - 1) % 2) * (cardW + CARD_GAP)
    local cy = -(GRID_TOP + math.floor((i - 1) / 2) * (CARD_H + CARD_GAP))
    card:SetPoint("TOPLEFT", h, "TOPLEFT", cx, cy)
    local c = COLOR[key]
    UI.RoundBox(card, { radius = 10, bottom = { 0, 0, 0, 0.5 }, top = { c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 0.55 },
      border = { c[1], c[2], c[3], 0.45 } })
    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetSize(44, 44)
    icon:SetPoint("LEFT", card, "LEFT", 14, 0)
    icon:SetTexture(UI.ART .. "Day\\ui-" .. key)
    local name = UI.Label(card, NAME[key], "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -2)
    name:SetTextColor(c[1] * 0.5 + 0.5, c[2] * 0.5 + 0.5, c[3] * 0.5 + 0.5)
    local span = UI.Label(card, "", "GameFontHighlightLarge")
    span:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 14, 2)
    lines[key] = span
  end

  local function draw()
    local b = buckets()
    local edges = { 0, b.dawn, b.day, b.dusk, b.night, 24 }
    for i, s in ipairs(segs) do
      local a, z = edges[i], edges[i + 1]
      s.l:ClearAllPoints()
      s.r:ClearAllPoints()
      s.text:ClearAllPoints()
      if z > a then
        local m = (a + z) / 2
        s.l:SetPoint("TOPLEFT", bar, "TOPLEFT", x(a), 0)
        s.l:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", x(m), 0)
        s.r:SetPoint("TOPLEFT", bar, "TOPLEFT", x(m), 0)
        s.r:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", x(z), 0)
        s.l:Show()
        s.r:Show()
        s.text:SetPoint("CENTER", bar, "LEFT", x(m), 0)
        s.text:SetText(NAME[s.key])
        if x(z) - x(a) > s.text:GetStringWidth() + 6 then s.text:Show() else s.text:Hide() end
      else
        s.l:Hide()
        s.r:Hide()
        s.text:Hide()
      end
    end
    for _, t in ipairs(ticks) do
      t.fs:ClearAllPoints()
      if t.hr == 24 and ns.cfg.clock24 then t.fs:SetText("24:00") else t.fs:SetText(ns.FormatHour(t.hr % 24)) end
      local point = "TOP"
      if t.hr == 0 then point = "TOPLEFT" elseif t.hr == 24 then point = "TOPRIGHT" end
      t.fs:SetPoint(point, bar, "BOTTOMLEFT", x(t.hr), -4)
    end
    for i, key in ipairs(ORDER) do
      local nextKey = ORDER[i % 4 + 1]
      lines[key]:SetText(ns.FormatHour(b[key]) .. "  -  " .. ns.FormatHour(b[nextKey]))
    end
  end

  local function drawNow()
    local env = ns.Situations.Snapshot()
    now:ClearAllPoints()
    now:SetPoint("CENTER", bar, "LEFT", x(env.hour + env.min / 60), 0)
    nowText:SetText(L["DAY_NOW"]:format(ns.FormatHour(env.hour, env.min), NAME[env.period]))
  end

  -- Handles on the four inner edges
  local handles = {}
  local dragging
  for i, key in ipairs(ORDER) do
    local hd = CreateFrame("Button", nil, bar)
    hd:SetSize(HANDLE_W, BAR_H + 10)
    hd:SetFrameLevel(bar:GetFrameLevel() + 5)
    local line = hd:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(1, 0.82, 0, 1)
    line:SetPoint("TOP")
    line:SetPoint("BOTTOM")
    line:SetWidth(2)
    local knob = hd:CreateTexture(nil, "OVERLAY", nil, 1)
    knob:SetColorTexture(1, 0.82, 0, 1)
    knob:SetSize(8, 8)
    knob:SetPoint("BOTTOM", hd, "BOTTOM", 0, 0)
    hd.line, hd.knob = line, knob
    hd:SetScript("OnEnter", function(self)
      line:SetColorTexture(1, 1, 1, 1)
      knob:SetColorTexture(1, 1, 1, 1)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(L["DAY_STARTS"]:format(NAME[key], ns.FormatHour(buckets()[key])), 1, 1, 1)
      GameTooltip:AddLine(L["DAY_DRAG"], 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end)
    hd:SetScript("OnLeave", function()
      if dragging ~= key then
        line:SetColorTexture(1, 0.82, 0, 1)
        knob:SetColorTexture(1, 0.82, 0, 1)
      end
      GameTooltip:Hide()
    end)
    hd:SetScript("OnMouseDown", function() dragging = key end)
    hd:SetScript("OnMouseUp", function()
      dragging = nil
      line:SetColorTexture(1, 0.82, 0, 1)
      knob:SetColorTexture(1, 0.82, 0, 1)
      ns.Detect.Evaluate("settings")
      drawNow()
    end)
    handles[i] = { key = key, btn = hd }
  end

  local function placeHandles()
    local b = buckets()
    for _, hd in ipairs(handles) do
      hd.btn:ClearAllPoints()
      hd.btn:SetPoint("CENTER", bar, "LEFT", x(b[hd.key]), -2)
    end
  end

  local elapsed = 0
  h:SetScript("OnUpdate", function(_, dt)
    if dragging then
      local scale = bar:GetEffectiveScale()
      local cx = GetCursorPosition() / scale
      local hour = math.floor((cx - bar:GetLeft()) / width * 24 + 0.5)
      local b = buckets()
      local i
      for n, key in ipairs(ORDER) do if key == dragging then i = n end end
      local lo = 0
      if i > 1 then lo = b[ORDER[i - 1]] + 1 end
      local hi = 23
      if i < 4 then hi = b[ORDER[i + 1]] - 1 end
      hour = math.max(lo, math.min(hi, hour))
      if hour ~= b[dragging] then
        b[dragging] = hour
        draw()
        placeHandles()
        if GameTooltip:IsShown() then
          GameTooltip:ClearLines()
          GameTooltip:AddLine(L["DAY_STARTS"]:format(NAME[dragging], ns.FormatHour(hour)), 1, 1, 1)
          GameTooltip:Show()
        end
      end
    end
    elapsed = elapsed + dt
    if elapsed > 15 then
      elapsed = 0
      drawNow()
    end
  end)

  local reset = UI.Button(h, L["DAY_RESET"], 140, function()
    for k, v in pairs(DEFAULT) do ns.cfg.buckets[k] = v end
    h:Refresh()
    ns.Detect.Evaluate("settings")
  end)
  h.resetBtn = reset   -- placed by the page (Time of day: in its bottom card)

  function h:Refresh()
    draw()
    placeHandles()
    drawNow()
  end
  h:SetScript("OnShow", function(self) self:Refresh() end)
  h:Refresh()
  return h
end
