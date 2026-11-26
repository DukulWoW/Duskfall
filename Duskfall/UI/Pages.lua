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

local function buildGeneral(p)
  local add, refresh = stacker(p, -48)
  local SL_W = 460
  add(UI.Check(p, { label = "Duskfall on", tip = "Off puts your baseline back and leaves the sliders to you.",
    get = function() return ns.cfg.enabled end,
    set = function(v) D.SetEnabled(v) W.UpdateStatus() end }), 26, 12)
  add(UI.Slider(p, SL_W, { label = "Doorway delay", min = 0, max = 2, step = 0.1, default = 0.5,
    fmt = function(v) return string.format("%.1f s", v) end,
    tip = "How long a new state (indoors, mounted...) must hold before Duskfall reacts. Stops flicker in doorways.",
    get = function() return ns.cfg.debounce end,
    onChange = function(v) ns.cfg.debounce = v end }), UI.SLIDER_H, 12)
  add(UI.Slider(p, SL_W, { label = "Time of day fade", min = 0, max = 120, step = 5, default = 45,
    fmt = function(v) return v .. " s" end,
    tip = "How long a change caused only by the clock takes, in every mode, so dusk never snaps.",
    get = function() return ns.cfg.timeFade end,
    onChange = function(v) ns.cfg.timeFade = v end }), UI.SLIDER_H, 12)
  add(UI.Slider(p, SL_W, { label = "Adapt overshoot gap", min = 0, max = 10, step = 0.5, default = 2,
    fmt = function(v) return string.format("%.1f s", v) end,
    tip = "Two Adapt dips or glares never come closer than this. Riding along a zone border dips once.",
    get = function() return ns.cfg.adaptGap end,
    onChange = function(v) ns.cfg.adaptGap = v end }), UI.SLIDER_H, 16)
  add(UI.Check(p, { label = "Debug output", tip = "Prints what Duskfall does in chat.",
    get = function() return ns.cfg.debug end,
    set = function(v) ns.cfg.debug = v end }), 26, 8)
  return refresh
end

local function buildTime(p)
  local add, refresh = stacker(p, -48)
  local DD_W = 300
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
  fmt:SetPoint("TOPLEFT", src, "TOPRIGHT", 40, 0)
  add(UI.Header(p, "Parts of the day"), 14, 4)
  local help = UI.Label(p, "A Look can be set to one part of the day. Drag the yellow edges to change when each part starts.")
  help:SetWidth(FULL_W)
  add(help, 14, 12)
  bar = UI.DayBar(p, FULL_W)
  add(bar, bar:GetHeight(), 8)
  local r = refresh
  return function() r() fmt:Refresh() end
end

local function buildBaseline(p)
  local add, refresh = stacker(p, -48)
  local text = UI.Label(p, "Your baseline is your own look: Duskfall starts from it (Looks are offsets from it) and puts it back when you log out or switch Duskfall off.")
  text:SetWidth(CONTENT_W - 24)
  add(text, 28, 12)
  local vals = UI.Label(p, "", "GameFontHighlightLarge")
  vals.Refresh = function()
    local b, parts = ns.db.baseline or {}, {}
    for _, ch in ipairs(C.list) do
      local v = b[ch.key]
      parts[#parts + 1] = ch.label .. " |cffffffff" .. (v and C.Format(ch.key, v) or "-") .. "|r"
    end
    vals:SetText(table.concat(parts, "     "))
  end
  add(vals, 20, 16)
  add(UI.Button(p, "Save current as baseline", 220, function()
    UI.Confirm("Make the values on screen now your baseline (the ones logging out brings back)?", function()
      D.SaveBaseline()
      vals:Refresh()
      W.UpdateStatus()
    end)
  end), 22, 8)
  local tip = UI.Label(p, "Tip: switch Duskfall off, set the game's sliders the way you like them, then save.")
  tip:SetTextColor(0.7, 0.7, 0.7)
  add(tip, 14, 8)
  return refresh
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
  local add, refresh = stacker(p, -48)
  local DD_W = 300
  add(UI.Check(p, { label = "Minimap moon opens Duskfall",
    tip = "The day / night moon on the minimap gets the same clicks and tooltip as the minimap button. With this on you may not need the button at all.",
    get = function() return ns.cfg.moon ~= false end,
    set = function(v)
      ns.cfg.moon = v
      ns.Moon.Apply()
      if v and not ns.Moon.Found() then ns.Print("can't find the minimap moon on this client.") end
    end }), 26, 10)
  add(UI.Dropdown(p, DD_W, { label = "Minimap button",
    tip = "Left-click opens Duskfall, right-click switches it on or off, shift-right-click opens Settings. The same clicks work on the moon, in the addon compartment and on broker bars. Automatic shows the button only when the moon can't be used (switched off above, or hidden by another addon).",
    items = { { "auto", "Automatic (when the moon can't be used)" }, { "always", "Always" }, { "never", "Never" } },
    get = function() return ns.cfg.minimapButton or "auto" end,
    set = function(v) ns.cfg.minimapButton = v ns.UpdateMinimapButton() end }), UI.DROPDOWN_H, 12)
  add(UI.Dropdown(p, DD_W, { label = "Broker text",
    tip = "What broker bars (Titan Panel, ChocolateBar, ElvUI datatexts...) show next to the icon.",
    items = { { "look", "The Look in effect" }, { "values", "The values on screen" }, { "both", "Look and values" }, { "none", "Nothing (icon only)" } },
    get = function() return ns.cfg.brokerText end,
    set = function(v) ns.cfg.brokerText = v ns.UpdateBroker() end }), UI.DROPDOWN_H, 18)
  add(UI.Header(p, "Status display"), 14, 6)
  local help = UI.Label(p, "A small floating display of the Look in effect and the values on screen.")
  help:SetWidth(CONTENT_W - 24)
  add(help, 14, 10)
  add(UI.Dropdown(p, DD_W, { label = "Show it",
    items = { { "off", "Never" }, { "change", "When the Look changes" }, { "always", "Always" } },
    get = function() return ns.cfg.statusDisplay end,
    set = function(v)
      ns.cfg.statusDisplay = v
      ns.StatusDisplay.Refresh(v == "change")
    end }), UI.DROPDOWN_H, 8)
  add(UI.Slider(p, 460, { label = "Stays for", min = 1, max = 15, step = 1, default = 4,
    fmt = function(v) return v .. " s" end,
    tip = "When the Look changes: how long the display stays once the change is done.",
    get = function() return ns.cfg.statusSeconds end,
    onChange = function(v) ns.cfg.statusSeconds = v end }), UI.SLIDER_H, 12)
  local move = UI.Button(p, "Move it", 120, function() ns.StatusDisplay.Unlock(20) end)
  UI.Tooltip(move, "Move it", "Shows the display for 20 seconds so you can drag it where you want it.")
  add(move, 22, 8)
  local reset = UI.Button(p, "Reset position", 120, function() ns.StatusDisplay.ResetPosition() end)
  reset:SetPoint("LEFT", move, "RIGHT", 8, 0)
  return refresh
end

local SUBPAGES = {
  { key = "general", title = "General", build = buildGeneral,
    desc = "Switch Duskfall on or off, doorway delay, transition timing, debug output." },
  { key = "time", title = "Time of day", build = buildTime,
    desc = "Server or local clock, 12 or 24 hour, and when dawn, day, dusk and night start." },
  { key = "display", title = "Display", build = buildDisplay,
    desc = "Minimap button and moon, broker text, and the floating status display." },
  { key = "baseline", title = "Baseline", build = buildBaseline,
    desc = "Your own look: what Duskfall starts from and puts back when you log out." },
  { key = "chars", title = "Characters", build = buildCharacters,
    desc = "Characters Duskfall knows. Remove the ones you deleted." },
}

-- Settings tab ------------------------------------------------------------------------------------
W.AddTab("settings", "Settings", function(page)
  UI.Glow(page, nil, 0.8)
  local overview = CreateFrame("Frame", nil, page)
  overview:SetAllPoints()
  local open

  local title = UI.Header(overview, "Settings")
  title:SetFontObject("GameFontNormalLarge")
  title:SetPoint("TOPLEFT", overview, "TOPLEFT", 12, -12)
  local y = -48
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

    local row = CreateFrame("Frame", nil, overview)
    row:SetPoint("TOPLEFT", overview, "TOPLEFT", 12, y)
    row:SetPoint("RIGHT", overview, "RIGHT", -12, 0)
    row:SetHeight(44)
    local btn = UI.Button(row, "Settings", 100, function() open(def.key) end)
    btn:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -2)
    local rt = UI.Label(row, def.title, "GameFontNormal")
    rt:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -4)
    local rd = UI.Label(row, def.desc)
    rd:SetTextColor(0.65, 0.65, 0.65)
    rd:SetPoint("TOPLEFT", rt, "BOTTOMLEFT", 0, -4)
    rd:SetPoint("RIGHT", btn, "LEFT", -12, 0)
    y = y - 54
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
    "|cffffd100/dusk help|r   every command",
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
