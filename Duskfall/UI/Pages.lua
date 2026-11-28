-- Duskfall UI/Pages.lua: the tabs of the settings window.
--   left:  Places (UI/Places.lua, loads first so it is the first tab), Styles (UI/Styles.lua, also before this file)
--   right: Settings (an overview of sub-pages, like BigNoteBox's Modules tab: General, Time of day,
--          Baseline, Characters), About (logo, version, links, commands)
local ADDON, ns = ...
local L = ns.L
local UI, W, C, D = ns.UI, ns.Window, ns.Channels, ns.Detect

ns.LINKS = {
  { key = "dukul", name = "Dukul.net", url = "https://dukul.net", sub = L["LINK_DUKUL_SUB"] },   --noloc
  { key = "github", name = "GitHub", url = "https://github.com/DukulWoW/Duskfall" },   --noloc
  { key = "curseforge", name = "CurseForge", url = "https://www.curseforge.com/wow/addons/duskfall" },   --noloc
  { key = "wago", name = "Wago", url = "https://addons.wago.io/addons/duskfall" },   --noloc
  { key = "discord", name = "Discord", url = "https://discord.gg/eDsQQkEPvU" },   --noloc
  { key = "bugs", name = L["LINK_BUGS"], url = "https://github.com/DukulWoW/Duskfall/issues/new/choose", sub = L["LINK_BUGS_SUB"] },
}

-- An hour in the chosen clock format: 21 -> "21:00" or "9 PM".
function ns.FormatHour(h, m)
  m = m or 0
  if ns.cfg.clock24 then return string.format("%02d:%02d", h, m) end
  local pm = h >= 12
  local h12 = h % 12
  if h12 == 0 then h12 = 12 end
  if m == 0 then return (pm and L["TIME_PM"] or L["TIME_AM"]):format(h12) end
  return (pm and L["TIME_PM_MIN"] or L["TIME_AM_MIN"]):format(h12, m)
end

-- Settings: sub-page builders ----------------------------------------------------------------------
local CONTENT_W = 700
local FULL_W = 728        -- the whole width of a sub-page (752) less its 12 px margins
local GAME_DEFAULT = { gamma = 1.0, brightness = 50, contrast = 50, bloom = 1.0 }

-- Stacks widgets from the top of a frame; every widget with :Refresh() is refreshed on show.
local function stacker(parent, y)
  local controls = {}
  y = y or -12
  local add = function(widget, h, gap, x)
    widget:SetPoint("TOPLEFT", parent, "TOPLEFT", 12 + (x or 0), y)
    y = y - (h or 26) - (gap or 8)
    controls[#controls + 1] = widget
    return widget
  end
  local refresh = function()
    for _, c in ipairs(controls) do
      if c.Refresh then c:Refresh() end
    end
  end
  return add, refresh
end

-- A card: a rounded, softly shaded box with a title and an optional line under it, as on Time of
-- day and Baseline (Kim). Returns the card and add(widget, h, gap, x) that stacks widgets inside.
local function card(p, x, y, w, h, title, desc, controls)
  local c = CreateFrame("Frame", nil, p)
  c:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
  c:SetSize(w, h)
  -- At the page's own level: the controls (children of the page) always draw over it
  c:SetFrameLevel(p:GetFrameLevel())
  UI.RoundBox(c, { radius = 10, bottom = { 0, 0, 0, 0.45 }, top = { 0.2, 0.15, 0.09, 0.4 },
    border = { 1, 0.82, 0, 0.22 } })
  local t = UI.Label(c, title, "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -14)
  local cy = -42
  if desc then
    local d = UI.Label(c, desc)
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
    d:SetWidth(w - 32)
    d:SetTextColor(0.68, 0.68, 0.68)
    cy = -42 - math.max(14, d:GetStringHeight()) - 4
  end
  local function add(widget, wh, gap, wx)
    widget:SetPoint("TOPLEFT", c, "TOPLEFT", 16 + (wx or 0), cy)
    cy = cy - (wh or 26) - (gap or 8)
    controls[#controls + 1] = widget
    return widget
  end
  return c, add
end

local function refresher(controls)
  return function()
    for _, c in ipairs(controls) do
      if c.Refresh then c:Refresh() end
    end
  end
end

local function buildGeneral(p)
  local controls = {}
  -- Top row (Kim, 2026-11-27): Duskfall on the left, Sound on the right
  local HALF = math.floor((FULL_W - 12) / 2)
  local _, top = card(p, 12, -50, HALF, 108, "Duskfall", nil, controls)   --noloc
  top(UI.Check(p, { label = L["GEN_ON"], tip = L["SET_ON_TIP"],
    get = function() return ns.cfg.enabled end,
    set = function(v) D.SetEnabled(v) W.UpdateStatus() end }), 26, 4)
  top(UI.Check(p, { label = L["GEN_DEBUG"], tip = L["GEN_DEBUG_TIP"],
    get = function() return ns.cfg.debug end,
    set = function(v) ns.cfg.debug = v end }), 26, 4)

  -- Sound (Core/Sound.lua): two sounds, each on / off with its own choice and a Play button; the
  -- channel on the title line
  local SND = ns.Sound
  local sc = card(p, 12 + HALF + 12, -50, HALF, 108, L["GEN_SOUND"], nil, controls)
  local chan = UI.Dropdown(p, 132, { tip = L["GEN_CHANNEL_TIP"],
    items = function()
      local out = {}
      for _, c in ipairs(SND.CHANNELS) do out[#out + 1] = { c[1], c[2] } end
      return out
    end,
    get = function() return ns.cfg.soundChannel end,
    set = function(v) ns.cfg.soundChannel = v end })
  chan:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -14, 6)
  controls[#controls + 1] = chan
  local function soundRow(y, label, tip, onKey, nameKey)
    local sw = UI.Check(p, { label = label, tip = tip,
      get = function() return ns.cfg[onKey] end,
      set = function(v) ns.cfg[onKey] = v end })
    sw:SetPoint("TOPLEFT", sc, "TOPLEFT", 16, y)
    controls[#controls + 1] = sw
    -- The sound dropdowns line up with the channel's on the right, Play to their left (Kim)
    local dd = UI.Dropdown(p, 132, { tip = L["GEN_SOUND_TIP"],
      items = function()
        local out = {}
        for _, n in ipairs(SND.List()) do out[#out + 1] = { n, SND.Label(n) } end
        return out
      end,
      get = function() return ns.cfg[nameKey] end,
      set = function(v) ns.cfg[nameKey] = v SND.Play(v) end })
    dd:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -14, y + 16)
    controls[#controls + 1] = dd
    -- Play as an icon in every language (Kim, 1.2.0: "Abspielen" ran into the switch's label)
    local play = UI.Button(p, "", 26, function() SND.Play(ns.cfg[nameKey]) end, 22)
    play:SetGlyph("play", 12)
    play:SetPoint("RIGHT", dd._dd, "LEFT", -6, 0)
    UI.Tooltip(play, L["GEN_PLAY"], L["GEN_PLAY_TIP"])
  end
  soundRow(-42, L["GEN_NEW_PLACE"], L["GEN_NEW_PLACE_TIP"],
    "soundNew", "soundNewName")
  soundRow(-72, L["GEN_SETTING_STARTS"], L["GEN_SETTING_STARTS_TIP"],
    "soundActive", "soundActiveName")

  local SL_W = FULL_W - 32
  -- Timing and keys (Kim, 2026-11-27): the two timings side by side, Hold to brighten under them
  local _, timing = card(p, 12, -170, FULL_W, 166, L["GEN_TIMING"], L["GEN_TIMING_DESC"], controls)
  local HALF_SL = math.floor((SL_W - 24) / 2)
  local door = timing(UI.Slider(p, HALF_SL, { label = L["GEN_DOORWAY"], min = 0, max = 2, step = 0.1, default = 0.5,
    fmt = function(v) return L["SECS_FMT"]:format(v) end,
    tip = L["GEN_DOORWAY_TIP"],
    get = function() return ns.cfg.debounce end,
    onChange = function(v) ns.cfg.debounce = v end }), UI.SLIDER_H, 10)
  local gap = UI.Slider(p, HALF_SL, { label = L["GEN_GAP"], min = 0, max = 10, step = 0.5, default = 2,
    fmt = function(v) return L["SECS_FMT"]:format(v) end,
    tip = L["GEN_GAP_TIP"],
    get = function() return ns.cfg.adaptGap end,
    onChange = function(v) ns.cfg.adaptGap = v end })
  gap:SetPoint("TOPLEFT", door, "TOPLEFT", HALF_SL + 24, 0)
  controls[#controls + 1] = gap
  timing(UI.Slider(p, SL_W, { label = L["BIND_PEEK"], min = 0, max = 1, step = 0.05, default = 0.5,
    fmt = function(v) return L["PCT_FMT"]:format(math.floor(v * 100 + 0.5)) end,
    tip = L["GEN_PEEK_TIP"],
    get = function() return ns.cfg.peekLift end,
    onChange = function(v) ns.cfg.peekLift = v end }), UI.SLIDER_H, 10)

  -- Factory reset (Kim, 2026-11-26): a red box at the bottom, one button per kind of reset, each
  -- asks first. None of them can be undone.
  local danger = CreateFrame("Frame", nil, p)
  danger:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -348)
  danger:SetSize(FULL_W, 136)
  danger:SetFrameLevel(p:GetFrameLevel())
  UI.RoundBox(danger, { radius = 10, bottom = { 0.12, 0.02, 0.01, 0.55 }, top = { 0.3, 0.06, 0.04, 0.45 },
    border = { 0.95, 0.35, 0.22, 0.5 } })
  local dTitle = UI.Label(danger, L["GEN_FACTORY"], "GameFontNormalLarge")
  dTitle:SetPoint("TOPLEFT", danger, "TOPLEFT", 16, -14)
  dTitle:SetTextColor(1, 0.55, 0.4)
  local dDesc = UI.Label(danger, L["GEN_FACTORY_DESC"])
  dDesc:SetPoint("LEFT", dTitle, "RIGHT", 12, -1)
  dDesc:SetTextColor(0.75, 0.65, 0.6)

  local function after()
    D.ClearHolds()
    D.state.target = nil
    D.Evaluate("edit")
    W.UpdateStatus()
  end
  -- { button, tooltip, question, action, caption under the button }
  local RESETS = {
    { L["TAB_SETTINGS"], L["RS_SETTINGS_TIP"], L["RS_SETTINGS_Q"], function()
        local mm = ns.cfg.minimap   -- the minimap button library keeps this very table
        wipe(ns.cfg)
        for k, v in pairs(ns.DEFAULTS) do ns.cfg[k] = UI.DeepCopy(v) end
        if type(mm) == "table" then
          wipe(mm)
          for k, v in pairs(ns.cfg.minimap) do mm[k] = v end
          ns.cfg.minimap = mm
        end
        D.SetEnabled(ns.cfg.enabled)
        W.SetAdvanced(false)
        if ns.Moon then ns.Moon.Apply() ns.Moon.UpdateRings() end
        if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
        if ns.UpdateBroker then ns.UpdateBroker() end
        if ns.StatusDisplay then ns.StatusDisplay.ResetPosition() ns.StatusDisplay.Refresh() end
        if ns.CursorLight then ns.CursorLight.Refresh() end
        after()
      end, L["RS_SETTINGS_CAP"] },
    { L["RS_PLACES"], L["RS_PLACES_TIP"], L["RS_PLACES_Q"], function()
        wipe(ns.Resolver.ActiveStyle().looks)
        after()
      end, L["RS_PLACES_CAP"] },
    { L["RS_FOUND"], L["RS_FOUND_TIP"], L["RS_FOUND_Q"], function()
        wipe(ns.db.places)
        after()
      end, L["RS_FOUND_CAP"] },
    { L["RS_SCREEN"], L["RS_SCREEN_TIP"], L["RS_SCREEN_Q"], function()
        ns.Transition.Cancel()
        C.WriteAll(GAME_DEFAULT)
        D.SaveBaseline()
        after()
      end, L["RS_SCREEN_CAP"] },
    { L["RS_ALL"], L["RS_ALL_TIP"], L["RS_ALL_Q"], function()
        ns.Transition.Cancel()
        if ns.db and ns.db.baseline then C.WriteAll(ns.db.baseline) end
        DuskfallDB = nil
        ReloadUI()
      end, L["RS_ALL_CAP"] },
  }
  local BW = math.floor((FULL_W - 32 - (#RESETS - 1) * 8) / #RESETS)
  for i, r in ipairs(RESETS) do
    local b = UI.Button(danger, r[1], BW, function()
      UI.Confirm(L["GEN_CANT_UNDO"]:format(r[3]), function() ns.Safe(r[4], "reset " .. r[1]) end)
    end, 24)
    b:SetKind("danger")
    b:SetPoint("TOPLEFT", danger, "TOPLEFT", 16 + (i - 1) * (BW + 8), -54)
    UI.Tooltip(b, L["GEN_RESET_TIP"]:format(r[1]), r[2])
    local cap = UI.Label(danger, r[5])
    cap:SetPoint("TOP", b, "BOTTOM", 0, -8)
    cap:SetWidth(BW)
    cap:SetJustifyH("CENTER")
    cap:SetTextColor(0.78, 0.66, 0.6)
  end
  return refresher(controls)
end

local function buildTime(p)
  local add, refresh = stacker(p, -48)
  -- The two dropdowns as wide as the day cards below and over them (Kim): (FULL_W - 12) / 2, 12 apart
  local DD_W = math.floor((FULL_W - 12) / 2)
  local bar
  local src = UI.Dropdown(p, DD_W, { label = L["TM_SOURCE"],
    tip = L["TM_SOURCE_TIP"],
    items = { { "server", L["TM_SERVER"] }, { "local", L["TM_LOCAL"] } },
    get = function() return ns.cfg.clock end,
    set = function(v) ns.cfg.clock = v D.Evaluate("settings") if bar then bar:Refresh() end end })
  add(src, UI.DROPDOWN_H, 8)
  local fmt = UI.Dropdown(p, DD_W, { label = L["TM_FORMAT"],
    items = { { true, L["TM_24"] }, { false, L["TM_12"] } },
    get = function() return ns.cfg.clock24 end,
    set = function(v) ns.cfg.clock24 = v if bar then bar:Refresh() end end })
  fmt:SetPoint("TOPLEFT", src, "TOPRIGHT", 12, 0)
  local partsHead = UI.Header(p, L["TM_PARTS"])
  add(partsHead, 14, 4)
  local partsHelp = UI.HelpIcon(p, "time", L["TM_PARTS"], L["TM_PARTS_TIP"])
  partsHelp:SetPoint("LEFT", partsHead, "RIGHT", 6, 0)
  local help = UI.Label(p, L["TM_HELP"])
  help:SetWidth(FULL_W)
  add(help, 14, 12)
  bar = UI.DayBar(p, FULL_W)
  add(bar, bar:GetHeight(), 8)
  -- Bottom card (Kim): what happens when a part of the day begins; the day bar's Reset in it
  local tc = UI.Card(p, 12, 0, FULL_W, 96)
  tc:ClearAllPoints()
  tc:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -12)
  local tcTitle = UI.Label(tc, L["TM_BEGINS"], "GameFontNormalLarge")
  tcTitle:SetPoint("TOPLEFT", tc, "TOPLEFT", 16, -14)
  local fade = UI.Slider(p, FULL_W - 32, { label = L["TM_FADE"], min = 0, max = 120, step = 5, default = 45,
    fmt = function(v) return L["SECS_INT"]:format(v) end,
    tip = L["TM_FADE_TIP"],
    get = function() return ns.cfg.timeFade end,
    onChange = function(v) ns.cfg.timeFade = v end })
  fade:SetPoint("TOPLEFT", tc, "TOPLEFT", 16, -44)
  if bar.resetBtn then
    bar.resetBtn:SetParent(p)
    bar.resetBtn:ClearAllPoints()
    bar.resetBtn:SetPoint("TOPRIGHT", tc, "TOPRIGHT", -16, -12)
    UI.Tooltip(bar.resetBtn, L["DAY_RESET"], L["TM_RESET_TIP"])
  end
  local r = refresh
  return function() r() fmt:Refresh() fade:Refresh() end
end

-- Baseline: the four values as cards in 2 x 2 (as Time of day), each with its value large and a
-- slider on the game's own range, the mark at the game's default. Moving one changes the
-- baseline at once, and the screen with it (settings are changes from it) (Kim, 2026-11-26).
local BASE_STEP = { gamma = 0.01, brightness = 1, contrast = 1, bloom = 0.05 }

local function buildBaseline(p)
  local text = UI.Label(p, L["BL_TEXT"])
  text:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -50)
  text:SetWidth(FULL_W)
  text:SetSpacing(2)

  local GAP, CARD_H = 12, 155   -- tall enough to fill down to the actions box (Kim)
  local cardW = math.floor((FULL_W - GAP) / 2)
  local cards = {}
  local pending = false
  local function apply()
    if pending then return end
    pending = true
    C_Timer.After(0.04, function()
      pending = false
      -- Off: the screen is the baseline itself, so it is written straight away
      if not ns.cfg.enabled then
        if ns.db.baseline then C.WriteAll(ns.db.baseline) end
        W.UpdateStatus()
        return
      end
      D.ClearHolds()
      D.state.target = nil
      D.Evaluate("edit")
    end)
  end
  for i, ch in ipairs(C.list) do
    local k = ch.key
    local g = UI.CHANNEL_GRADIENT[k]
    local card = CreateFrame("Frame", nil, p)
    card:SetSize(cardW, CARD_H)
    card:SetPoint("TOPLEFT", p, "TOPLEFT", 12 + ((i - 1) % 2) * (cardW + GAP), -92 - math.floor((i - 1) / 2) * (CARD_H + GAP))
    local t = g.to
    UI.RoundBox(card, { radius = 10, bottom = { 0, 0, 0, 0.5 }, top = { t[1] * 0.3, t[2] * 0.3, t[3] * 0.3, 0.55 },
      border = { t[1], t[2], t[3], 0.35 } })
    local name = UI.Label(card, ch.label, "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -14)
    local def = UI.Label(card, L["BL_GAME_DEFAULT"]:format(C.Format(k, GAME_DEFAULT[k])), "GameFontHighlightSmall")
    def:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    def:SetTextColor(0.6, 0.6, 0.6)
    local big = UI.Label(card, "", "GameFontHighlightHuge")
    big:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -14)
    big:SetJustifyH("RIGHT")
    local sl = UI.LightSlider(card, cardW - 24, { label = ch.label, labelW = 0, valueW = 0,
      min = ch.min, max = ch.max, step = BASE_STEP[k], mid = GAME_DEFAULT[k], from = g.from, to = g.to,
      get = function() return ns.db.baseline and ns.db.baseline[k] or GAME_DEFAULT[k] end,
      set = function(v)
        if not ns.db.baseline then return end
        ns.db.baseline[k] = tonumber(C.Format(k, C.Clamp(k, v)))
        big:SetText(C.Format(k, ns.db.baseline[k]))
        apply()
      end })
    sl:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 12, 10)
    cards[i] = { big = big, slider = sl, key = k }
    if k == "gamma" then
      -- Black-lift tint (1.3.0, Kim): for screens where Gamma does nothing (UI/BlackLift.lua)
      local lift = UI.Switch(card, { label = L["BL_LIFT"], tip = L["BL_LIFT_TIP"],
        get = function() return ns.cfg.blackLift == true end,
        set = function(v)
          ns.cfg.blackLift = v
          if ns.BlackLift then ns.BlackLift.Update() end
        end })
      lift:SetPoint("TOPLEFT", def, "BOTTOMLEFT", 0, -12)
      local _, size = lift.Text:GetFont()
      UI.FitText(lift.Text, cardW - 32 - 42, size)
      lift:SetLabel(lift.Text:GetText())
      cards[i].lift = lift
    end
  end

  local function refreshCards()
    for _, c in ipairs(cards) do
      c.slider:Refresh()
      if c.lift then c.lift:Refresh() end
      local v = ns.db.baseline and ns.db.baseline[c.key]
      c.big:SetText(v and C.Format(c.key, v) or "-")
    end
  end

  -- Actions in a rounded box at the bottom, the hint just above, as on Places (Kim)
  local actions = CreateFrame("Frame", nil, p)
  actions:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 12, 8)
  actions:SetSize(FULL_W, 46)
  actions:SetFrameLevel(p:GetFrameLevel())
  UI.RoundBox(actions, { radius = 10, bottom = { 0, 0, 0, 0.5 }, top = { 0.22, 0.17, 0.1, 0.4 },
    border = { 1, 0.82, 0, 0.12 } })
  local save = UI.Button(p, L["BL_USE_SCREEN"], 190, function()
    UI.Confirm(L["BL_USE_SCREEN_Q"], function()
      D.SaveBaseline()
      refreshCards()
      W.UpdateStatus()
    end)
  end)
  save:SetPoint("LEFT", actions, "LEFT", 10, 0)
  UI.Tooltip(save, L["BL_USE_SCREEN"], L["BL_USE_SCREEN_TIP"])
  local reset = UI.Button(p, L["BL_GAME_DEFAULTS"], 150, function()
    UI.Confirm(L["BL_GAME_DEFAULTS_Q"], function()
      if not ns.db.baseline then return end
      for k, v in pairs(GAME_DEFAULT) do ns.db.baseline[k] = v end
      refreshCards()
      apply()
    end)
  end)
  reset:SetPoint("LEFT", save, "RIGHT", 8, 0)
  local tip = UI.Label(p, L["BL_TIP"])
  tip:SetPoint("BOTTOMLEFT", actions, "TOPLEFT", 4, 6)
  tip:SetTextColor(0.7, 0.7, 0.7)
  -- Calibrate (Kim, 2026-11-27): grey squares to set the baseline by (UI/Calibrate.lua)
  local calib = UI.Button(p, L["BL_CALIBRATE"], 120, function() if ns.Calibrate then ns.Calibrate.Open() end end)
  calib:SetKind("main")
  calib:SetPoint("LEFT", reset, "RIGHT", 8, 0)
  UI.Tooltip(calib, L["BL_CALIBRATE"], L["BL_CALIBRATE_TIP"])
  local help = UI.HelpIcon(p, "own", L["SET_BASELINE"], L["BL_HELP_TIP"])
  help:SetPoint("LEFT", calib, "RIGHT", 10, 0)
  -- The row centred in its box (Kim, 1.3.1)
  local row = save:GetWidth() + 8 + reset:GetWidth() + 8 + calib:GetWidth() + 10 + help:GetWidth()
  save:ClearAllPoints()
  save:SetPoint("LEFT", actions, "LEFT", math.max(10, math.floor((FULL_W - row) / 2 + 0.5)), 0)
  return refreshCards
end

local function buildCharacters(p)
  local note = UI.Label(p, L["CH_NOTE"])
  note:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -48)
  note:SetPoint("RIGHT", p, "RIGHT", -12, 0)

  local box = CreateFrame("Frame", nil, p, "WowScrollBoxList")
  box:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -10)
  box:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -30, 10)
  local scroll = CreateFrame("EventFrame", nil, p, "MinimalScrollBar")
  scroll:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 0)
  scroll:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 8, 0)

  local refresh
  local view = CreateScrollBoxListLinearView()
  view:SetElementExtent(28)
  view:SetElementInitializer("Frame", function(row, e)
    if not row.name then
      row.shade = row:CreateTexture(nil, "BACKGROUND")
      row.shade:SetAllPoints()
      row.shade:SetColorTexture(0, 0, 0, 0.25)
      row.name = UI.Label(row, "", "GameFontHighlight")
      row.name:SetPoint("LEFT", row, "LEFT", 8, 0)
      row.name:SetWidth(230)
      row.info = UI.Label(row, "", "GameFontHighlightSmall")
      row.info:SetPoint("LEFT", row, "LEFT", 250, 0)
      row.info:SetTextColor(0.7, 0.7, 0.7)
      row.remove = UI.Button(row, L["BTN_REMOVE"], 80, nil, 20)
      row.remove:SetKind("danger")
      row.remove:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    end
    local c = e.c
    local name = c.name or "?"
    local col = c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
    if col and col.colorStr then name = "|c" .. col.colorStr .. name .. "|r" end
    if e.guid == ns.charKey then name = name .. "  |cff9d9d9d" .. L["SL_YOU"] .. "|r" end
    row.name:SetText(name)
    local styles, looks = ns.CharUse(e.guid)
    row.info:SetText(L["CH_LAST_SEEN"]:format(date("%Y-%m-%d", c.last or 0),
      styles == 1 and L["CH_STYLES_ONE"] or L["CH_STYLES_MANY"]:format(styles),
      looks == 1 and L["CH_LOOKS_ONE"] or L["CH_LOOKS_MANY"]:format(looks)))
    row.shade:SetShown(e.index % 2 == 0)
    row.remove:SetEnabled(e.guid ~= ns.charKey)
    row.remove:SetScript("OnClick", function()
      UI.Confirm(L["CH_REMOVE_Q"]:format(c.name or "?"), function()
        local emptied = ns.RemoveCharacter(e.guid)
        if emptied and emptied > 0 then
          ns.Print("|cffff9f40" .. L["SL_SCOPES_EMPTIED"] .. "|r", emptied)
        end
        D.state.target = nil
        D.Evaluate("chars")
        refresh()
      end)
    end)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(box, scroll, view)
  UI.AutoHideScroll(box, scroll)

  refresh = function()
    local list = {}
    for guid, c in pairs(ns.db.chars) do list[#list + 1] = { guid = guid, c = c } end
    table.sort(list, function(a, b) return (a.c.name or "") < (b.c.name or "") end)
    for i, e in ipairs(list) do e.index = i end
    box:SetDataProvider(CreateDataProvider(list))
  end
  return refresh
end

local function buildDisplay(p)
  local controls = {}
  local HALF = math.floor((FULL_W - 12) / 2)
  local DD_W = HALF - 32

  local _, mm = card(p, 12, -50, HALF, 262, L["DS_MINIMAP"], nil, controls)
  local indicator = mm(UI.Check(p, { label = L["DS_MOON"],
    tip = L["DS_MOON_TIP"],
    get = function() return ns.cfg.moon ~= false end,
    set = function(v)
      ns.cfg.moon = v
      ns.Moon.Apply()
      if v and not ns.Moon.Found() then ns.Print(L["DS_NO_MOON"]) end
    end }), 26, 4)
  -- "?" to the Help page about the indicator and its glow (Kim, 1.3.0)
  local indicatorHelp = UI.HelpIcon(p, "indicator", L["HELP_INDICATOR"], L["DS_MOON_HELP_TIP"])
  indicatorHelp:SetPoint("LEFT", indicator, "RIGHT", 6, 0)
  mm(UI.Check(p, { label = L["DS_GLOW"],
    tip = L["DS_GLOW_TIP"],
    get = function() return ns.cfg.ringGlow ~= false end,
    set = function(v)
      ns.cfg.ringGlow = v
      ns.Moon.UpdateRings()
    end }), 26, 10)
  mm(UI.Dropdown(p, DD_W, { label = L["DS_BUTTON"],
    tip = L["DS_BUTTON_TIP"],
    items = { { "auto", L["DS_AUTO"] }, { "always", L["DS_ALWAYS"] }, { "never", L["DS_NEVER"] } },
    get = function() return ns.cfg.minimapButton or "auto" end,
    set = function(v) ns.cfg.minimapButton = v ns.UpdateMinimapButton() end }), UI.DROPDOWN_H, 10)
  mm(UI.Dropdown(p, DD_W, { label = L["DS_BROKER"],
    tip = L["DS_BROKER_TIP"],
    items = { { "look", L["DS_BR_LOOK"] }, { "values", L["DS_BR_VALUES"] }, { "both", L["DS_BR_BOTH"] }, { "light", L["DS_BR_LIGHT"] }, { "none", L["DS_BR_NONE"] } },
    get = function() return ns.cfg.brokerText end,
    set = function(v) ns.cfg.brokerText = v ns.UpdateBroker() end }), UI.DROPDOWN_H, 8)

  -- The game's own colorblind filter (Options > Accessibility), here for quick switching (Kim).
  -- colorblindSimulator 0-3 and colorblindWeaknessFactor 0-1 exist on Forever (Kim, 2026-11-26:
  -- "0 0.5"). Read from the game each time, never stored by Duskfall.
  local function cvarNum(name, d) return tonumber(GetCVar(name)) or d end
  local _, cb = card(p, 12 + HALF + 12, -50, HALF, 262, L["DS_CB"], L["DS_CB_DESC"], controls)
  cb(UI.Dropdown(p, DD_W, { label = L["DS_FILTER"],
    items = { { 0, L["WIN_OFF"] }, { 1, L["DS_PROT"] }, { 2, L["DS_DEUT"] }, { 3, L["DS_TRIT"] } },
    get = function() return cvarNum("colorblindSimulator", 0) end,
    set = function(v) SetCVar("colorblindSimulator", v) end }), UI.DROPDOWN_H, 10)
  cb(UI.Slider(p, DD_W, { label = L["DS_STRENGTH"], min = 0, max = 1, step = 0.05, default = 0.5,
    fmt = function(v) return L["PCT_FMT"]:format(math.floor(v * 100 + 0.5)) end,
    tip = L["DS_STRENGTH_TIP"],
    get = function() return cvarNum("colorblindWeaknessFactor", 0.5) end,
    onChange = function(v) SetCVar("colorblindWeaknessFactor", v) end }), UI.SLIDER_H, 8)
  cb(UI.Check(p, { label = L["DS_CURSOR"],
    tip = L["DS_CURSOR_TIP"],
    get = function() return ns.cfg.cursorLight ~= false end,
    set = function(v) ns.cfg.cursorLight = v end }), 26, 4)
  cb(UI.Slider(p, DD_W, { label = L["DS_LIGHT"], min = 0.25, max = 3, step = 0.05, default = 1,
    fmt = function(v) return L["PCT_FMT"]:format(math.floor(v * 100 + 0.5)) end,
    tip = L["DS_LIGHT_TIP"],
    get = function() return tonumber(ns.cfg.cursorLightStrength) or 1 end,
    onChange = function(v)
      ns.cfg.cursorLightStrength = v
      if ns.CursorLight then ns.CursorLight.Refresh() end
    end }), UI.SLIDER_H, 8)

  local _, sd = card(p, 12, -324, FULL_W, 150, L["DS_STATUS"], L["DS_STATUS_DESC"], controls)
  -- Four in a row (1.3.0): Show, Stays, the Light slider, what it saves for
  local QW = math.floor((FULL_W - 32 - 3 * 12) / 4)
  local show = sd(UI.Dropdown(p, QW, { label = L["DS_SHOW"],
    items = { { "off", L["DS_NEVER"] }, { "change", L["DS_ON_CHANGE"] }, { "always", L["DS_ALWAYS"] } },
    get = function() return ns.cfg.statusDisplay end,
    set = function(v)
      ns.cfg.statusDisplay = v
      ns.StatusDisplay.Refresh(v == "change")
    end }), UI.DROPDOWN_H, 10)
  -- Stays (Kim, 2026-11-27): as long as the change runs, or some seconds after it
  local stays = UI.Dropdown(p, QW, { label = L["DS_STAYS"],
    tip = L["DS_STAYS_TIP"],
    items = { { "change", L["DS_AS_LONG"] }, { 2, L["DS_AFTER"]:format(2) }, { 4, L["DS_AFTER"]:format(4) },
              { 6, L["DS_AFTER"]:format(6) }, { 10, L["DS_AFTER"]:format(10) }, { 15, L["DS_AFTER"]:format(15) } },
    get = function()
      if ns.cfg.statusStay == "change" then return "change" end
      return tonumber(ns.cfg.statusSeconds) or 4
    end,
    set = function(v)
      if v == "change" then
        ns.cfg.statusStay = "change"
      else
        ns.cfg.statusStay = "seconds"
        ns.cfg.statusSeconds = v
      end
    end })
  stays:SetPoint("TOPLEFT", show, "TOPLEFT", QW + 12, 0)
  controls[#controls + 1] = stays
  local function sdRefresh() if ns.StatusDisplay then ns.StatusDisplay.Refresh() end end
  local ql = UI.Dropdown(p, QW, { label = L["QL_SHOW"], tip = L["QL_SHOW_TIP"],
    items = { { "status", L["QL_WITH_STATUS"] }, { "off", L["WIN_OFF"] } },
    get = function() return ns.cfg.quickLight or "status" end,
    set = function(v) ns.cfg.quickLight = v sdRefresh() end })
  ql:SetPoint("TOPLEFT", show, "TOPLEFT", 2 * (QW + 12), 0)
  controls[#controls + 1] = ql
  local qlFor = UI.Dropdown(p, QW, { label = L["QL_FOR"], tip = L["QL_FOR_TIP"],
    items = { { "place", L["QL_FOR_PLACE"] }, { "io", L["QL_FOR_IO"] }, { "iotime", L["QL_FOR_IOTIME"] } },
    get = function() return ns.cfg.quickLightFor or "place" end,
    set = function(v) ns.cfg.quickLightFor = v sdRefresh() end })
  qlFor:SetPoint("TOPLEFT", show, "TOPLEFT", 3 * (QW + 12), 0)
  controls[#controls + 1] = qlFor
  local move = UI.Button(p, L["DS_MOVE"], 120, function() ns.StatusDisplay.Unlock(20) end)
  UI.Tooltip(move, L["DS_MOVE"], L["DS_MOVE_TIP"])
  -- Centred in the card (Kim, 1.3.1): Move 120 + Reset position 120 + Test 90, 8 apart
  sd(move, 22, 8, math.floor((FULL_W - (120 + 8 + 120 + 8 + 90)) / 2 + 0.5) - 16)
  local reset = UI.Button(p, L["DS_RESET_POS"], 120, function() ns.StatusDisplay.ResetPosition() end)
  reset:SetPoint("LEFT", move, "RIGHT", 8, 0)
  local test = UI.Button(p, L["DS_TEST"], 90, function() ns.StatusDisplay.Test() end)
  test:SetPoint("LEFT", reset, "RIGHT", 8, 0)
  UI.Tooltip(test, L["DS_TEST"], L["DS_TEST_TIP"])
  return refresher(controls)
end

local SUBPAGES = {
  { key = "general", title = L["SET_GENERAL"], build = buildGeneral, icon = "Interface\\Icons\\Trade_Engineering",
    desc = L["SET_GENERAL_DESC"],
    summary = function()
      if not ns.cfg.enabled then return "|cffff6060" .. L["SET_SWITCHED_OFF"] .. "|r" end
      return L["SET_GENERAL_SUM"]:format(ns.cfg.debounce or 0.5)
    end },
  { key = "time", title = L["SET_TIME"], build = buildTime,
    desc = L["SET_TIME_DESC"],
    iconFn = function() return UI.ART .. "Day\\ui-" .. ns.Situations.Snapshot().period end,
    summary = function()
      local env = ns.Situations.Snapshot()
      local name = { dawn = L["PERIOD_DAWN"], day = L["PERIOD_DAY"], dusk = L["PERIOD_DUSK"], night = L["PERIOD_NIGHT"] }
      return L[ns.cfg.clock == "local" and "SET_TIME_SUM_LOCAL" or "SET_TIME_SUM_SERVER"]:format(
        ns.FormatHour(env.hour, env.min), name[env.period] or "?")
    end },
  { key = "display", title = L["SET_DISPLAY"], build = buildDisplay, icon = "Interface\\Icons\\INV_Misc_Spyglass_03",
    desc = L["SET_DISPLAY_DESC"],
    summary = function()
      local btn = { auto = L["SET_BTN_AUTO"], always = L["SET_BTN_ALWAYS"], never = L["SET_BTN_NEVER"] }
      return L[ns.cfg.moon ~= false and "SET_MOON_ON" or "SET_MOON_OFF"]:format(btn[ns.cfg.minimapButton or "auto"] or "")
    end },
  { key = "baseline", title = L["SET_BASELINE"], build = buildBaseline, icon = "Interface\\Icons\\Spell_Holy_HolyBolt",
    desc = L["SET_BASELINE_DESC"],
    summary = function()
      local b, parts = ns.db.baseline or {}, {}
      for _, ch in ipairs(C.list) do
        if b[ch.key] then parts[#parts + 1] = ch.short .. " " .. C.Format(ch.key, b[ch.key]) end
      end
      return table.concat(parts, "  ")
    end },
  { key = "chars", title = L["SET_CHARS"], build = buildCharacters, icon = "Interface\\Icons\\INV_Misc_Head_Human_01",
    portrait = true,   -- the character you play (race and gender), as on the unit frame (Kim)
    desc = L["SET_CHARS_DESC"],
    summary = function()
      local n = 0
      for _ in pairs(ns.db.chars) do n = n + 1 end
      return n == 1 and L["SET_CHARS_ONE"] or L["SET_CHARS_MANY"]:format(n)
    end },
}

-- Open the window on a Settings page (key: general, time, display, baseline, chars; nil = the overview).
function ns.OpenSettingsPage(key)
  if not ns.OpenWindow then return end
  W.CloseOverlays(true)
  ns.OpenWindow("settings", true)
  local pg = W.PageOf("settings")
  if key and pg and pg.OpenSub then pg.OpenSub(key) end
end

-- Settings tab ------------------------------------------------------------------------------------
W.AddTab("settings", L["TAB_SETTINGS"], function(page)
  UI.Glow(page, nil, 0.8)
  local overview = CreateFrame("Frame", nil, page)
  overview:SetAllPoints()
  local open

  -- The overview (Kim: less boring): a header with a quick on / off switch, then one rounded tile
  -- per page in two columns, each with a round icon, its name, what is in it and a live summary.
  -- The whole tile opens the page.
  local title = UI.Label(overview, L["TAB_SETTINGS"], "GameFontNormalHuge")
  title:SetPoint("TOPLEFT", overview, "TOPLEFT", 14, -14)
  -- The main on / off: the big switch with the moon's glow while on (Kim)
  local quick = UI.Switch(overview, { label = "Duskfall", big = true,   --noloc
    tip = L["SET_ON_TIP"],
    get = function() return ns.cfg.enabled end,
    set = function(v) D.SetEnabled(v) W.UpdateStatus() end })
  quick:SetPoint("TOPRIGHT", overview, "TOPRIGHT", -24, -12)
  -- Refresh, left of the big switch (Kim): clears anything stuck and writes the settings for here
  local refresh = UI.Button(overview, L["SET_REFRESH"], 96, function()
    D.Refresh()
    W.UpdateStatus()
  end, 24)
  refresh:SetPoint("RIGHT", quick, "LEFT", -28, 0)
  UI.Tooltip(refresh, L["SET_REFRESH"], L["SET_REFRESH_TIP"])
  -- Language, left of Refresh (Kim, 1.2.0; BNB's selector): the game's language first, then each
  -- language in its own name with its flag; the ones not shipped yet greyed. A pick asks, saves
  -- db.lang (as /dusk lang) and reloads. On a client of another script the whole game's font changes
  -- (Locales/enUS.lua), and the question says so. Away from English, "Game language" keeps its
  -- English name too, so a player who cannot read the language finds the way back.
  local FLAG = UI.ART .. "Flags\\flag-"
  local LANG_FLAG = { enUS = "en", zhCN = "cn", zhTW = "tw", deDE = "de", frFR = "fr", esES = "es", koKR = "ko",
                      jaJP = "ja", ukUA = "ua" }
  local function langText(code)
    local f = LANG_FLAG[code]
    return (f and ("|T" .. FLAG .. f .. ":14:20:0:0:32:32|t ") or "") .. ns.LANG_NAMES[code]   --noloc
  end
  local lang
  lang = UI.Dropdown(overview, 150, { tipTitle = L["SET_LANG"], tip = L["SET_LANG_TIP"],
    items = function()
      local client = L["SET_LANG_CLIENT"]
      if ns.locale ~= "enUS" then client = client .. " (Game language)" end   --noloc
      local out = { { "client", client } }
      for _, code in ipairs(ns.LANGS) do
        if ns.LANG_READY[code] then
          out[#out + 1] = { code, langText(code) }
        else
          out[#out + 1] = { code, "|cff888888" .. langText(code) .. "  " .. L["SET_LANG_SOON"] .. "|r", true }
        end
      end
      return out
    end,
    get = function() return ns.db.lang or "client" end,
    set = function(v)
      if v == (ns.db.lang or "client") then return end
      local code = v ~= "client" and v or nil
      local q = L["SET_LANG_Q"]:format(code and ns.LANG_NAMES[code] or L["SET_LANG_CLIENT"])
      if code and code ~= GetLocale() and ns.LANG_FONT[code] then q = q .. "\n\n" .. L["SET_LANG_FONT"] end
      UI.Confirm(q, function()
        ns.db.lang = code
        ReloadUI()
      end)
      lang:Refresh()
    end })
  lang:SetPoint("RIGHT", refresh, "LEFT", -10, 0)
  lang._dd:ClearAllPoints()
  lang._dd:SetPoint("RIGHT", refresh, "LEFT", -10, 0)
  local tiles = {}
  -- Layout (Kim): General across the top, then Time of day | Baseline, then Display | Characters,
  -- tall enough to fill the page. TILE_SPOT = key -> { column (0, 1 or "full"), row }.
  local TILE_GAP, TILE_H = 12, 128
  local tileW = math.floor((FULL_W - TILE_GAP) / 2)
  local TILE_SPOT = { general = { "full", 0 }, time = { 0, 1 }, baseline = { 1, 1 }, display = { 0, 2 }, chars = { 1, 2 } }
  local subs = {}
  for _, def in ipairs(SUBPAGES) do
    local sub = CreateFrame("Frame", nil, page)
    sub:SetAllPoints()
    sub:Hide()
    local back = UI.BackButton(sub, 24, { tip = L["BTN_BACK"], onClick = function() page.Back() end })
    back:SetPoint("TOPLEFT", sub, "TOPLEFT", 12, -12)
    local h = UI.Header(sub, def.title)
    h:SetFontObject("GameFontNormalLarge")
    h:SetPoint("LEFT", back, "RIGHT", 8, 0)
    local rule = sub:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(1, 0.82, 0, 0.25)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", sub, "TOPLEFT", 12, -40)
    rule:SetPoint("TOPRIGHT", sub, "TOPRIGHT", -12, -40)
    sub.def = def
    subs[def.key] = sub

    local n = #tiles
    local spot = TILE_SPOT[def.key] or { n % 2, math.floor(n / 2) }
    local tile = CreateFrame("Button", nil, overview)
    if spot[1] == "full" then
      tile:SetSize(FULL_W, TILE_H)
      tile:SetPoint("TOPLEFT", overview, "TOPLEFT", 12, -62 - spot[2] * (TILE_H + TILE_GAP))
    else
      tile:SetSize(tileW, TILE_H)
      tile:SetPoint("TOPLEFT", overview, "TOPLEFT", 12 + spot[1] * (tileW + TILE_GAP), -62 - spot[2] * (TILE_H + TILE_GAP))
    end
    UI.RoundBox(tile, { radius = 12, bottom = { 0, 0, 0, 0.45 }, top = { 0.2, 0.15, 0.09, 0.42 },
      border = { 1, 0.82, 0, 0.22 } })
    local hl = tile:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", tile, "TOPLEFT", 3, -3)
    hl:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -3, 3)
    hl:SetColorTexture(1, 0.85, 0.4, 0.07)
    -- A round icon (cropped and masked)
    local icon = tile:CreateTexture(nil, "ARTWORK")
    icon:SetSize(46, 46)
    icon:SetPoint("LEFT", tile, "LEFT", 16, 0)
    if def.icon then icon:SetTexture(def.icon) icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    local round
    if tile.CreateMaskTexture then
      local mask = tile:CreateMaskTexture()
      mask:SetAllPoints(icon)
      if pcall(mask.SetTexture, mask, "Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") then
        icon:AddMaskTexture(mask)
        round = mask
      end
    end
    -- Fixed icons catch the cursor light too (not the ones that change: portrait, moon phase).
    -- The copy gets the same round mask, or its square corners light up (Kim's screenshot).
    if def.icon and not def.iconFn and not def.portrait and ns.CursorLight then
      local lit = ns.CursorLight.Copy(icon, "art")
      if lit and round then lit:AddMaskTexture(round) end
    end
    -- BigNoteBox's "Simple Glass Orb" frame round the icon (Kim): ui-glyphframe-2, file 237655
    -- (1024 x 1024), the frame at 946,0 63 x 63 with its round hole at 950.5,3.5 56 x 56. Not on
    -- Time of day: its icons have a border of their own.
    if not def.iconFn then
      local F = 46 * 63 / 56
      local orb = tile:CreateTexture(nil, "OVERLAY")
      orb:SetSize(F, F)
      orb:SetPoint("CENTER", icon, "CENTER", -F / 63, 0)
      orb:SetTexture(237655)
      orb:SetTexCoord(946 / 1024, 1009 / 1024, 0, 63 / 1024)
      if ns.CursorLight then ns.CursorLight.Copy(orb, "edge") end
    end
    local name = UI.Label(tile, def.title, "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 16, 2)
    local desc = UI.Label(tile, def.desc)
    desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("RIGHT", tile, "RIGHT", -30, 0)
    desc:SetTextColor(0.72, 0.72, 0.72)
    local sum = UI.Label(tile, "", "GameFontHighlightSmall")
    sum:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -6)
    sum:SetPoint("RIGHT", tile, "RIGHT", -30, 0)
    sum:SetWordWrap(false)
    sum:SetTextColor(0.85, 0.75, 0.5)
    local arrow = UI.Label(tile, ">", "GameFontNormalLarge")
    arrow:SetPoint("RIGHT", tile, "RIGHT", -14, 0)
    arrow:SetTextColor(1, 0.82, 0, 0.6)
    tile:SetScript("OnClick", function() open(def.key) end)
    tile.Refresh = function()
      if def.iconFn then icon:SetTexture(def.iconFn()) icon:SetTexCoord(0, 1, 0, 1) end
      if def.portrait and SetPortraitTexture then
        SetPortraitTexture(icon, "player")
        icon:SetTexCoord(0, 1, 0, 1)
      end
      sum:SetText(def.summary and def.summary() or "")
    end
    tiles[#tiles + 1] = tile
  end

  open = function(key)
    local sub = subs[key]
    if not sub.refresh then sub.refresh = sub.def.build(sub) end
    overview:Hide()
    for _, s in pairs(subs) do s:Hide() end
    sub:Show()
    if sub.refresh then sub.refresh() end
    page.openSub = key
  end
  page.OpenSub = function(key) if subs[key] then open(key) end end
  page.Back = function()
    if not page.openSub then return false end
    subs[page.openSub]:Hide()
    page.openSub = nil
    overview:Show()
    return true
  end
  -- Leaving the tab (or closing the window) goes back to the overview: coming back starts there (Kim)
  page:SetScript("OnHide", function() page.Back() end)
  local function refreshTiles()
    quick:Refresh()
    for _, t in ipairs(tiles) do ns.Safe(t.Refresh, "settings tile") end
  end
  -- Winter (UI/Winter.lua): the snowflake switch in the bottom right corner, only in season
  if ns.Winter then
    local flake = ns.Winter.Switch(overview)
    flake:SetPoint("BOTTOMRIGHT", W.frame, "BOTTOMRIGHT", -10, 10)   -- 10 px from the window's corner (Kim)
    flake:SetFrameLevel(W.frame:GetFrameLevel() + 21)   -- over the border and the status strip, under overlays (+40)
  end
  overview:SetScript("OnShow", refreshTiles)
  ns.Listen("ONOFF", function() if overview:IsVisible() then refreshTiles() end end)
  refreshTiles()
  ns.OpenSettingsPage = function(key)
    ns.OpenWindow("settings", true)
    open(key)
  end
end, "right")

-- About tab ---------------------------------------------------------------------------------------
-- One calm centred column (Kim: "think Apple"): icon, name, version, one line on what it does, the
-- links, and the commands folded away behind a button.
W.AddTab("about", L["TAB_ABOUT"], function(page)
  UI.Glow(page, nil, 0.8)
  -- Winter (UI/Winter.lua): snow falling behind the content; the column goes above it
  local snow
  if ns.Winter then
    snow = CreateFrame("Frame", nil, page)
    snow:SetAllPoints()
    snow:EnableMouse(false)
  end
  local col = CreateFrame("Frame", nil, page)
  col:SetPoint("TOP", page, "TOP", 0, -18)
  col:SetSize(560, 440)
  if snow then
    col:SetFrameLevel(snow:GetFrameLevel() + 2)
    ns.Winter.AddFalling(snow)
  end

  -- The name block (Kim, 2026-11-27): bigger, one line each: Duskfall / Version / by / Dukul
  local logo = col:CreateTexture(nil, "ARTWORK")
  logo:SetSize(128, 128)
  logo:SetPoint("TOP", col, "TOP", 0, 0)
  logo:SetTexture(UI.ART .. "icon")

  local name = col:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge3")
  local path, _, flags = name:GetFont()
  if path then name:SetFont(path, 44, flags or "") end
  name:SetPoint("TOP", logo, "BOTTOM", 0, -8)
  name:SetText("|cff3355ccD|cff506ac5u|cff6d7fbes|cff8a94b7k|cffa8a9aff|cffc5bea8a|cffe2d3a1l|cffffe89al|r")
  local ver = UI.Label(col, L["VERSION_FMT"]:format(ns.VERSION), "GameFontHighlightLarge")
  ver:SetPoint("TOP", name, "BOTTOM", 0, -6)
  ver:SetTextColor(0.75, 0.75, 0.75)
  local by = UI.Label(col, L["AB_BY"], "GameFontHighlight")
  by:SetPoint("TOP", ver, "BOTTOM", 0, -6)
  by:SetTextColor(0.45, 0.45, 0.45)
  -- "Dukul" in Duskfall blue (UI.RING_BLUE, the blue of the frame and the icon's ring; Kim)
  local who = UI.Label(col, "|cff5c80ffDukul|r", "GameFontNormalLarge")
  who:SetPoint("TOP", by, "BOTTOM", 0, -4)

  local desc = UI.Label(col, L["AB_DESC"], "GameFontHighlight")
  desc:SetPoint("TOP", who, "BOTTOM", 0, -18)
  desc:SetWidth(460)
  desc:SetJustifyH("CENTER")
  desc:SetSpacing(3)
  desc:SetTextColor(0.88, 0.86, 0.82)

  -- Link buttons (BigNoteBox's icon buttons); a site without a url is left out
  local SZ, GAP = 32, 10
  local shown = {}
  for _, l in ipairs(ns.LINKS) do if l.url then shown[#shown + 1] = l end end
  local rowW = #shown * SZ + (#shown - 1) * GAP
  for i, l in ipairs(shown) do
    local b = UI.IconButton(col, SZ, l.key, {
      tip = l.name, tipSub = l.sub or L["LINK_COPY"]:format(l.name),
      onClick = function(self) UI.Copy(l.name, l.url, self) end,
    })
    b:SetPoint("TOPLEFT", desc, "BOTTOM", -math.floor(rowW / 2) + (i - 1) * (SZ + GAP), -18)
  end

  -- Commands, Help and Patch Notes in one row (Kim): Commands opens Help on its Commands topic
  local BW, BG = 130, 10
  local row = {
    { L["AB_COMMANDS"], L["AB_COMMANDS_TIP"], function() if ns.Help then ns.Help.Open("commands") end end },
    { L["BTN_HELP"], L["WIN_HELP_TIP"], function() if ns.Help then ns.Help.Open("start") end end },
    { L["AB_PATCH"], L["AB_PATCH_TIP"], function() if ns.PatchNotes then ns.PatchNotes.Open() end end },
  }
  local total = #row * BW + (#row - 1) * BG
  local midBtn   -- the middle button: the row is centred on it
  for i, r in ipairs(row) do
    local b = UI.Button(col, r[1], BW, r[3], 26)
    b:SetPoint("TOPLEFT", desc, "BOTTOM", -math.floor(total / 2) + (i - 1) * (BW + BG), -(18 + SZ + 18))
    UI.Tooltip(b, r[1], r[2])
    if i == math.ceil(#row / 2) then midBtn = b end
  end

  -- The bottom (Kim, 2026-11-27): the status strip is hidden on this tab (W.UpdateStrip) and the
  -- solidarity line from all of Kim's addons (as BigNoteBox's General tab) takes its place; a gold
  -- rule above it, and the fan project note centred between the buttons and the rule. The flags line
  -- is kept as written in every language (as in BigNoteBox). Own frame above the page's glow.
  local FLAG = UI.ART .. "Flags\\"
  local solFrame = CreateFrame("Frame", nil, page)
  solFrame:SetPoint("BOTTOMLEFT", W.frame, "BOTTOMLEFT", 16, 10)
  solFrame:SetPoint("BOTTOMRIGHT", W.frame, "BOTTOMRIGHT", -16, 10)
  solFrame:SetHeight(16)
  solFrame:SetFrameLevel(page:GetFrameLevel() + 20)
  local sol = UI.Label(solFrame, "LGBTQIA+ |T" .. FLAG .. "flag-pride:14:20|t Pride  \226\128\148"   --noloc
    .. "  Trans |T" .. FLAG .. "flag-trans:14:20|t Rights  \226\128\148"   --noloc
    .. "  Slava |T" .. FLAG .. "flag-ua:14:20|t Ukraini  \226\128\148"   --noloc
    .. "  Free |T" .. FLAG .. "flag-ps:14:20|t Palestine", "GameFontHighlightSmall")   --noloc
  sol:SetPoint("CENTER", solFrame, "CENTER", 0, 0)
  sol:SetJustifyH("CENTER")
  sol:SetTextColor(0.85, 0.85, 0.85)
  -- The rule: Duskfall blue at both ends, gold in the middle (Kim), as two gradient halves
  local rule = CreateFrame("Frame", nil, solFrame)
  rule:SetHeight(1)
  rule:SetPoint("BOTTOMLEFT", solFrame, "TOPLEFT", 8, 10)
  rule:SetPoint("BOTTOMRIGHT", solFrame, "TOPRIGHT", -8, 10)
  local blue, gold = UI.RING_BLUE, UI.RING_GOLD
  local ruleL = rule:CreateTexture(nil, "ARTWORK")
  ruleL:SetPoint("TOPLEFT", rule, "TOPLEFT")
  ruleL:SetPoint("BOTTOMRIGHT", rule, "BOTTOM")
  UI.Gradient(ruleL, "HORIZONTAL", { blue[1], blue[2], blue[3], 0.7 }, { gold[1], gold[2], gold[3], 0.7 })
  local ruleR = rule:CreateTexture(nil, "ARTWORK")
  ruleR:SetPoint("TOPLEFT", rule, "TOP")
  ruleR:SetPoint("BOTTOMRIGHT", rule, "BOTTOMRIGHT")
  UI.Gradient(ruleR, "HORIZONTAL", { gold[1], gold[2], gold[3], 0.7 }, { blue[1], blue[2], blue[3], 0.7 })
  -- The note, centred in the gap between the buttons and the rule
  local gap = CreateFrame("Frame", nil, page)
  gap:SetPoint("TOP", midBtn, "BOTTOM", 0, 0)
  gap:SetPoint("BOTTOM", rule, "TOP", 0, 0)
  gap:SetWidth(700)
  gap:SetFrameLevel(page:GetFrameLevel() + 20)
  local foot = UI.Label(gap, L["AB_FOOT"], "GameFontDisableSmall")
  foot:SetPoint("CENTER", gap, "CENTER", 0, 0)
end, "right")
