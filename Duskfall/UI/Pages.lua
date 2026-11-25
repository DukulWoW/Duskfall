-- Duskfall UI/Pages.lua: the tabs of the settings window built in B-04a: Settings and Characters.
-- Places (B-04b) and Styles (B-04d) are placeholders until then.
local ADDON, ns = ...
local UI, W, C, D = ns.UI, ns.Window, ns.Channels, ns.Detect

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

local function placeholder(page, text)
  UI.Glow(page, nil, 0.8)
  local fs = UI.Label(page, text, "GameFontHighlight")
  fs:SetPoint("CENTER")
  fs:SetJustifyH("CENTER")
end

-- Places -----------------------------------------------------------------------------------------
W.AddTab("places", "Places", function(page)
  placeholder(page, "The place list comes in B-04b.\nUntil then: /dusk save, /dusk clear, /dusk looks.")
end)

-- Styles -----------------------------------------------------------------------------------------
W.AddTab("styles", "Styles", function(page)
  placeholder(page, "Styles come in B-04d.\nUntil then: /dusk style, /dusk mode, /dusk fade, /dusk adapt.")
end)

-- Settings ---------------------------------------------------------------------------------------
local ORDER = { "dawn", "day", "dusk", "night" }
local PERIOD_LABEL = { dawn = "Dawn starts", day = "Day starts", dusk = "Dusk starts", night = "Night starts" }

local function hoursValid(b)
  return b.dawn < b.day and b.day < b.dusk and b.dusk < b.night
end

W.AddTab("settings", "Settings", function(page)
  local controls = {}
  local COL_W = 340
  local left = CreateFrame("Frame", nil, page)
  left:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
  left:SetWidth(COL_W + 24)
  UI.Glow(left, nil, 0.8)
  local right = CreateFrame("Frame", nil, page)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
  right:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
  UI.Glow(right, nil, 0.8)

  local function stack(parent)
    local y = -12
    return function(widget, h, gap)
      widget:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
      y = y - (h or 26) - (gap or 8)
      controls[#controls + 1] = widget
      return widget
    end
  end

  -- Left: behaviour
  local L = stack(left)
  L(UI.Header(left, "Behaviour"), 14, 6)
  L(UI.Check(left, { label = "Duskfall on", tip = "Off puts your baseline back and leaves the sliders to you.",
    get = function() return ns.cfg.enabled end,
    set = function(v) D.SetEnabled(v) W.UpdateStatus() end }), 26, 10)
  L(UI.Slider(left, COL_W, { label = "Doorway delay", min = 0, max = 2, step = 0.1, default = 0.5,
    fmt = function(v) return string.format("%.1f s", v) end,
    tip = "How long a new state (indoors, mounted...) must hold before Duskfall reacts. Stops flicker in doorways.",
    get = function() return ns.cfg.debounce end,
    onChange = function(v) ns.cfg.debounce = v end }), UI.SLIDER_H, 10)
  L(UI.Slider(left, COL_W, { label = "Time of day fade", min = 0, max = 120, step = 5, default = 45,
    fmt = function(v) return v .. " s" end,
    tip = "How long a change caused only by the clock takes, in every mode, so dusk never snaps.",
    get = function() return ns.cfg.timeFade end,
    onChange = function(v) ns.cfg.timeFade = v end }), UI.SLIDER_H, 10)
  L(UI.Slider(left, COL_W, { label = "Adapt overshoot gap", min = 0, max = 10, step = 0.5, default = 2,
    fmt = function(v) return string.format("%.1f s", v) end,
    tip = "Two Adapt dips or glares never come closer than this. Riding along a zone border dips once.",
    get = function() return ns.cfg.adaptGap end,
    onChange = function(v) ns.cfg.adaptGap = v end }), UI.SLIDER_H, 14)

  L(UI.Header(left, "Baseline"), 14, 6)
  local baseText = UI.Label(left, "", "GameFontHighlight")
  L(baseText, 14, 8)
  local function showBase()
    local b, parts = ns.db.baseline or {}, {}
    for _, ch in ipairs(C.list) do
      local v = b[ch.key]
      parts[#parts + 1] = ch.label .. " " .. (v and C.Format(ch.key, v) or "-")
    end
    baseText:SetText(table.concat(parts, "   "))
  end
  baseText.Refresh = showBase
  L(UI.Button(left, "Save current as baseline", 200, function()
    UI.Confirm("Make the values on screen now your baseline (the ones logging out brings back)?", function()
      D.SaveBaseline()
      showBase()
      W.UpdateStatus()
    end)
  end), 22, 14)
  L(UI.Check(left, { label = "Debug output", get = function() return ns.cfg.debug end,
    set = function(v) ns.cfg.debug = v end }), 26, 8)

  -- Right: clock
  local R = stack(right)
  R(UI.Header(right, "Clock"), 14, 6)
  R(UI.Dropdown(right, 180, { label = "Time source",
    tip = "Server time matches day and night in the world. Local is your computer's clock.",
    items = { { "server", "Server (matches the sky)" }, { "local", "Local (your computer)" } },
    get = function() return ns.cfg.clock end,
    set = function(v) ns.cfg.clock = v D.Evaluate("settings") end }), UI.DROPDOWN_H, 8)
  local hourDrops = {}
  R(UI.Dropdown(right, 180, { label = "Clock format",
    items = { { true, "24 hour" }, { false, "12 hour" } },
    get = function() return ns.cfg.clock24 end,
    set = function(v)
      ns.cfg.clock24 = v
      for _, d in ipairs(hourDrops) do d:Refresh() end
    end }), UI.DROPDOWN_H, 14)
  R(UI.Header(right, "Parts of the day"), 14, 6)
  local warn = UI.Label(right, "", "GameFontRedSmall")
  for _, key in ipairs(ORDER) do
    local d = UI.Dropdown(right, 180, { label = PERIOD_LABEL[key],
      items = function()
        local list = {}
        for hr = 0, 23 do list[#list + 1] = { hr, ns.FormatHour(hr) } end
        return list
      end,
      get = function() return ns.cfg.buckets[key] end,
      set = function(v)
        local b = {}
        for k, x in pairs(ns.cfg.buckets) do b[k] = x end
        b[key] = v
        if not hoursValid(b) then
          warn:SetText("Must go Dawn < Day < Dusk < Night.")
          return
        end
        warn:SetText("")
        ns.cfg.buckets[key] = v
        D.Evaluate("settings")
      end })
    hourDrops[#hourDrops + 1] = d
    R(d, UI.DROPDOWN_H, 4)
  end
  R(warn, 14, 4)

  page:SetScript("OnShow", function()
    for _, c in ipairs(controls) do
      if c.Refresh then c:Refresh() end
    end
  end)
end)

-- Characters ---------------------------------------------------------------------------------------
W.AddTab("chars", "Characters", function(page)
  UI.Glow(page, nil, 0.8)
  local title = UI.Header(page, "Known characters")
  title:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -12)
  local note = UI.Label(page, "Characters are added when they log in. Remove the ones you deleted; they also leave every scope that names them.")
  note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  note:SetPoint("RIGHT", page, "RIGHT", -12, 0)

  local box = CreateFrame("Frame", nil, page, "WowScrollBoxList")
  box:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -10)
  box:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -30, 10)
  local bar = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
  bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 0)
  bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 8, 0)

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
  ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)

  refresh = function()
    local list = {}
    for guid, c in pairs(ns.db.chars) do list[#list + 1] = { guid = guid, c = c } end
    table.sort(list, function(a, b) return (a.c.name or "") < (b.c.name or "") end)
    for i, e in ipairs(list) do e.index = i end
    box:SetDataProvider(CreateDataProvider(list))
  end
  page:SetScript("OnShow", refresh)
  refresh()
end)
