-- Duskfall UI/Styles.lua: the Styles tab (B-04d).
--   left:  every Style: name, who uses it (Global / characters / unused), number of Looks; the one
--          this character uses is marked. New, Duplicate, Delete (the last Style can't go).
--   right: the selected Style: name, scope (UI.ScopeDropdown, Copy / Paste), its transition
--          (mode, fade duration, Adapt to-dark / to-light duration and strength) and Try it.
-- Scopes never overlap: picking a character takes it out of the Style it was in, picking Global
-- makes the other Global Style unused; a note under the dropdown says what moved.
-- Try it: dark, then back, with the selected Style's own transition (D.Preview, why "demo").
local ADDON, ns = ...
local L = ns.L
local UI, W, C, S, D, R = ns.UI, ns.Window, ns.Channels, ns.Situations, ns.Detect, ns.Resolver

local LEFT_W = 270
local ROW_H = 36
local GREY = "|cff9d9d9d"
local MODES = { { "instant", L["SS_INSTANT"] }, { "fade", L["ST_FADE"] }, { "adapt", L["ST_ADAPT"] } }

local function changed(why)
  D.ClearHolds()
  D.state.target = nil
  D.Evaluate(why)
end

local function trOf(st)
  st.transition = st.transition or {}
  local tr = st.transition
  tr.mode = tr.mode or "adapt"
  tr.fade = tr.fade or { duration = 1.5 }
  tr.adapt = tr.adapt or {}
  tr.adapt.toDark = tr.adapt.toDark or { duration = 4.0, strength = 0.3 }
  tr.adapt.toLight = tr.adapt.toLight or { duration = 1.0, strength = 0.3 }
  return tr
end

local function charsOf(scope)
  if type(scope) == "table" and not scope.global and type(scope.chars) == "table" then return scope.chars end
  return nil
end

-- Takes what st's scope names away from the other Styles. Returns notes on what moved.
local function claim(st)
  local notes = {}
  local global = UI.ScopeIsGlobal(st.scope, true)
  local mine = charsOf(st.scope) or {}
  for _, o in ipairs(ns.db.styles) do
    if o ~= st then
      if global and UI.ScopeIsGlobal(o.scope, true) then
        o.scope = { chars = {} }
        notes[#notes + 1] = string.format("\"%s\" is no longer Global (now unused).", o.name or "?")
      end
      local theirs = charsOf(o.scope)
      if theirs then
        for guid in pairs(mine) do
          if theirs[guid] then
            theirs[guid] = nil
            notes[#notes + 1] = string.format("%s left \"%s\".", ns.CharName(guid), o.name or "?")
          end
        end
      end
    end
  end
  return notes
end

ns.StyleClaim = claim

-- Try it: darker, a short hold, and back, with st's own transition, wherever you are. Shared
-- with simple mode (UI/SimpleStyles.lua). Returns the seconds it takes, nil when it can't run.
function ns.TryStyle(st)
  if not ns.cfg.enabled then ns.Print(L["ST_TRY_OFF"]) return nil end
  local tr = trOf(st)
  local normal = R.Resolve(D.state.env or S.Snapshot())
  local dark = {}
  for k, v in pairs(normal) do dark[k] = v end
  dark.gamma = C.Clamp("gamma", normal.gamma - 0.5)
  dark.brightness = C.Clamp("brightness", normal.brightness - 20)
  local d1, d2 = 0, 0
  if tr.mode == "fade" then d1, d2 = tr.fade.duration, tr.fade.duration
  elseif tr.mode == "adapt" then d1, d2 = tr.adapt.toDark.duration, tr.adapt.toLight.duration end
  -- Hold the dark long enough that the way back may overshoot again (settings.adaptGap)
  local hold = math.max(1.5, (tonumber(ns.cfg.adaptGap) or 2) - d1 + 0.2)
  local total = d1 + hold + d2 + 0.5
  D.Preview(dark, total, { why = "demo", style = st })
  local pv = D.state.preview
  C_Timer.After(d1 + hold, function()
    if D.state.preview ~= pv then return end
    pv.target = normal
    D.Evaluate("demo")
  end)
  return total
end
ns.StyleTransition = trOf

local function copyStyle(st)
  local c = UI.DeepCopy(st)
  c.id = ns.NewID("s")
  c.name = L["ST_COPY_NAME"]:format(st.name or L["STYLE_DEFAULT"])
  c.scope = { chars = {} }
  for _, l in ipairs(c.looks or {}) do l.id = ns.NewID("l") end
  return c
end

ns.StyleCopy = copyStyle

-- The tab holds two pages: simple mode (UI/SimpleStyles.lua, the default) and this one, Advanced mode.
W.AddTab("styles", L["TAB_STYLES"], function(tab)
  UI.Glow(tab, nil, 0.8)
  local page = CreateFrame("Frame", nil, tab)
  page:SetAllPoints()
  page:Hide()
  local sel
  local refresh, refreshList, refreshUse

  -- Left: the list ---------------------------------------------------------------------------
  local left = CreateFrame("Frame", nil, page)
  left:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
  left:SetWidth(LEFT_W)

  local head = UI.Header(left, L["TAB_STYLES"])
  head:SetPoint("TOPLEFT", left, "TOPLEFT", 12, -12)

  local area = CreateFrame("Frame", nil, left)
  area:SetPoint("TOPLEFT", left, "TOPLEFT", 8, -34)
  area:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -18, 40)
  UI.RoundBox(area, { radius = 8, bottom = { 0, 0, 0, 0.32 }, top = { 0, 0, 0, 0.22 } })
  local box = CreateFrame("Frame", nil, area, "WowScrollBoxList")
  box:SetAllPoints()
  local scroll = CreateFrame("EventFrame", nil, left, "MinimalScrollBar")
  scroll:SetPoint("TOPLEFT", area, "TOPRIGHT", 4, 0)
  scroll:SetPoint("BOTTOMLEFT", area, "BOTTOMRIGHT", 4, 0)

  local view = CreateScrollBoxListLinearView()
  view:SetElementExtent(ROW_H)
  view:SetElementInitializer("Button", function(row, st)
    if not row.name then
      row.sel = row:CreateTexture(nil, "BACKGROUND", nil, 2)
      row.sel:SetAllPoints()
      row.sel:SetColorTexture(1, 0.82, 0, 0.2)
      local hl = row:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 1, 1, 0.08)
      row.name = UI.Label(row, "", "GameFontHighlight")
      row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
      row.name:SetPoint("RIGHT", row, "RIGHT", -6, 0)
      row.name:SetWordWrap(false)
      row.info = UI.Label(row, "", "GameFontHighlightSmall")
      row.info:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
      row.info:SetPoint("RIGHT", row, "RIGHT", -6, 0)
      row.info:SetWordWrap(false)
      row.info:SetTextColor(0.75, 0.75, 0.75)
    end
    local name = st.name or "?"
    if st == R.ActiveStyle() then name = name .. "  |cff40ff40" .. L["ST_YOURS"] .. "|r" end
    row.name:SetText(name)
    local who = UI.ScopeText(st.scope, true)
    if who == L["SCOPE_UNUSED"] then who = GREY .. L["SL_UNUSED"] .. "|r" end
    local n = #(st.looks or {})
    row.info:SetText(n == 1 and L["ST_LOOKS_ONE"]:format(who) or L["ST_LOOKS_MANY"]:format(who, n))
    row.sel:SetShown(st == sel)
    row:SetScript("OnClick", function()
      sel = st
      refresh(true)
    end)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(box, scroll, view)
  UI.AutoHideScroll(box, scroll)

  local styles = function() return ns.db.styles end

  local newBtn = UI.Button(left, L["BTN_NEW"], 76, function()
    local st = ns.NewStyle(L["SL_STYLE_NEW_NAME"]:format(#styles() + 1))
    st.scope = { chars = {} }
    table.insert(styles(), st)
    sel = st
    refresh(true)
  end)
  newBtn:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 8, 10)
  UI.Tooltip(newBtn, L["SS_NEW_STYLE"], L["ST_NEW_TIP"])
  local dupBtn = UI.Button(left, L["LE_DUPLICATE"], 84, function()
    if not sel then return end
    local c = copyStyle(sel)
    local at = #styles() + 1
    for i, st in ipairs(styles()) do if st == sel then at = i + 1 end end
    table.insert(styles(), at, c)
    sel = c
    refresh(true)
  end)
  dupBtn:SetPoint("LEFT", newBtn, "RIGHT", 6, 0)
  UI.Tooltip(dupBtn, L["LE_DUPLICATE"], L["ST_DUP_TIP"])
  local delBtn = UI.Button(left, L["BTN_DELETE"], 76, function()
    if not sel or #styles() <= 1 then return end
    local st = sel
    local n = #(st.looks or {})
    UI.Confirm(n == 1 and L["ST_DELETE_ONE"]:format(st.name or "?") or L["ST_DELETE_MANY"]:format(st.name or "?", n), function()
      for i, s in ipairs(styles()) do
        if s == st then table.remove(styles(), i) break end
      end
      sel = nil
      changed("style")
      refresh(true)
    end)
  end)
  delBtn:SetKind("danger")
  delBtn:SetPoint("LEFT", dupBtn, "RIGHT", 6, 0)
  UI.Tooltip(delBtn, L["BTN_DELETE"], L["ST_DELETE_TIP"])

  -- Right: the selected Style ----------------------------------------------------------------
  local right = CreateFrame("Frame", nil, page)
  right:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT_W + 14, 0)
  right:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 0)
  local controls = {}
  local function add(c) controls[#controls + 1] = c return c end

  local title = UI.Header(right, "")
  title:SetFontObject("GameFontNormalLarge")
  title:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -12)
  title:SetPoint("RIGHT", right, "RIGHT", -4, 0)
  title:SetWordWrap(false)

  local nameLbl = UI.Label(right, L["LE_NAME"], "GameFontNormalSmall")
  nameLbl:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -48)
  local scopeLbl = UI.Label(right, L["LE_SCOPE"], "GameFontNormalSmall")
  scopeLbl:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -80)
  -- Name and Scope boxes start after the longer label (German "Geltungsbereich" was cut off)
  local boxX = math.max(50, math.ceil(math.max(nameLbl:GetUnboundedStringWidth(), scopeLbl:GetUnboundedStringWidth())) + 10)
  local name = CreateFrame("EditBox", nil, right, "InputBoxTemplate")
  name:SetSize(240, 20)
  name:SetPoint("LEFT", nameLbl, "LEFT", boxX, 0)
  name:SetAutoFocus(false)
  name:SetMaxLetters(40)
  name:SetScript("OnTextChanged", function(self, user)
    if not user or not sel then return end
    local t = (self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if t ~= "" then
      sel.name = t
      title:SetText(t)
      refreshList()
    end
  end)
  name:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  name:SetScript("OnEditFocusLost", function(self) if sel then self:SetText(sel.name or "") end end)

  local note
  local scopeDD = add(UI.ScopeDropdown(right, 240, { style = true,
    tip = L["ST_SCOPE_TIP"],
    get = function() return sel and sel.scope end,
    set = function(sc)
      if not sel then return end
      sel.scope = sc
      local notes = claim(sel)
      note:SetText(table.concat(notes, " "))
      -- Not refresh(): regenerating the dropdown's menu would close it while you tick
      changed("style")
      refreshList()
      refreshUse()
    end }))
  scopeDD:SetPoint("LEFT", scopeLbl, "LEFT", boxX, 0)

  note = UI.Label(right, "")
  note:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -104)
  note:SetPoint("RIGHT", right, "RIGHT", -4, 0)
  note:SetTextColor(1, 0.62, 0.25)
  local useLine = UI.Label(right, "")
  useLine:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -122)
  useLine:SetPoint("RIGHT", right, "RIGHT", -4, 0)

  local rule = right:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(1, 0.82, 0, 0.25)
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -142)
  rule:SetPoint("TOPRIGHT", right, "TOPRIGHT", -4, -142)

  local trHead = UI.Header(right, L["ST_TRANSITION"])
  trHead:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -152)
  local trTip = UI.Label(right, L["ST_TRANSITION_SUB"])
  trTip:SetPoint("LEFT", trHead, "RIGHT", 8, 0)
  trTip:SetTextColor(0.65, 0.65, 0.65)

  local COL = 236
  local SW = 216
  local sliders = {}
  local function enableSliders()
    local mode = sel and trOf(sel).mode
    sliders.fade:SetEnabled(mode == "fade")
    for _, k in ipairs({ "darkD", "darkS", "lightD", "lightS" }) do sliders[k]:SetEnabled(mode == "adapt") end
  end

  local mode = add(UI.Dropdown(right, SW, { label = L["ST_MODE"], items = MODES,
    tip = L["ST_MODE_TIP"],
    get = function() return sel and trOf(sel).mode end,
    set = function(v)
      if not sel then return end
      trOf(sel).mode = v
      enableSliders()
    end }))
  mode:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -172)

  local secs = function(v) return L["SECS_FMT"]:format(v) end
  local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
  local function slider(key, o, x, y)
    local s = add(UI.Slider(right, SW, o))
    s:SetPoint("TOPLEFT", right, "TOPLEFT", 4 + x, y)
    sliders[key] = s
  end
  slider("fade", { label = L["ST_FADE_DURATION"], min = 0, max = 10, step = 0.1, default = 1.5, fmt = secs,
    get = function() return sel and trOf(sel).fade.duration or 1.5 end,
    onChange = function(v) if sel then trOf(sel).fade.duration = v end end }, COL, -172)

  local darkLbl = UI.Label(right, L["ST_TO_DARKER"], "GameFontNormal")
  darkLbl:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -226)
  local lightLbl = UI.Label(right, L["ST_TO_BRIGHTER"], "GameFontNormal")
  lightLbl:SetPoint("TOPLEFT", right, "TOPLEFT", 4 + COL, -226)
  slider("darkD", { label = L["ST_DURATION"], min = 0, max = 15, step = 0.5, default = 4.0, fmt = secs,
    tip = L["ST_DARK_D_TIP"],
    get = function() return sel and trOf(sel).adapt.toDark.duration or 4.0 end,
    onChange = function(v) if sel then trOf(sel).adapt.toDark.duration = v end end }, 0, -246)
  slider("darkS", { label = L["ST_DIP"], min = 0, max = 1, step = 0.05, default = 0.3, fmt = pct,
    tip = L["ST_DIP_TIP"],
    get = function() return sel and trOf(sel).adapt.toDark.strength or 0.3 end,
    onChange = function(v) if sel then trOf(sel).adapt.toDark.strength = v end end }, 0, -294)
  slider("lightD", { label = L["ST_DURATION"], min = 0, max = 10, step = 0.5, default = 1.0, fmt = secs,
    tip = L["ST_LIGHT_D_TIP"],
    get = function() return sel and trOf(sel).adapt.toLight.duration or 1.0 end,
    onChange = function(v) if sel then trOf(sel).adapt.toLight.duration = v end end }, COL, -246)
  slider("lightS", { label = L["ST_GLARE"], min = 0, max = 1, step = 0.05, default = 0.3, fmt = pct,
    tip = L["ST_GLARE_TIP"],
    get = function() return sel and trOf(sel).adapt.toLight.strength or 0.3 end,
    onChange = function(v) if sel then trOf(sel).adapt.toLight.strength = v end end }, COL, -294)

  -- Rounded cards (Kim): the Style itself, then its transition; they replace the rule
  rule:Hide()
  local c1 = UI.Card(page, LEFT_W + 8, -4, 10, 134)
  c1:SetPoint("RIGHT", page, "RIGHT", -2, 0)
  local c2 = UI.Card(page, LEFT_W + 8, -144, 10, 236)
  c2:SetPoint("RIGHT", page, "RIGHT", -2, 0)
  -- Clarity (1.3.0): a card of its own under the transition
  local c3 = UI.Card(page, LEFT_W + 8, -388, 10, 74)
  c3:SetPoint("RIGHT", page, "RIGHT", -2, 0)
  local clHead = UI.Header(right, L["CLARITY"])
  clHead:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -396)
  local clSub = UI.Label(right, L["CLARITY_SUB"])
  clSub:SetPoint("LEFT", clHead, "RIGHT", 8, 0)
  clSub:SetTextColor(0.65, 0.65, 0.65)
  local clarity = add(UI.Slider(right, COL + SW, { label = L["CLARITY"], min = 0, max = 1, step = 0.05, default = 0.5,
    fmt = pct, tip = L["CLARITY_TIP"],
    get = function() return sel and tonumber(sel.clarity) or 0 end,
    onChange = function(v)
      if not sel then return end
      sel.clarity = v
      if sel == R.ActiveStyle() then D.Evaluate("edit") end
    end }))
  clarity:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -414)

  local tryBtn
  local function tryIt()
    if not sel then return end
    local total = ns.TryStyle(sel)
    if not total then return end
    tryBtn:SetEnabled(false)
    C_Timer.After(total, function() tryBtn:SetEnabled(true) end)
  end
  tryBtn = UI.Button(right, L["TRY_IT"], 110, tryIt)
  tryBtn:SetKind("main")
  tryBtn:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -350)
  UI.Tooltip(tryBtn, L["TRY_IT"], L["ST_TRY_TIP"])
  local tryTip = UI.Label(right, L["ST_TRY_SUB"])
  tryTip:SetPoint("LEFT", tryBtn, "RIGHT", 10, 0)
  tryTip:SetPoint("RIGHT", right, "RIGHT", -4, 0)
  tryTip:SetTextColor(0.65, 0.65, 0.65)

  -- Refresh ----------------------------------------------------------------------------------
  refreshList = function()
    local ok = pcall(box.SetDataProvider, box, CreateDataProvider(styles()), ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
    if not ok then box:SetDataProvider(CreateDataProvider(styles())) end
  end

  refreshUse = function()
    local active = R.ActiveStyle()
    if sel == active then
      useLine:SetText("|cff40ff40" .. L["ST_USES_THIS"] .. "|r")
    else
      useLine:SetText(GREY .. L["ST_USES_OTHER"]:format(active.name or "?") .. "|r")
    end
  end

  -- newSelection: a different Style was picked (clears the note)
  refresh = function(newSelection)
    local found = false
    for _, st in ipairs(styles()) do if st == sel then found = true end end
    if not found then sel = R.ActiveStyle() end
    if newSelection then note:SetText("") end
    refreshList()
    title:SetText(sel.name or "?")
    name:SetText(sel.name or "")
    name:SetCursorPosition(0)
    refreshUse()
    for _, c in ipairs(controls) do ns.Safe(c.Refresh, "styles", c) end
    enableSliders()
    delBtn:SetEnabled(#styles() > 1)
  end

  page:SetScript("OnShow", function() refresh(false) end)
  refresh(true)

  local simple = ns.SimpleStyles.Create(tab)
  local function showMode()
    local adv = ns.cfg.advanced and true or false
    simple:SetShown(not adv)
    page:SetShown(adv)
  end
  ns.Listen("MODE", showMode)
  showMode()
end, "left")
