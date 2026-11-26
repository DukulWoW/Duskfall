-- Duskfall UI/SimpleStyles.lua: the Styles tab in simple mode, the default (Kim, 2026-11-26). One
-- question: how should changes feel? Three cards (Instant, Smooth, Like your eyes), each with a
-- small drawing of what the light does over time; one Speed slider that scales every duration;
-- Try it; Share and Import. It changes the Style this character uses. The Style list, scopes and
-- the separate timings are Advanced mode (UI/Styles.lua).
-- Speed: factor = 2 ^ (speed * 1.3), speed -1 .. 1 (0.4x .. 2.5x). Fade 1.5 s, Adapt 4.0 s darker and
-- 1.0 s brighter at 1x (the defaults); all three are set together, so switching mode keeps the pace.
-- Public: ns.SimpleStyles.Create(parent) -> frame
local ADDON, ns = ...
local UI, R = ns.UI, ns.Resolver
local SS = {}
ns.SimpleStyles = SS

local GREY = "|cff9d9d9d"
local CARD_H, CARD_GAP = 206, 14
local GRAPH_W, GRAPH_H, COLS = 190, 64, 30
local BASE = { fade = 1.5, dark = 4.0, light = 1.0 }
local K = 1.3

local CARDS = {
  { mode = "instant", name = "Instant", desc = "The new look is there at once. Nothing to wait for." },
  { mode = "fade", name = "Smooth", desc = "A soft fade from one look to the next." },
  { mode = "adapt", name = "Like your eyes",
    desc = "Into the dark slowly, with a short dip, out into the light quickly, with a short glare. As real eyes adjust." },
}

-- Light over time for a step from bright to dark at t = 0.3 (0 .. 1).
local function ease(u) u = math.max(0, math.min(1, u)) return u * u * (3 - 2 * u) end
local CURVES = {
  instant = function(t) if t < 0.3 then return 1 end return 0.3 end,
  fade = function(t) if t < 0.3 then return 1 end return 1 - 0.7 * ease((t - 0.3) / 0.45) end,
  adapt = function(t)
    if t < 0.3 then return 1 end
    local u = (t - 0.3) / 0.7
    if u < 0.3 then return 1 - 0.9 * ease(u / 0.3) end
    return 0.1 + 0.2 * ease((u - 0.3) / 0.7)
  end,
}

local function log2(x) return math.log(x) / math.log(2) end
local function round1(x) return math.floor(x * 10 + 0.5) / 10 end

function SS.Create(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()
  f:Hide()
  local refresh

  local function style() return R.ActiveStyle() end
  local function tr() return ns.StyleTransition(style()) end

  local title = UI.Label(f, "How should changes feel?", "GameFontNormalHuge")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -14)
  local sub = UI.Label(f, "When the screen changes, for example when you walk from the sun into a cave.", "GameFontHighlight")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  sub:SetTextColor(0.7, 0.7, 0.7)

  -- Cards ----------------------------------------------------------------------------------------
  local cards = {}
  local cardW = math.floor((728 - 2 * CARD_GAP) / 3)
  for i, def in ipairs(CARDS) do
    local c = CreateFrame("Button", nil, f)
    c:SetSize(cardW, CARD_H)
    c:SetPoint("TOPLEFT", f, "TOPLEFT", 12 + (i - 1) * (cardW + CARD_GAP), -78)
    c.normal = UI.RoundBox(c, { radius = 12, bottom = { 0, 0, 0, 0.5 }, top = { 0.16, 0.12, 0.08, 0.45 },
      border = { 1, 0.82, 0, 0.25 } })
    local on = CreateFrame("Frame", nil, c)
    on:SetAllPoints()
    c.picked = UI.RoundBox(on, { radius = 12, sub = 3, bottom = { 0.3, 0.2, 0.04, 0.55 }, top = { 0.62, 0.46, 0.12, 0.55 },
      border = { 1, 0.85, 0.3, 0.9 } })
    local hl = c:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", c, "TOPLEFT", 3, -3)
    hl:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -3, 3)
    hl:SetColorTexture(1, 1, 1, 0.05)

    -- The drawing: light over time
    local graph = CreateFrame("Frame", nil, on)
    graph:SetSize(GRAPH_W, GRAPH_H)
    graph:SetPoint("TOP", c, "TOP", 0, -20)
    local floor = graph:CreateTexture(nil, "ARTWORK")
    floor:SetColorTexture(1, 0.82, 0, 0.25)
    floor:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", 0, -2)
    floor:SetPoint("BOTTOMRIGHT", graph, "BOTTOMRIGHT", 0, -2)
    floor:SetHeight(1)
    local colW = GRAPH_W / COLS
    local curve = CURVES[def.mode]
    for n = 0, COLS - 1 do
      local v = curve((n + 0.5) / COLS)
      local bar = graph:CreateTexture(nil, "ARTWORK", nil, 1)
      bar:SetSize(math.max(1, colW - 1.5), 3 + v * (GRAPH_H - 3))
      bar:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", n * colW, 0)
      UI.Gradient(bar, "VERTICAL", { 0.35 * v + 0.1, 0.25 * v + 0.08, 0.1 * v + 0.06, 0.95 },
        { 0.55 + 0.45 * v, 0.42 + 0.45 * v, 0.2 + 0.4 * v, 0.95 })
    end

    local name = UI.Label(on, def.name, "GameFontNormalLarge")
    name:SetPoint("TOP", graph, "BOTTOM", 0, -18)
    local desc = UI.Label(on, def.desc, "GameFontHighlight")
    desc:SetPoint("TOP", name, "BOTTOM", 0, -8)
    desc:SetWidth(cardW - 28)
    desc:SetJustifyH("CENTER")
    desc:SetSpacing(2)
    desc:SetTextColor(0.8, 0.8, 0.8)

    c:SetScript("OnClick", function()
      tr().mode = def.mode
      refresh()
    end)
    c.def = def
    cards[i] = c
  end

  -- Speed --------------------------------------------------------------------------------------
  local function speedOf()
    local t = tr()
    local x
    if t.mode == "fade" then x = (tonumber(t.fade.duration) or BASE.fade) / BASE.fade
    else x = (tonumber(t.adapt.toDark.duration) or BASE.dark) / BASE.dark end
    if x <= 0 then return -1 end
    return math.max(-1, math.min(1, log2(x) / K))
  end
  local function summary(sp)
    local t = tr()
    local x = 2 ^ (sp * K)
    if t.mode == "fade" then return string.format("%.1f s", round1(BASE.fade * x)) end
    return string.format("%.1f s / %.1f s", round1(BASE.dark * x), round1(BASE.light * x))
  end
  local speed = UI.LightSlider(f, 560, { label = "Speed", min = -1, max = 1, step = 0.1,
    from = { 1, 0.84, 0.45 }, to = { 0.2, 0.24, 0.5 },
    tip = "Left: quicker. Right: slower. The middle is the default pace.",
    fmt = function(v) return summary(v) end,
    zero = function() return GREY .. summary(0) .. "|r" end,
    get = function() return speedOf() end,
    set = function(v)
      local x = 2 ^ (v * K)
      local t = tr()
      t.fade.duration = round1(BASE.fade * x)
      t.adapt.toDark.duration = round1(BASE.dark * x)
      t.adapt.toLight.duration = round1(BASE.light * x)
    end })
  speed:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -(78 + CARD_H + 22))
  local speedNote = UI.Label(f, "")
  speedNote:SetPoint("TOPLEFT", speed, "BOTTOMLEFT", 90, -2)
  speedNote:SetTextColor(0.6, 0.6, 0.6)

  local tryBtn
  tryBtn = UI.Button(f, "Try it", 120, function()
    local total = ns.TryStyle(style())
    if not total then return end
    tryBtn:SetEnabled(false)
    C_Timer.After(total, function() tryBtn:SetEnabled(true) end)
  end, 26)
  tryBtn:SetPoint("LEFT", speed, "RIGHT", 24, 0)
  UI.Tooltip(tryBtn, "Try it", "Goes darker, waits, and comes back, the way you picked, wherever you are.")

  -- Share --------------------------------------------------------------------------------------
  local share
  share = UI.Button(f, "Share this Style", 150, function()
    UI.Copy(style().name, ns.Share.ExportStyle(style()), share)
  end)
  share:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 8)
  UI.Tooltip(share, "Share this Style", "Copies the Style, with every place you set, as a line of text to give to a friend.")
  local import = UI.Button(f, "Import", 100, function() ns.Share.ImportDialog(function() refresh() end) end)
  import:SetPoint("LEFT", share, "RIGHT", 8, 0)
  UI.Tooltip(import, "Import", "Paste a Style or a setting someone exported.")
  local foot = UI.Label(f, "")
  foot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 14)
  foot:SetJustifyH("RIGHT")
  foot:SetTextColor(0.6, 0.6, 0.6)

  refresh = function()
    if not f:IsVisible() then return end
    local mode = tr().mode
    for _, c in ipairs(cards) do c.picked:SetShown(c.def.mode == mode) end
    speed:Refresh()
    speed:SetEnabled(mode ~= "instant")
    if mode == "instant" then speedNote:SetText("Instant has no speed.")
    elseif mode == "fade" then speedNote:SetText("How long a fade takes.")
    else speedNote:SetText("Into the dark / out into the light.") end
    local n = #ns.db.styles
    local t = "Style: |cffc0c0c0" .. (style().name or "?") .. "|r"
    if n > 1 then t = t .. "   " .. GREY .. "(" .. n .. " Styles: Advanced mode picks who uses which)|r" end
    foot:SetText(t)
  end

  f:SetScript("OnShow", function() refresh() end)
  ns.Listen("MODE", function() refresh() end)
  return f
end
