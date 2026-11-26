-- Duskfall UI/LookEditor.lua: the Look editor (B-04c). Opens over the whole Places tab when a
-- Look is clicked (Back / ESC returns to the list). Two columns:
--   left:  Values (set checkbox, slider, number box, "Current" per channel; Absolute; Copy /
--          Paste), actions (Preview, Revert, Duplicate, Up, Down, Delete), Where list
--   right: When (Any / Yes / No per condition, Time with Custom From / To), what the Look does here now
-- Every edit saves at once and re-evaluates (instant, throttled to 25 a second), so a Look that
-- matches where you stand changes the screen while you drag. Revert = back to how it was on open.
-- Scope: UI.ScopeDropdown (Global or characters, Copy / Paste scope, Apply to all Looks).
-- Public: E.Create(parent, hooks) -> editor; editor:Open(look, placeKey), editor:Close(),
--         editor:RefreshNow(). hooks = { onClose = fn(), onOpen = fn(look) }
local ADDON, ns = ...
local UI, C, S, D, R = ns.UI, ns.Channels, ns.Situations, ns.Detect, ns.Resolver
local E = {}
ns.LookEditor = E

local COL_W = 350
local COL2_X = 386
local PREVIEW_SECONDS = 10
local STEP = { gamma = 0.01, brightness = 1, contrast = 1, bloom = 0.01 }
local GREY = "|cff9d9d9d"

local FLAGS = {
  { "indoors", "Indoors" }, { "resting", "Resting" }, { "combat", "In combat" }, { "mounted", "Mounted" },
  { "swimming", "Swimming" }, { "underwater", "Underwater" }, { "ghost", "Ghost" },
}
local ANY_YES_NO = { { "any", "Any" }, { "yes", "Yes" }, { "no", "No" } }
local TIMES = { { "any", "Any" }, { "dawn", "Dawn" }, { "day", "Day" }, { "dusk", "Dusk" }, { "night", "Night" }, { "custom", "Custom" } }
local ITYPES = { "itype:party", "itype:raid", "itype:pvp", "itype:arena", "itype:scenario" }
local KIND_LABEL = { sub = "Subzone", zone = "Zone", instance = "Instance" }

-- Helpers ----------------------------------------------------------------------------------------
local deepCopy = UI.DeepCopy

local function round(k, v) return tonumber(C.Format(k, v)) end

local function baseOf(k)
  local b = ns.db.baseline or {}
  return b[k] or C.Read(k) or 0
end

-- The slider range of a channel: the channel's own range, or as offsets from the baseline.
local function range(k, absolute)
  local ch = C.byKey[k]
  if absolute then return ch.min, ch.max end
  local b = baseOf(k)
  return round(k, ch.min - b), round(k, ch.max - b)
end

local function bare(s) return (s:gsub("^[~!]+", "")) end

-- When: one flag as "any" / "yes" / "no" ("outdoors" counts as indoors: no).
local function flagState(look, f)
  for _, s in ipairs(look.when or {}) do
    if s:sub(1, 1) ~= "~" then
      local neg = s:sub(1, 1) == "!"
      local b = bare(s)
      if b == f then if neg then return "no" end return "yes" end
      if f == "indoors" and b == "outdoors" then if neg then return "yes" end return "no" end
    end
  end
  return "any"
end

local function setFlag(look, f, v)
  local keep = {}
  for _, s in ipairs(look.when or {}) do
    local b = bare(s)
    if not (b == f or (f == "indoors" and b == "outdoors")) then keep[#keep + 1] = s end
  end
  if v == "yes" then keep[#keep + 1] = f elseif v == "no" then keep[#keep + 1] = "!" .. f end
  look.when = keep
end

local function timeEntry(look)
  for _, s in ipairs(look.when or {}) do
    if s:sub(1, 1) ~= "~" then
      local neg = s:sub(1, 1) == "!"
      local rest = bare(s):match("^time:(.+)$")
      if rest then return rest, neg end
    end
  end
  return nil
end

-- "any", a period, "custom", or "other" (a negated time from /dusk save, shown as it is).
local function timeState(look)
  local rest, neg = timeEntry(look)
  if not rest then return "any" end
  if neg then return "other" end
  if rest:find("-", 1, true) then return "custom" end
  return rest
end

local function customRange(look)
  local rest = timeEntry(look)
  local h1, m1, h2, m2 = (rest or ""):match("^(%d+):(%d+)%-(%d+):(%d+)$")
  if h1 then return tonumber(h1), tonumber(m1), tonumber(h2), tonumber(m2) end
  local b = ns.cfg.buckets
  return b.night, 0, b.dawn, 0
end

local function setTime(look, str)
  local keep = {}
  for _, s in ipairs(look.when or {}) do
    if not bare(s):match("^time:") then keep[#keep + 1] = s end
  end
  if str then keep[#keep + 1] = str end
  look.when = keep
end

local function customString(h1, m1, h2, m2)
  return string.format("time:%02d:%02d-%02d:%02d", h1, m1, h2, m2)
end

-- "Raven Hill (Duskwood)", "Duskwood (zone)", "The Deadmines (instance)", "All dungeons".
local function whereLabel(key)
  local P = ns.PlaceUI
  local k = P.kindOf(key)
  if k == "itype" then return P.placeName(key) end
  if k == "sub" then return P.placeName(key) .. GREY .. "  (" .. P.zoneName(P.zoneKeyOf(key)) .. ")|r" end
  return P.placeName(key) .. GREY .. "  (" .. string.lower(KIND_LABEL[k] or "?") .. ")|r"
end

-- Create -----------------------------------------------------------------------------------------
function E.Create(parent, hooks)
  hooks = hooks or {}
  local ed = CreateFrame("Frame", nil, parent)
  ed:SetAllPoints()
  ed:Hide()

  -- An empty stand-in until the first Open: the widgets read their getters while being built
  local look = { where = {}, when = {}, values = {}, scope = { global = true } }
  local placeKey, snapshot
  local previewEnd, previewTicker
  local controls = {}            -- everything with :Refresh()
  local loading = false          -- true while the controls are filled from the Look
  local function add(c) controls[#controls + 1] = c return c end

  -- Saving and re-evaluating -----------------------------------------------------------------
  local pending = false
  local refreshNow, refreshPreviewButton

  local function previewTarget()
    local target = R.Resolve(D.state.env or S.Snapshot())
    for _, ch in ipairs(C.list) do
      local k = ch.key
      local v = look.values and tonumber(look.values[k])
      if v ~= nil then
        if look.absolute then target[k] = C.Clamp(k, v) else target[k] = C.Clamp(k, baseOf(k) + v) end
      end
    end
    return target
  end

  local function startPreview(keepTime)
    local left = PREVIEW_SECONDS
    if keepTime and previewEnd then left = math.max(0.5, previewEnd - GetTime()) end
    previewEnd = GetTime() + left
    D.Preview(previewTarget(), left)
    if not previewTicker then
      previewTicker = C_Timer.NewTicker(0.25, function()
        if not D.state.preview or not previewEnd or GetTime() >= previewEnd then
          previewEnd = nil
          if previewTicker then previewTicker:Cancel() previewTicker = nil end
        end
        refreshPreviewButton()
      end)
    end
    refreshPreviewButton()
  end

  local function stopPreview()
    if previewTicker then previewTicker:Cancel() previewTicker = nil end
    if previewEnd then
      previewEnd = nil
      D.Preview(nil)
    end
    refreshPreviewButton()
  end

  local function apply()
    if loading or pending then return end
    pending = true
    C_Timer.After(0.04, function()
      pending = false
      if previewEnd then
        startPreview(true)
      else
        D.ClearHolds()
        D.state.target = nil
        D.Evaluate("edit")
      end
    end)
  end

  local function refreshAll()
    loading = true
    for _, c in ipairs(controls) do ns.Safe(c.Refresh, "editor", c) end
    loading = false
    refreshNow()
  end

  -- Header -------------------------------------------------------------------------------------
  local back = UI.IconButton(ed, 22, "left", { tip = "Back", tipSub = "Back to the place (ESC)", onClick = function() ed:Close() end })
  back:SetPoint("TOPLEFT", ed, "TOPLEFT", 12, -10)
  local title = UI.Header(ed, "Edit Look")
  title:SetFontObject("GameFontNormalLarge")
  title:SetPoint("LEFT", back, "RIGHT", 8, 0)
  local from = UI.Label(ed, "")
  from:SetPoint("LEFT", title, "RIGHT", 12, 0)
  from:SetPoint("RIGHT", ed, "RIGHT", -12, 0)
  from:SetWordWrap(false)
  from:SetTextColor(0.7, 0.7, 0.7)

  local nameLbl = UI.Label(ed, "Name", "GameFontNormalSmall")
  nameLbl:SetPoint("TOPLEFT", ed, "TOPLEFT", 12, -48)
  local name = CreateFrame("EditBox", nil, ed, "InputBoxTemplate")
  name:SetSize(220, 20)
  name:SetPoint("LEFT", nameLbl, "LEFT", 44, 0)
  name:SetAutoFocus(false)
  name:SetMaxLetters(60)
  name:SetScript("OnTextChanged", function(self, user)
    if not user or loading then return end
    local t = (self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if t ~= "" then look.name = t end
  end)
  name:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  name:SetScript("OnEscapePressed", function(self)
    self:SetText(look.name or "")
    self:ClearFocus()
  end)
  name:SetScript("OnEditFocusLost", function(self) self:SetText(look.name or "") end)
  add({ Refresh = function() name:SetText(look.name or "") name:SetCursorPosition(0) end })

  local onCheck = add(UI.Check(ed, { label = "On", tip = "An off Look is kept but never used.",
    get = function() return look.on ~= false end,
    set = function(v) look.on = v apply() end }))
  onCheck:SetPoint("LEFT", name, "RIGHT", 14, 0)

  local scopeLbl = UI.Label(ed, "Scope", "GameFontNormalSmall")
  scopeLbl:SetPoint("LEFT", onCheck, "RIGHT", 50, 0)
  local scopeDD = add(UI.ScopeDropdown(ed, 220, {
    tip = "Who this Look is for: Global (everyone using this Style), or only the characters you tick.",
    get = function() return look.scope end,
    set = function(sc)
      look.scope = sc
      apply()
    end,
    extra = function(root)
      root:CreateButton("Apply this scope to all Looks in this Style", function()
        local style = R.ActiveStyle()
        UI.Confirm("Give every Look in Style \"" .. (style.name or "?") .. "\" the scope " ..
          UI.ScopeText(look.scope) .. "?", function()
          for _, l in ipairs(style.looks) do l.scope = UI.DeepCopy(look.scope) end
          apply()
        end)
      end)
    end }))
  scopeDD:SetPoint("LEFT", scopeLbl, "RIGHT", 8, 0)

  local rule = ed:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(1, 0.82, 0, 0.25)
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", ed, "TOPLEFT", 12, -70)
  rule:SetPoint("TOPRIGHT", ed, "TOPRIGHT", -12, -70)

  -- Values (left column) ---------------------------------------------------------------------
  local col1 = CreateFrame("Frame", nil, ed)
  col1:SetPoint("TOPLEFT", ed, "TOPLEFT", 12, -78)
  col1:SetPoint("BOTTOMLEFT", ed, "BOTTOMLEFT", 12, 6)
  col1:SetWidth(COL_W)

  local valHead = UI.Header(col1, "Values")
  valHead:SetPoint("TOPLEFT", col1, "TOPLEFT", 0, -4)

  local absCheck = add(UI.Check(col1, { label = "Absolute",
    tip = "Off: the values are offsets from your baseline (+/-), so they follow it when you change it. On: fixed values.",
    get = function() return look.absolute end,
    set = function(v)
      -- Converted so the screen stays the same
      look.values = look.values or {}
      for _, ch in ipairs(C.list) do
        local k = ch.key
        local x = tonumber(look.values[k])
        if x ~= nil then
          if v and not look.absolute then look.values[k] = round(k, C.Clamp(k, baseOf(k) + x))
          elseif not v and look.absolute then look.values[k] = round(k, x - baseOf(k)) end
        end
      end
      look.absolute = v and true or false
      refreshAll()
      apply()
    end }))
  absCheck:SetPoint("LEFT", valHead, "RIGHT", 16, 0)

  local paste
  local copy = UI.Button(col1, "Copy", 56, function()
    ns.valueClip = { absolute = look.absolute and true or false, values = deepCopy(look.values or {}) }
    paste:SetEnabled(true)
  end, 20)
  copy:SetPoint("TOPRIGHT", col1, "TOPRIGHT", -62, -2)
  UI.Tooltip(copy, "Copy values", "Remember this Look's values to paste into another Look.")
  paste = UI.Button(col1, "Paste", 56, function()
    local clip = ns.valueClip
    if not clip then return end
    local out = {}
    for k, x in pairs(clip.values) do
      x = tonumber(x)
      if x ~= nil and C.byKey[k] then
        if clip.absolute == (look.absolute and true or false) then out[k] = x
        elseif look.absolute then out[k] = round(k, C.Clamp(k, baseOf(k) + x))
        else out[k] = round(k, x - baseOf(k)) end
      end
    end
    look.values = out
    refreshAll()
    apply()
  end, 20)
  paste:SetPoint("TOPRIGHT", col1, "TOPRIGHT", 0, -2)
  UI.Tooltip(paste, "Paste values", "Replace this Look's values with the copied ones.")
  add({ Refresh = function() paste:SetEnabled(ns.valueClip ~= nil) end })

  local function channelRow(ch, y)
    local k = ch.key
    local row = CreateFrame("Frame", nil, col1)
    row:SetPoint("TOPLEFT", col1, "TOPLEFT", 0, y)
    row:SetSize(COL_W, 28)
    local set = UI.Switch(row, {})
    set:SetPoint("LEFT", row, "LEFT", 0, 0)
    UI.Tooltip(set, ch.label, "On: this Look sets " .. ch.label .. ". Off: it falls through to the next Look, or your baseline.")
    local lbl = UI.Label(row, ch.label, "GameFontHighlightSmall")
    lbl:SetPoint("LEFT", set, "RIGHT", 6, 0)
    lbl:SetWidth(60)
    local cur = UI.Button(row, "Current", 60, nil, 20)
    cur:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    UI.Tooltip(cur, "Use current", "Take the " .. ch.label .. " on screen now (for example after moving the game's own slider).")
    local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    box:SetSize(44, 20)
    box:SetPoint("RIGHT", cur, "LEFT", -8, 0)
    box:SetAutoFocus(false)
    box:SetJustifyH("CENTER")
    local muted = false
    local lo, hi = 0, 1
    local slVal = 0
    local setValue
    -- Our own slider (Kim): the channel's gradient, < > steppers, the mark at "no change"
    -- (0 for offsets, your baseline for fixed values)
    local g = UI.CHANNEL_GRADIENT[k]
    local sl = UI.LightSlider(row, 10, { labelW = 0, valueW = 0, min = lo, max = hi, step = STEP[k],
      from = g.from, to = g.to, steppers = true, lineH = 12,
      get = function() return slVal end,
      set = function(v)
        slVal = v
        if muted or loading then return end
        if look.values == nil or look.values[k] == nil then return end
        local n = round(k, lo + math.floor((v - lo) / STEP[k] + 0.5) * STEP[k])
        if n == look.values[k] then return end
        setValue(n)
      end })
    sl:SetPoint("LEFT", lbl, "RIGHT", 0, 0)
    sl:SetPoint("RIGHT", box, "LEFT", -8, 0)
    local function show(v)
      if v == nil then
        box:SetText("-")
        return
      end
      local s = C.Format(k, v)
      if not look.absolute and v >= 0 then s = "+" .. s end
      box:SetText(s)
    end
    setValue = function(v)
      look.values = look.values or {}
      if v ~= nil then v = round(k, math.max(lo, math.min(hi, v))) end
      look.values[k] = v
      show(v)
      apply()
    end
    set.onToggle = function(self)
      if self:GetChecked() then
        local start = 0
        if look.absolute then start = round(k, baseOf(k)) end
        setValue(start)
      else
        setValue(nil)
      end
      row:Refresh()
    end
    cur:SetScript("OnClick", function()
      local v = C.Read(k)
      if v == nil then return end
      if not look.absolute then v = v - baseOf(k) end
      setValue(v)
      row:Refresh()
    end)
    box:SetScript("OnEnterPressed", function(self)
      local v = tonumber(((self:GetText() or ""):gsub("^%+", "")))
      self:ClearFocus()
      if v == nil then row:Refresh() return end
      setValue(v)
      row:Refresh()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() row:Refresh() end)
    box:SetScript("OnEditFocusLost", function() row:Refresh() end)

    function row:Refresh()
      lo, hi = range(k, look.absolute)
      local v = look.values and tonumber(look.values[k])
      local on = v ~= nil
      set:SetChecked(on, true)
      muted = true
      local start = v
      if start == nil then
        if look.absolute then start = baseOf(k) else start = 0 end
      end
      start = math.max(lo, math.min(hi, start))
      sl:SetRange(lo, hi, look.absolute and baseOf(k) or 0)
      slVal = start
      sl:SetValue(start, true)
      sl:SetEnabled(on)
      muted = false
      pcall(box.SetEnabled, box, on)
      show(v)
      lbl:SetTextColor(on and 1 or 0.5, on and 1 or 0.5, on and 1 or 0.5)
    end
    return row
  end

  for i, ch in ipairs(C.list) do
    add(channelRow(ch, -26 - (i - 1) * 30))
  end

  local baseNote = UI.Label(col1, "")
  baseNote:SetPoint("TOPLEFT", col1, "TOPLEFT", 0, -26 - #C.list * 30 - 2)
  baseNote:SetPoint("RIGHT", col1, "RIGHT", 0, 0)
  baseNote:SetTextColor(0.65, 0.65, 0.65)
  add({ Refresh = function()
    if look.absolute then
      baseNote:SetText("Fixed values: your baseline does not change them.")
    else
      local b = {}
      for _, ch in ipairs(C.list) do b[#b + 1] = ch.short .. " " .. C.Format(ch.key, baseOf(ch.key)) end
      baseNote:SetText("Offsets from your baseline: " .. table.concat(b, "  "))
    end
  end })

  -- Actions ----------------------------------------------------------------------------------
  local actY = -26 - #C.list * 30 - 26
  local previewBtn = UI.Button(col1, "Preview", 110, function()
    if previewEnd then stopPreview() else startPreview(false) end
  end)
  previewBtn:SetPoint("TOPLEFT", col1, "TOPLEFT", 0, actY)
  UI.Tooltip(previewBtn, "Preview", "Show this Look's values for " .. PREVIEW_SECONDS .. " seconds, even where it does not match. Click again to stop.")
  refreshPreviewButton = function()
    if previewEnd then
      previewBtn:SetText(string.format("Stop (%d)", math.max(0, math.ceil(previewEnd - GetTime()))))
    else
      previewBtn:SetText("Preview")
    end
  end

  local revert = UI.Button(col1, "Revert", 110, function()
    if not snapshot then return end
    for kk in pairs(look) do look[kk] = nil end
    for kk, v in pairs(deepCopy(snapshot)) do look[kk] = v end
    refreshAll()
    apply()
  end)
  revert:SetPoint("LEFT", previewBtn, "RIGHT", 10, 0)
  UI.Tooltip(revert, "Revert", "Back to how this Look was when you opened it.")

  local function styleIndex()
    local style = R.ActiveStyle()
    for i, l in ipairs(style.looks) do if l == look then return i, style end end
    return nil, style
  end

  local dup = UI.Button(col1, "Duplicate", 110, function()
    local i, style = styleIndex()
    local copyLook = deepCopy(look)
    copyLook.id = ns.NewID("l")
    copyLook.name = (look.name or "Look") .. " (copy)"
    table.insert(style.looks, (i or #style.looks) + 1, copyLook)
    ed:Open(copyLook, placeKey)
    apply()
  end)
  dup:SetPoint("LEFT", revert, "RIGHT", 10, 0)
  UI.Tooltip(dup, "Duplicate", "A copy of this Look, right after it, opened in the editor.")

  local orderLbl
  local function move(dir)
    local i, style = styleIndex()
    if not i then return end
    local j = i + dir
    if j < 1 or j > #style.looks then return end
    style.looks[i], style.looks[j] = style.looks[j], style.looks[i]
    refreshAll()
    apply()
  end
  local up = UI.Button(col1, "Up", 52, function() move(-1) end)
  up:SetPoint("TOPLEFT", previewBtn, "BOTTOMLEFT", 0, -8)
  local down = UI.Button(col1, "Down", 52, function() move(1) end)
  down:SetPoint("LEFT", up, "RIGHT", 6, 0)
  UI.Tooltip(up, "Move up", "Order only decides between two Looks that are equally specific.")
  UI.Tooltip(down, "Move down", "Order only decides between two Looks that are equally specific.")
  orderLbl = UI.Label(col1, "")
  orderLbl:SetPoint("LEFT", down, "RIGHT", 8, 0)
  orderLbl:SetTextColor(0.65, 0.65, 0.65)
  add({ Refresh = function()
    local i, style = styleIndex()
    up:SetEnabled(i ~= nil and i > 1)
    down:SetEnabled(i ~= nil and i < #style.looks)
    orderLbl:SetText(i and string.format("%d of %d", i, #style.looks) or "")
  end })

  local del = UI.Button(col1, "Delete", 110, function()
    UI.Confirm("Delete the Look \"" .. (look.name or "?") .. "\"?", function()
      local i, style = styleIndex()
      if i then table.remove(style.looks, i) end
      stopPreview()
      D.ClearHolds()
      D.state.target = nil
      D.Evaluate("edit")
      ed:Close()
    end)
  end)
  del:SetPoint("TOPLEFT", dup, "BOTTOMLEFT", 0, -8)

  -- Where (left column, bottom) --------------------------------------------------------------
  local whereY = actY - 68
  local whereHead = UI.Header(col1, "Where")
  whereHead:SetPoint("TOPLEFT", col1, "TOPLEFT", 0, whereY)
  local whereTip = UI.Label(col1, "any one of these")
  whereTip:SetPoint("LEFT", whereHead, "RIGHT", 8, 0)
  whereTip:SetTextColor(0.65, 0.65, 0.65)

  local wArea = CreateFrame("Frame", nil, col1)
  wArea:SetPoint("TOPLEFT", col1, "TOPLEFT", 0, whereY - 18)
  wArea:SetPoint("RIGHT", col1, "RIGHT", -14, 0)
  wArea:SetHeight(22 * 4)
  UI.RoundBox(wArea, { radius = 8, bottom = { 0, 0, 0, 0.32 }, top = { 0, 0, 0, 0.22 } })
  local wBox = CreateFrame("Frame", nil, wArea, "WowScrollBoxList")
  wBox:SetAllPoints()
  local wScroll = CreateFrame("EventFrame", nil, col1, "MinimalScrollBar")
  wScroll:SetPoint("TOPLEFT", wArea, "TOPRIGHT", 4, 0)
  wScroll:SetPoint("BOTTOMLEFT", wArea, "BOTTOMRIGHT", 4, 0)
  local wEmpty = UI.Label(wArea, "No places: this Look counts everywhere.")
  wEmpty:SetPoint("CENTER")
  wEmpty:SetTextColor(1, 0.62, 0.25)

  local refreshWhere
  local wView = CreateScrollBoxListLinearView()
  wView:SetElementExtent(22)
  wView:SetElementInitializer("Frame", function(row, e)
    if not row.name then
      row.on = UI.Switch(row, {})
      row.on:SetPoint("LEFT", row, "LEFT", 2, 0)
      UI.Tooltip(row.on, "On / off", "A place switched off is kept in the list but not used.")
      row.x = UI.Button(row, "X", 22, nil, 18)
      row.x:SetPoint("RIGHT", row, "RIGHT", -4, 0)
      UI.Tooltip(row.x, "Remove", "Take this place out of the Look.")
      row.name = UI.Label(row, "", "GameFontHighlightSmall")
      row.name:SetPoint("LEFT", row.on, "RIGHT", 6, 0)
      row.name:SetPoint("RIGHT", row.x, "LEFT", -6, 0)
      row.name:SetWordWrap(false)
    end
    local key, off = e.str, false
    if key:sub(1, 1) == "~" then key, off = key:sub(2), true end
    row.name:SetText(whereLabel(key))
    row.name:SetAlpha(off and 0.5 or 1)
    row.on:SetChecked(not off, true)
    row.on.onToggle = function(self)
      look.where[e.index] = (self:GetChecked() and "" or "~") .. key
      refreshWhere()
      apply()
    end
    row.x:SetScript("OnClick", function()
      table.remove(look.where, e.index)
      refreshWhere()
      apply()
    end)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(wBox, wScroll, wView)
  UI.AutoHideScroll(wBox, wScroll)

  refreshWhere = function()
    local list = {}
    for i, s in ipairs(look.where or {}) do list[#list + 1] = { index = i, str = s } end
    wBox:SetDataProvider(CreateDataProvider(list))
    local any = false
    for _, s in ipairs(look.where or {}) do if s:sub(1, 1) ~= "~" then any = true end end
    wEmpty:SetShown(not any)
    if #list > 0 and not any then wEmpty:SetText("All places are off: this Look counts everywhere.")
    else wEmpty:SetText("No places: this Look counts everywhere.") end
  end
  add({ Refresh = function() refreshWhere() end })

  local function addWhere(key)
    look.where = look.where or {}
    for i, s in ipairs(look.where) do
      if s == key then return end
      if s == "~" .. key then
        look.where[i] = key
        refreshWhere()
        apply()
        return
      end
    end
    look.where[#look.where + 1] = key
    refreshWhere()
    apply()
  end

  local addHere = UI.Button(col1, "Add current place", 150, function(self)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(self, function(_, root)
      local env = S.Snapshot()
      local any = false
      for _, kind in ipairs({ "sub", "zone", "instance" }) do
        local key = S.PlaceKey(kind, env)
        if key then
          any = true
          root:CreateButton(KIND_LABEL[kind] .. ": " .. (S.PlaceName(kind, env) or key), function() addWhere(key) end)
        end
      end
      if not any then root:CreateTitle("No place to add here") end
    end)
  end)
  addHere:SetPoint("TOPLEFT", wArea, "BOTTOMLEFT", 0, -6)
  local addType = UI.Button(col1, "Add instance type", 150, function(self)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(self, function(_, root)
      for _, key in ipairs(ITYPES) do
        root:CreateButton(ns.PlaceUI.placeName(key), function() addWhere(key) end)
      end
    end)
  end)
  addType:SetPoint("LEFT", addHere, "RIGHT", 8, 0)

  -- When (right column) ----------------------------------------------------------------------
  local col2 = CreateFrame("Frame", nil, ed)
  col2:SetPoint("TOPLEFT", ed, "TOPLEFT", COL2_X, -78)
  col2:SetPoint("BOTTOMRIGHT", ed, "BOTTOMRIGHT", -12, 6)

  local whenHead = UI.Header(col2, "When")
  whenHead:SetPoint("TOPLEFT", col2, "TOPLEFT", 0, -4)
  local whenTip = UI.Label(col2, "all of these")
  whenTip:SetPoint("LEFT", whenHead, "RIGHT", 8, 0)
  whenTip:SetTextColor(0.65, 0.65, 0.65)

  local DD_W, DD_STEP = 160, 48
  for i, f in ipairs(FLAGS) do
    local c = (i - 1) % 2
    local r = math.floor((i - 1) / 2)
    local dd = add(UI.Dropdown(col2, DD_W, { label = f[2], items = ANY_YES_NO,
      tip = (f[1] == "indoors") and "Yes = indoors, No = outdoors. Inside instances the game never reports indoors." or nil,
      get = function() return flagState(look, f[1]) end,
      set = function(v) setFlag(look, f[1], v) apply() end }))
    dd:SetPoint("TOPLEFT", col2, "TOPLEFT", c * (DD_W + 20), -24 - r * DD_STEP)
  end

  local custom
  local timeDD = add(UI.Dropdown(col2, DD_W, { label = "Time",
    tip = "Dawn, day, dusk and night follow Settings > Time of day.",
    items = function()
      local list = {}
      for _, t in ipairs(TIMES) do list[#list + 1] = t end
      if look and timeState(look) == "other" then
        list[#list + 1] = { "other", "Not " .. (timeEntry(look) or "?") }
      end
      return list
    end,
    get = function() return timeState(look) end,
    set = function(v)
      if v == "any" then setTime(look, nil)
      elseif v == "custom" then setTime(look, customString(customRange(look)))
      elseif v ~= "other" then setTime(look, "time:" .. v) end
      custom:Refresh()
      apply()
    end }))
  timeDD:SetPoint("TOPLEFT", col2, "TOPLEFT", DD_W + 20, -24 - 3 * DD_STEP)

  -- Custom From / To: hour + minute, as BNB's alarm picker
  custom = CreateFrame("Frame", nil, col2)
  custom:SetPoint("TOPLEFT", col2, "TOPLEFT", 0, -24 - 4 * DD_STEP)
  custom:SetSize(COL_W, UI.DROPDOWN_H)
  local HOURS, MINS = {}, {}
  local function hourItems()
    wipe(HOURS)
    for h = 0, 23 do HOURS[#HOURS + 1] = { h, ns.FormatHour(h) } end
    return HOURS
  end
  for m = 0, 55, 5 do MINS[#MINS + 1] = { m, string.format(":%02d", m) } end
  local function part(i)
    return function()
      local v = { customRange(look) }
      return v[i]
    end
  end
  local function setPart(i)
    return function(val)
      local v = { customRange(look) }
      v[i] = val
      setTime(look, customString(v[1], v[2], v[3], v[4]))
      apply()
    end
  end
  local pickers = {
    UI.Dropdown(custom, 84, { label = "From", items = hourItems, get = part(1), set = setPart(1) }),
    UI.Dropdown(custom, 64, { label = " ", items = MINS, get = part(2), set = setPart(2) }),
    UI.Dropdown(custom, 84, { label = "To", items = hourItems, get = part(3), set = setPart(3) }),
    UI.Dropdown(custom, 64, { label = " ", items = MINS, get = part(4), set = setPart(4) }),
  }
  local px = 0
  for i, p in ipairs(pickers) do
    p:SetPoint("TOPLEFT", custom, "TOPLEFT", px, 0)
    px = px + p:GetWidth() + ((i % 2 == 0) and 18 or 6)
  end
  function custom:Refresh()
    local on = timeState(look) == "custom"
    self:SetShown(on)
    if on then for _, p in ipairs(pickers) do p:Refresh() end end
  end
  add(custom)

  -- What the Look does where you stand
  local nowHead = UI.Header(col2, "Here now")
  nowHead:SetPoint("TOPLEFT", col2, "TOPLEFT", 0, -24 - 5 * DD_STEP - 8)
  local nowText = UI.Label(col2, "", "GameFontHighlight")
  nowText:SetPoint("TOPLEFT", nowHead, "BOTTOMLEFT", 0, -6)
  nowText:SetPoint("RIGHT", col2, "RIGHT", 0, 0)
  local nowSub = UI.Label(col2, "")
  nowSub:SetPoint("TOPLEFT", nowText, "BOTTOMLEFT", 0, -4)
  nowSub:SetPoint("RIGHT", col2, "RIGHT", 0, 0)
  nowSub:SetTextColor(0.65, 0.65, 0.65)

  refreshNow = function()
    if not look then return end
    local active, matching = ns.PlaceUI.liveSets()
    local text, sub
    if previewEnd then
      text = "|cffffd100Previewing|r"
      sub = "The screen shows this Look's values until the preview ends."
    elseif look.on == false then
      text = GREY .. "Off|r"
      sub = "Switched off: never used."
    elseif not ns.ScopeOf(look.scope, ns.charKey) then
      text = GREY .. "Not for this character|r"
      sub = "Its scope names other characters."
    elseif active[look] then
      text = "|cff40ff40In effect|r"
      sub = "It sets the screen where you stand now, so edits show at once."
    elseif matching[look] then
      text = "|cffffd100Matches, outranked|r"
      sub = "A more specific Look wins here (or sets every channel this one sets)."
    else
      text = GREY .. "Does not match here|r"
      sub = "Use Preview to see it."
    end
    nowText:SetText(text)
    nowSub:SetText(sub)
  end

  -- Open / close -----------------------------------------------------------------------------
  function ed:Open(l, key)
    if previewEnd then stopPreview() end
    look, placeKey = l, key
    look.where = look.where or {}
    look.when = look.when or {}
    look.values = look.values or {}
    snapshot = deepCopy(look)
    if key then from:SetText("from " .. ns.PlaceUI.placeName(key)) else from:SetText("") end
    self:Show()
    refreshAll()
    if hooks.onOpen then ns.Safe(hooks.onOpen, "editor open", look) end
  end

  function ed:Close()
    stopPreview()
    name:ClearFocus()
    self:Hide()
    if hooks.onClose then ns.Safe(hooks.onClose, "editor close", look) end
  end

  function ed:RefreshNow() if self:IsShown() then refreshNow() end end
  function ed:Look() return look end

  -- Closing the window ends a preview
  ed:SetScript("OnHide", function()
    if previewEnd then stopPreview() end
  end)

  return ed
end
