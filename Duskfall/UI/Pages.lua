-- Duskfall UI/Pages.lua: the tabs of the settings window.
--   left:  Places (UI/Places.lua, loads first so it is the first tab), Styles (UI/Styles.lua, also before this file)
--   right: Settings (an overview of sub-pages, like BigNoteBox's Modules tab: General, Time of day,
--          Baseline, Characters), About (logo, version, links, commands)
local ADDON, ns = ...
local UI, W, C, D = ns.UI, ns.Window, ns.Channels, ns.Detect

ns.LINKS = {
  { key = "dukul", name = "Dukul.net", url = "https://dukul.net", sub = "Dukul's other addons" },
  { key = "github", name = "GitHub", url = "https://github.com/DukulWoW/Duskfall" },
  { key = "curseforge", name = "CurseForge", url = "https://www.curseforge.com/wow/addons/duskfall" },
  { key = "wago", name = "Wago", url = "https://addons.wago.io/addons/duskfall" },
  { key = "bugs", name = "Report a bug", url = "https://github.com/DukulWoW/Duskfall/issues", sub = "Opens the issue tracker link" },
}

-- An hour in the chosen clock format: 21 -> "21:00" or "9 PM".
function ns.FormatHour(h, m)
  m = m or 0
  if ns.cfg.clock24 then return string.format("%02d:%02d", h, m) end
  local suffix = "AM"
  if h >= 12 then suffix = "PM" end
  local h12 = h % 12
  if h12 == 0 then h12 = 12 end
  if m == 0 then return h12 .. " " .. suffix end
  return string.format("%d:%02d %s", h12, m, suffix)
end

-- Settings: sub-page builders ----------------------------------------------------------------------
local CONTENT_W = 700
local FULL_W = 728        -- the whole width of a sub-page (752) less its 12 px margins

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
  local _, top = card(p, 12, -50, FULL_W, 96, "Duskfall", nil, controls)
  local on = top(UI.Check(p, { label = "Duskfall on", tip = "Off puts your baseline back and leaves the sliders to you.",
    get = function() return ns.cfg.enabled end,
    set = function(v) D.SetEnabled(v) W.UpdateStatus() end }), 26, 4)
  local dbg = UI.Check(p, { label = "Debug output", tip = "Prints what Duskfall does in chat.",
    get = function() return ns.cfg.debug end,
    set = function(v) ns.cfg.debug = v end })
  dbg:SetPoint("LEFT", on, "LEFT", 300, 0)
  controls[#controls + 1] = dbg

  local SL_W = FULL_W - 32
  local _, timing = card(p, 12, -158, FULL_W, 216, "Timing",
    "How quickly Duskfall reacts. The feel of the changes themselves is on the Styles tab.", controls)
  timing(UI.Slider(p, SL_W, { label = "Doorway delay", min = 0, max = 2, step = 0.1, default = 0.5,
    fmt = function(v) return string.format("%.1f s", v) end,
    tip = "How long a new state (indoors, mounted...) must hold before Duskfall reacts. Stops flicker in doorways.",
    get = function() return ns.cfg.debounce end,
    onChange = function(v) ns.cfg.debounce = v end }), UI.SLIDER_H, 10)
  timing(UI.Slider(p, SL_W, { label = "Time of day fade", min = 0, max = 120, step = 5, default = 45,
    fmt = function(v) return v .. " s" end,
    tip = "How long a change caused only by the clock takes, in every mode, so dusk never snaps.",
    get = function() return ns.cfg.timeFade end,
    onChange = function(v) ns.cfg.timeFade = v end }), UI.SLIDER_H, 10)
  timing(UI.Slider(p, SL_W, { label = "Adapt overshoot gap", min = 0, max = 10, step = 0.5, default = 2,
    fmt = function(v) return string.format("%.1f s", v) end,
    tip = "Two Adapt dips or glares never come closer than this. Riding along a zone border dips once.",
    get = function() return ns.cfg.adaptGap end,
    onChange = function(v) ns.cfg.adaptGap = v end }), UI.SLIDER_H, 10)
  return refresher(controls)
end

local function buildTime(p)
  local add, refresh = stacker(p, -48)
  -- The two dropdowns as wide as the day cards below and over them (Kim): (FULL_W - 12) / 2, 12 apart
  local DD_W = math.floor((FULL_W - 12) / 2)
  local bar
  local src = UI.Dropdown(p, DD_W, { label = "Time source",
    tip = "Server time matches day and night in the world. Local is your computer's clock.",
    items = { { "server", "Server time (matches the sky)" }, { "local", "Local time (your computer)" } },
    get = function() return ns.cfg.clock end,
    set = function(v) ns.cfg.clock = v D.Evaluate("settings") if bar then bar:Refresh() end end })
  add(src, UI.DROPDOWN_H, 8)
  local fmt = UI.Dropdown(p, DD_W, { label = "Clock format",
    items = { { true, "24 hour (21:00)" }, { false, "12 hour (9 PM)" } },
    get = function() return ns.cfg.clock24 end,
    set = function(v) ns.cfg.clock24 = v if bar then bar:Refresh() end end })
  fmt:SetPoint("TOPLEFT", src, "TOPRIGHT", 12, 0)
  local partsHead = UI.Header(p, "Parts of the day")
  add(partsHead, 14, 4)
  local partsHelp = UI.HelpIcon(p, "time", "Parts of the day", "When Dawn, Day, Dusk and Night start. A setting " ..
    "can be for one of them.")
  partsHelp:SetPoint("LEFT", partsHead, "RIGHT", 6, 0)
  local help = UI.Label(p, "A Look can be set to one part of the day. Drag the yellow edges to change when each part starts.")
  help:SetWidth(FULL_W)
  add(help, 14, 12)
  bar = UI.DayBar(p, FULL_W)
  add(bar, bar:GetHeight(), 8)
  local r = refresh
  return function() r() fmt:Refresh() end
end

-- Baseline: the four values as cards in 2 x 2 (as Time of day), each with its value large and a
-- slider on the game's own range, the mark at the game's default. Moving one changes the
-- baseline at once, and the screen with it (settings are changes from it) (Kim, 2026-11-26).
local GAME_DEFAULT = { gamma = 1.0, brightness = 50, contrast = 50, bloom = 1.0 }
local BASE_STEP = { gamma = 0.01, brightness = 1, contrast = 1, bloom = 0.05 }

local function buildBaseline(p)
  local text = UI.Label(p, "Your baseline is your own look: Duskfall starts from it, every setting in Places is a "
    .. "change from it, and logging out or switching Duskfall off puts it back.")
  text:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -50)
  text:SetWidth(FULL_W)
  text:SetSpacing(2)

  local GAP, CARD_H = 12, 104
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
    local def = UI.Label(card, "Game default " .. C.Format(k, GAME_DEFAULT[k]), "GameFontHighlightSmall")
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
  end

  local function refreshCards()
    for _, c in ipairs(cards) do
      c.slider:Refresh()
      local v = ns.db.baseline and ns.db.baseline[c.key]
      c.big:SetText(v and C.Format(c.key, v) or "-")
    end
  end

  local y = -92 - 2 * (CARD_H + GAP) - 6
  local save = UI.Button(p, "Use what is on screen", 190, function()
    UI.Confirm("Make the values on screen now your baseline (the ones logging out brings back)?", function()
      D.SaveBaseline()
      refreshCards()
      W.UpdateStatus()
    end)
  end)
  save:SetPoint("TOPLEFT", p, "TOPLEFT", 12, y)
  UI.Tooltip(save, "Use what is on screen", "Takes the values on screen now as your baseline. Handy after you set " ..
    "the game's own sliders with Duskfall switched off.")
  local reset = UI.Button(p, "Game defaults", 150, function()
    UI.Confirm("Set your baseline to the game's defaults (Gamma 1.00, Brightness 50, Contrast 50, Bloom 1.00)?", function()
      if not ns.db.baseline then return end
      for k, v in pairs(GAME_DEFAULT) do ns.db.baseline[k] = v end
      refreshCards()
      apply()
    end)
  end)
  reset:SetPoint("LEFT", save, "RIGHT", 8, 0)
  local tip = UI.Label(p, "Drag a slider and the screen follows. Right-click a slider for the game default.")
  tip:SetPoint("TOPLEFT", save, "BOTTOMLEFT", 0, -10)
  tip:SetTextColor(0.7, 0.7, 0.7)
  local help = UI.HelpIcon(p, "own", "Baseline", "Your own look, which every setting in Places changes from.")
  help:SetPoint("LEFT", reset, "RIGHT", 10, 0)
  return refreshCards
end

local function buildCharacters(p)
  local note = UI.Label(p, "Characters are added when they log in. Remove the ones you deleted; they also leave every scope that names them.")
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
      row.remove = UI.Button(row, "Remove", 80, nil, 20)
      row.remove:SetKind("danger")
      row.remove:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    end
    local c = e.c
    local name = c.name or "?"
    local col = c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
    if col and col.colorStr then name = "|c" .. col.colorStr .. name .. "|r" end
    if e.guid == ns.charKey then name = name .. "  |cff9d9d9d(you)|r" end
    row.name:SetText(name)
    local styles, looks = ns.CharUse(e.guid)
    row.info:SetText(string.format("last seen %s   %d Style%s, %d Look%s", date("%Y-%m-%d", c.last or 0),
      styles, styles == 1 and "" or "s", looks, looks == 1 and "" or "s"))
    row.shade:SetShown(e.index % 2 == 0)
    row.remove:SetEnabled(e.guid ~= ns.charKey)
    row.remove:SetScript("OnClick", function()
      UI.Confirm("Remove " .. (c.name or "?") .. " from Duskfall? It also leaves every Style and Look scope that names it.", function()
        local emptied = ns.RemoveCharacter(e.guid)
        if emptied and emptied > 0 then
          ns.Print("|cffff9f40%d scope(s) named only that character: those Looks are now Global, those Styles unused.|r", emptied)
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

  local _, mm = card(p, 12, -50, HALF, 262, "Minimap and broker", nil, controls)
  mm(UI.Check(p, { label = "Minimap moon opens Duskfall",
    tip = "The day / night moon on the minimap gets the same clicks and tooltip as the minimap button. With this on you may not need the button at all.",
    get = function() return ns.cfg.moon ~= false end,
    set = function(v)
      ns.cfg.moon = v
      ns.Moon.Apply()
      if v and not ns.Moon.Found() then ns.Print("can't find the minimap moon on this client.") end
    end }), 26, 4)
  mm(UI.Check(p, { label = "Glow where a setting is in effect",
    tip = "A slow gold ring behind Duskfall's icon on the moon and the minimap button while one of your settings is in effect where you stand.",
    get = function() return ns.cfg.ringGlow ~= false end,
    set = function(v)
      ns.cfg.ringGlow = v
      ns.Moon.UpdateRings()
    end }), 26, 10)
  mm(UI.Dropdown(p, DD_W, { label = "Minimap button",
    tip = "Left-click opens Duskfall, right-click switches it on or off, shift-right-click opens Settings. The same clicks work on the moon, in the addon compartment and on broker bars. Automatic shows the button only when the moon can't be used (switched off above, or hidden by another addon).",
    items = { { "auto", "Automatic (when the moon can't be used)" }, { "always", "Always" }, { "never", "Never" } },
    get = function() return ns.cfg.minimapButton or "auto" end,
    set = function(v) ns.cfg.minimapButton = v ns.UpdateMinimapButton() end }), UI.DROPDOWN_H, 10)
  mm(UI.Dropdown(p, DD_W, { label = "Broker text",
    tip = "What broker bars (Titan Panel, ChocolateBar, ElvUI datatexts...) show next to the icon.",
    items = { { "look", "The setting in effect" }, { "values", "The values on screen" }, { "both", "Setting and values" }, { "none", "Nothing (icon only)" } },
    get = function() return ns.cfg.brokerText end,
    set = function(v) ns.cfg.brokerText = v ns.UpdateBroker() end }), UI.DROPDOWN_H, 8)

  -- The game's own colorblind filter (Options > Accessibility), here for quick switching (Kim).
  -- colorblindSimulator 0-3 and colorblindWeaknessFactor 0-1 exist on Forever (Kim, 2026-11-26:
  -- "0 0.5"). Read from the game each time, never stored by Duskfall.
  local function cvarNum(name, d) return tonumber(GetCVar(name)) or d end
  local _, cb = card(p, 12 + HALF + 12, -50, HALF, 262, "Colorblind filter and light",
    "The game's own filter (Options > Accessibility). Duskfall only changes it when you do.", controls)
  cb(UI.Dropdown(p, DD_W, { label = "Filter",
    items = { { 0, "Off" }, { 1, "Protanopia (red weak)" }, { 2, "Deuteranopia (green weak)" }, { 3, "Tritanopia (blue weak)" } },
    get = function() return cvarNum("colorblindSimulator", 0) end,
    set = function(v) SetCVar("colorblindSimulator", v) end }), UI.DROPDOWN_H, 10)
  cb(UI.Slider(p, DD_W, { label = "Strength", min = 0, max = 1, step = 0.05, default = 0.5,
    fmt = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
    tip = "How strongly the filter adjusts the colours.",
    get = function() return cvarNum("colorblindWeaknessFactor", 0.5) end,
    onChange = function(v) SetCVar("colorblindWeaknessFactor", v) end }), UI.SLIDER_H, 8)
  cb(UI.Check(p, { label = "Cursor light in Duskfall's windows",
    tip = "A soft warm light follows the mouse over Duskfall's windows, and lifts them when your screen is dark.",
    get = function() return ns.cfg.cursorLight ~= false end,
    set = function(v) ns.cfg.cursorLight = v end }), 26, 4)
  cb(UI.Slider(p, DD_W, { label = "Light strength", min = 0.25, max = 3, step = 0.05, default = 1,
    fmt = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
    tip = "How bright the cursor light is. Move the mouse over this window to see it.",
    get = function() return tonumber(ns.cfg.cursorLightStrength) or 1 end,
    onChange = function(v) ns.cfg.cursorLightStrength = v end }), UI.SLIDER_H, 8)

  local _, sd = card(p, 12, -324, FULL_W, 150, "Status display",
    "A small floating display of the setting in effect and the values on screen.", controls)
  local show = sd(UI.Dropdown(p, DD_W, { label = "Show it",
    items = { { "off", "Never" }, { "change", "When the setting changes" }, { "always", "Always" } },
    get = function() return ns.cfg.statusDisplay end,
    set = function(v)
      ns.cfg.statusDisplay = v
      ns.StatusDisplay.Refresh(v == "change")
    end }), UI.DROPDOWN_H, 10)
  local stays = UI.Slider(p, DD_W, { label = "Stays for", min = 1, max = 15, step = 1, default = 4,
    fmt = function(v) return v .. " s" end,
    tip = "When the setting changes: how long the display stays once the change is done.",
    get = function() return ns.cfg.statusSeconds end,
    onChange = function(v) ns.cfg.statusSeconds = v end })
  stays:SetPoint("TOPLEFT", show, "TOPLEFT", HALF + 12, 0)
  controls[#controls + 1] = stays
  local move = UI.Button(p, "Move it", 120, function() ns.StatusDisplay.Unlock(20) end)
  UI.Tooltip(move, "Move it", "Shows the display for 20 seconds so you can drag it where you want it.")
  sd(move, 22, 8)
  local reset = UI.Button(p, "Reset position", 120, function() ns.StatusDisplay.ResetPosition() end)
  reset:SetPoint("LEFT", move, "RIGHT", 8, 0)
  return refresher(controls)
end

local SUBPAGES = {
  { key = "general", title = "General", build = buildGeneral, icon = "Interface\\Icons\\Trade_Engineering",
    desc = "On or off, doorway delay and timing.",
    summary = function()
      if not ns.cfg.enabled then return "|cffff6060Switched off|r" end
      return string.format("On, doorway delay %.1f s", ns.cfg.debounce or 0.5)
    end },
  { key = "time", title = "Time of day", build = buildTime,
    desc = "The clock, and when dawn, day, dusk and night start.",
    iconFn = function() return UI.ART .. "ui-" .. ns.Situations.Snapshot().period end,
    summary = function()
      local env = ns.Situations.Snapshot()
      local name = { dawn = "Dawn", day = "Day", dusk = "Dusk", night = "Night" }
      return string.format("Now %s, %s (%s clock)", ns.FormatHour(env.hour, env.min), name[env.period] or "?",
        ns.cfg.clock == "local" and "your" or "server")
    end },
  { key = "display", title = "Display", build = buildDisplay, icon = "Interface\\Icons\\INV_Misc_Spyglass_03",
    desc = "Minimap moon and button, broker, status display, colorblind filter, cursor light.",
    summary = function()
      local btn = { auto = "button automatic", always = "button always", never = "no button" }
      return (ns.cfg.moon ~= false and "Moon on, " or "Moon off, ") .. (btn[ns.cfg.minimapButton or "auto"] or "")
    end },
  { key = "baseline", title = "Baseline", build = buildBaseline, icon = "Interface\\Icons\\Spell_Holy_HolyBolt",
    desc = "Your own look, which every setting changes from.",
    summary = function()
      local b, parts = ns.db.baseline or {}, {}
      for _, ch in ipairs(C.list) do
        if b[ch.key] then parts[#parts + 1] = ch.short .. " " .. C.Format(ch.key, b[ch.key]) end
      end
      return table.concat(parts, "  ")
    end },
  { key = "chars", title = "Characters", build = buildCharacters, icon = "Interface\\Icons\\INV_Misc_Head_Human_01",
    portrait = true,   -- the character you play (race and gender), as on the unit frame (Kim)
    desc = "Characters Duskfall knows. Remove the ones you deleted.",
    summary = function()
      local n = 0
      for _ in pairs(ns.db.chars) do n = n + 1 end
      return string.format("%d character%s", n, n == 1 and "" or "s")
    end },
}

-- Settings tab ------------------------------------------------------------------------------------
W.AddTab("settings", "Settings", function(page)
  UI.Glow(page, nil, 0.8)
  local overview = CreateFrame("Frame", nil, page)
  overview:SetAllPoints()
  local open

  -- The overview (Kim: less boring): a header with a quick on / off switch, then one rounded tile
  -- per page in two columns, each with a round icon, its name, what is in it and a live summary.
  -- The whole tile opens the page.
  local title = UI.Label(overview, "Settings", "GameFontNormalHuge")
  title:SetPoint("TOPLEFT", overview, "TOPLEFT", 14, -14)
  -- The main on / off: the big switch with the moon's glow while on (Kim)
  local quick = UI.Switch(overview, { label = "Duskfall", big = true,
    tip = "Off puts your baseline back and leaves the sliders to you.",
    get = function() return ns.cfg.enabled end,
    set = function(v) D.SetEnabled(v) W.UpdateStatus() end })
  quick:SetPoint("TOPRIGHT", overview, "TOPRIGHT", -24, -12)
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
    local back = UI.IconButton(sub, 22, "left", { tip = "Back", onClick = function() page.Back() end })
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
    if tile.CreateMaskTexture then
      local mask = tile:CreateMaskTexture()
      mask:SetAllPoints(icon)
      if pcall(mask.SetTexture, mask, "Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") then
        icon:AddMaskTexture(mask)
      end
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
W.AddTab("about", "About", function(page)
  UI.Glow(page, nil, 0.8)
  local col = CreateFrame("Frame", nil, page)
  col:SetPoint("TOP", page, "TOP", 0, -18)
  col:SetSize(560, 440)

  local logo = col:CreateTexture(nil, "ARTWORK")
  logo:SetSize(104, 104)
  logo:SetPoint("TOP", col, "TOP", 0, 0)
  logo:SetTexture(UI.ART .. "icon")

  local name = col:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge3")
  name:SetPoint("TOP", logo, "BOTTOM", 0, -8)
  name:SetText("|cff3355ccD|cff506ac5u|cff6d7fbes|cff8a94b7k|cffa8a9aff|cffc5bea8a|cffe2d3a1l|cffffe89al|r")
  local ver = UI.Label(col, "Version " .. ns.VERSION .. "   |cff6f6f6fby|r Dukul", "GameFontHighlight")
  ver:SetPoint("TOP", name, "BOTTOM", 0, -6)
  ver:SetTextColor(0.62, 0.62, 0.62)

  local desc = UI.Label(col, "Gamma, brightness, contrast and bloom that follow you through the world, and change "
    .. "the way your eyes do.", "GameFontHighlight")
  desc:SetPoint("TOP", ver, "BOTTOM", 0, -16)
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
      tip = l.name, tipSub = l.sub or ("Copy the " .. l.name .. " link"),
      onClick = function(self) UI.Copy(l.name, l.url, self) end,
    })
    b:SetPoint("TOPLEFT", desc, "BOTTOM", -math.floor(rowW / 2) + (i - 1) * (SZ + GAP), -18)
  end

  -- Commands, folded away until asked for
  local panel = CreateFrame("Frame", nil, col)
  panel:SetPoint("TOP", desc, "BOTTOM", 0, -(18 + SZ + 52))
  panel:SetSize(520, 150)
  UI.RoundBox(panel, { radius = 10, bottom = { 0, 0, 0, 0.5 }, top = { 0.18, 0.14, 0.09, 0.4 },
    border = { 1, 0.82, 0, 0.2 } })
  local cmds = UI.Label(panel, table.concat({
    "|cffffd100/dusk|r   this window",
    "|cffffd100/dusk settings|r   this window, on Settings",
    "|cffffd100/dusk status|r   where you are and what Duskfall shows, in chat",
    "|cffffd100/dusk save|r  /  |cffffd100clear|r  sub, zone or instance [conditions]   from chat",
    "|cffffd100/dusk on|r  /  |cffffd100off|r   switch Duskfall on or off (also a key binding)",
    "|cffffd100/dusk help|r   the help, with every command",
  }, "\n"), "GameFontHighlight")
  cmds:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -16)
  cmds:SetPoint("RIGHT", panel, "RIGHT", -18, 0)
  cmds:SetSpacing(5)
  panel:Hide()

  local toggle
  toggle = UI.Button(col, "Commands", 140, function()
    panel:SetShown(not panel:IsShown())
    toggle:SetText(panel:IsShown() and "Hide commands" or "Commands")
  end)
  toggle:SetPoint("TOP", desc, "BOTTOM", 0, -(18 + SZ + 16))

  local foot = UI.Label(page, "A free fan project, not affiliated with Blizzard Entertainment. All rights reserved.",
    "GameFontDisableSmall")
  foot:SetPoint("BOTTOM", page, "BOTTOM", 0, 8)
end, "right")
