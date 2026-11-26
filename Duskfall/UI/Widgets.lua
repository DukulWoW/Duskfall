-- Duskfall UI/Widgets.lua: the building blocks of the settings window.
-- Patterns from BigNoteBox (UI/Widgets.lua, UI/Chrome.lua) and Kahoof (UI/Theme.lua):
--   * every slider is UI.Slider, on MinimalSliderWithSteppersTemplate (the modern settings
--     slider; never OptionsSliderTemplate), label + default above, value right, Reset button
--   * dropdowns are WowStyle1DropdownTemplate + SetupMenu (SetupMenu runs its function at once)
--   * the Forever look: wood background tiled on the window's Bg, soft glow on panels
-- Public: UI.ART, UI.Wood(f), UI.Glow(host, region), UI.Header(parent, text), UI.Label(...),
--         UI.Button(parent, text, w, onClick), UI.Check(parent, o), UI.Slider(parent, width, o),
--         UI.Dropdown(parent, width, o), UI.Confirm(text, onAccept), UI.SLIDER_H,
--         UI.IconButton(parent, size, symbol, o), UI.Copy(title, text, anchor),
--         UI.ScopeDropdown(parent, width, o), UI.ScopeText(scope, style), UI.ScopeIsGlobal(scope, style),
--         UI.DeepCopy(t), UI.CharColored(guid), UI.scopeClip, UI.Gradient(tex, orient, a, b),
--         UI.Border(f, r, g, b, a), UI.RoundBox(f, o), UI.AutoHideScroll(box, bar), UI.ClearX(parent, size, onClick, tip),
--         UI.SearchBox(parent, width, o), UI.HelpIcon(parent, topic, title, text), UI.Segmented(parent, width, o), UI.LightSlider(parent, width, o)
local ADDON, ns = ...
local UI = {}
ns.UI = UI

UI.ART = "Interface\\AddOns\\Duskfall\\Assets\\"
UI.SLIDER_H = 40
UI.DROPDOWN_H = 44

-- Forever look ---------------------------------------------------------------------------------
function UI.Wood(f)
  local bg = f.Bg
  if not bg then
    bg = f:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints(f)
  end
  bg:SetTexture(UI.ART .. "wood", "REPEAT", "REPEAT")
  bg:SetHorizTile(true)
  bg:SetVertTile(true)
  return bg
end

-- Soft glow that lifts a panel off the wood. Top of BACKGROUND, under everything else.
function UI.Glow(host, region, alpha)
  local glow = host:CreateTexture(nil, "BACKGROUND", nil, 7)
  glow:SetAllPoints(region or host)
  glow:SetTexture(UI.ART .. "glow")
  if alpha then glow:SetAlpha(alpha) end
  return glow
end

-- Text -----------------------------------------------------------------------------------------
function UI.Header(parent, text)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetText(text)
  fs:SetJustifyH("LEFT")
  return fs
end

function UI.Label(parent, text, font)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  fs:SetText(text or "")
  fs:SetJustifyH("LEFT")
  return fs
end

local function tooltip(frame, title, tip)
  if not title and not tip then return end
  frame:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if title then GameTooltip:AddLine(title, 1, 1, 1) end
    if tip then GameTooltip:AddLine(tip, 0.8, 0.8, 0.8, true) end
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end
UI.Tooltip = tooltip

-- Button ---------------------------------------------------------------------------------------
-- SharedButtonTemplate is the current Blizzard button: red with bronze edges on Forever and sharp
-- at any size; UIPanelButtonTemplate (the old low-res grey-edged one) only where it is missing (BNB).
local buttonTemplate
function UI.Button(parent, text, w, onClick, h)
  if not buttonTemplate then
    buttonTemplate = (C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("SharedButtonTemplate"))
      and "SharedButtonTemplate" or "UIPanelButtonTemplate"
  end
  local b = CreateFrame("Button", nil, parent, buttonTemplate)
  b:SetSize(w or 120, h or 22)
  b:SetText(text)
  if onClick then b:SetScript("OnClick", function(self) ns.Safe(onClick, "button", self) end) end
  return b
end

-- Checkbox -------------------------------------------------------------------------------------
-- o = { label, tip, get = fn() -> bool, set = fn(bool) }. Returns the button; :Refresh().
function UI.Check(parent, o)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(26, 26)
  local text = cb.Text or cb.text
  if not text then
    text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  end
  text:SetText(o.label or "")
  cb:SetScript("OnClick", function(self) ns.Safe(o.set, "check", self:GetChecked() and true or false) end)
  tooltip(cb, o.label, o.tip)
  function cb:Refresh() self:SetChecked(o.get() and true or false) end
  cb:Refresh()
  return cb
end

-- Slider ---------------------------------------------------------------------------------------
--   Label  Default: 0.5 s                          0.5 s
--   <----------------|---------------->  [ Reset ]
-- o = { label, min, max, step, value | get, default, fmt = fn(v) -> text, onChange(v), tip }
-- No mouse wheel (it scrolls the page, as in BNB). Returns a holder: :SetValue(v, silent),
-- :GetValue(), :SetEnabled(on), :Refresh() (reads o.get).
local function noWheel(frame)
  pcall(frame.EnableMouseWheel, frame, false)
  if frame.HasScript and frame:HasScript("OnMouseWheel") then pcall(frame.SetScript, frame, "OnMouseWheel", nil) end
  for _, child in ipairs({ frame:GetChildren() }) do noWheel(child) end
end

function UI.Slider(parent, width, o)
  local step = o.step or 1
  local fmt = o.fmt or function(v)
    if step < 1 then return string.format("%.2f", v) end
    return tostring(v)
  end
  local function snap(v)
    v = math.max(o.min, math.min(o.max, tonumber(v) or o.min))
    if step == 1 then return math.floor(v + 0.5) end
    return o.min + math.floor((v - o.min) / step + 0.5) * step
  end
  local function same(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < step / 2 end

  local h = CreateFrame("Frame", nil, parent)
  h:SetSize(width, UI.SLIDER_H)

  local val = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  val:SetPoint("TOPRIGHT", h, "TOPRIGHT", 0, 0)
  val:SetJustifyH("RIGHT")

  local lbl = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  lbl:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)
  lbl:SetPoint("RIGHT", val, "LEFT", -8, 0)
  lbl:SetJustifyH("LEFT")
  lbl:SetWordWrap(false)
  local text = o.label or ""
  if o.default ~= nil then text = text .. "  |cff888888Default: " .. fmt(o.default) .. "|r" end
  lbl:SetText(text)

  local reset = UI.Button(h, "Reset", 52, nil, 20)
  reset:SetPoint("TOPRIGHT", h, "TOPRIGHT", 0, -16)

  local sl = CreateFrame("Slider", nil, h, "MinimalSliderWithSteppersTemplate")
  sl:SetPoint("TOPLEFT", h, "TOPLEFT", 0, -16)
  sl:SetPoint("RIGHT", reset, "LEFT", -6, 0)
  sl:SetHeight(20)
  local cur = snap(o.get and o.get() or o.value)
  sl:Init(cur, o.min, o.max, math.floor((o.max - o.min) / step + 0.5))
  noWheel(sl)

  local enabled, muted = true, false
  local function sync()
    val:SetText(fmt(cur))
    local atDef = o.default == nil or same(cur, o.default)
    reset:SetEnabled(enabled and not atDef)
  end
  sl:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, v)
    local n = snap(v)
    if same(n, cur) then return end
    cur = n
    sync()
    if o.onChange and not muted then ns.Safe(o.onChange, "slider", n) end
  end)

  local function setValue(v, silent)
    muted = silent and true or false
    sl:SetValue(snap(v))
    muted = false
    cur = snap(v)
    sync()
  end
  reset:SetScript("OnClick", function() if o.default ~= nil then setValue(o.default) end end)
  if o.tip then
    local hot = CreateFrame("Frame", nil, h)
    hot:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)
    hot:SetPoint("BOTTOMRIGHT", h, "TOPRIGHT", 0, -14)
    hot:EnableMouse(true)
    tooltip(hot, o.label, o.tip)
  end

  h._slider = sl
  function h:SetValue(v, silent) setValue(v, silent) end
  function h:GetValue() return cur end
  function h:SetEnabled(on)
    enabled = on and true or false
    pcall(sl.SetEnabled, sl, enabled)
    sync()
  end
  function h:Refresh() if o.get then setValue(o.get(), true) end end
  sync()
  return h
end

-- Dropdown -------------------------------------------------------------------------------------
-- Label above, WowStyle1DropdownTemplate below.
-- o = { label, tip, items = { {value, text}, ... } or fn() -> items, get = fn() -> value,
--       set = fn(value) }. Returns a holder: :Refresh().
function UI.Dropdown(parent, width, o)
  local h = CreateFrame("Frame", nil, parent)
  h:SetSize(width, UI.DROPDOWN_H)
  local lbl = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  lbl:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)
  lbl:SetText(o.label or "")
  local dd = CreateFrame("DropdownButton", nil, h, "WowStyle1DropdownTemplate")
  dd:SetPoint("TOPLEFT", h, "TOPLEFT", 0, -16)
  dd:SetWidth(width)
  tooltip(dd, o.label, o.tip)
  local function items()
    if type(o.items) == "function" then return o.items() end
    return o.items
  end
  local function build()
    dd:SetupMenu(function(_, root)
      for _, it in ipairs(items()) do
        root:CreateRadio(it[2],
          function(v) return o.get() == v end,
          function(v) ns.Safe(o.set, "dropdown", v) end,
          it[1])
      end
    end)
  end
  h._dd = dd
  function h:Refresh()
    build()
    if dd.GenerateMenu then pcall(dd.GenerateMenu, dd) end
  end
  build()
  return h
end

-- Scope dropdown -------------------------------------------------------------------------------
-- Multi-select: Global, then every known character (class colours). Ticking a character unticks
-- Global; unticking the last one gives Global (a Look) or Unused (a Style, o.style). Below a
-- divider: Copy scope, Paste scope, then o.extra(root) adds more. Checkbox clicks answer
-- MenuResponse.Refresh so the menu stays open.
-- o = { get = fn() -> scope, set = fn(scope), style = bool, extra = fn(root), tip }. :Refresh().
function UI.DeepCopy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = UI.DeepCopy(v) end
  return out
end

function UI.CharColored(guid)
  local c = ns.db.chars[guid]
  local name = (c and c.name) or tostring(guid)
  local col = c and c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
  if col and col.colorStr then return "|c" .. col.colorStr .. name .. "|r" end
  return name
end

local function scopeChars(scope)
  if type(scope) == "table" and not scope.global and type(scope.chars) == "table" then return scope.chars end
  return nil
end

-- style: an empty character list means Unused, not Global.
function UI.ScopeIsGlobal(scope, style)
  if type(scope) ~= "table" or scope.global then return true end
  if style then return false end
  local chars = scopeChars(scope)
  return chars == nil or next(chars) == nil
end

function UI.ScopeText(scope, style)
  if UI.ScopeIsGlobal(scope, style) then return "Global" end
  local names = {}
  for guid in pairs(scopeChars(scope) or {}) do names[#names + 1] = ns.CharName(guid) end
  if #names == 0 then return "Unused" end
  table.sort(names)
  return table.concat(names, ", ")
end

function UI.ScopeDropdown(parent, width, o)
  local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
  dd:SetWidth(width)
  if o.tip then tooltip(dd, "Scope", o.tip) end
  local function refreshText() pcall(dd.OverrideText, dd, UI.ScopeText(o.get(), o.style)) end
  local function done(sc)
    ns.Safe(o.set, "scope", sc)
    refreshText()
    return MenuResponse and MenuResponse.Refresh
  end
  dd:SetupMenu(function(_, root)
    root:CreateCheckbox("Global", function() return UI.ScopeIsGlobal(o.get(), o.style) end, function()
      if UI.ScopeIsGlobal(o.get(), o.style) then
        if o.style then return done({ chars = {} }) end
        return MenuResponse and MenuResponse.Refresh
      end
      return done({ global = true })
    end)
    local list = {}
    for guid, c in pairs(ns.db.chars) do list[#list + 1] = { guid = guid, name = c.name or "" } end
    table.sort(list, function(a, b) return a.name < b.name end)
    for _, e in ipairs(list) do
      root:CreateCheckbox(UI.CharColored(e.guid), function()
        local chars = scopeChars(o.get())
        return chars ~= nil and chars[e.guid] == true
      end, function()
        local chars = {}
        for g in pairs(scopeChars(o.get()) or {}) do chars[g] = true end
        if chars[e.guid] then chars[e.guid] = nil else chars[e.guid] = true end
        if next(chars) == nil and not o.style then return done({ global = true }) end
        return done({ chars = chars })
      end)
    end
    root:CreateDivider()
    root:CreateButton("Copy scope", function() UI.scopeClip = UI.DeepCopy(o.get() or { global = true }) end)
    local paste = root:CreateButton("Paste scope", function()
      if not UI.scopeClip then return end
      local sc = UI.DeepCopy(UI.scopeClip)
      if not o.style and UI.ScopeIsGlobal(sc) then sc = { global = true } end
      done(sc)
    end)
    if not UI.scopeClip and paste and paste.SetEnabled then pcall(paste.SetEnabled, paste, false) end
    if o.extra then o.extra(root) end
  end)
  function dd:Refresh()
    if self.GenerateMenu then pcall(self.GenerateMenu, self) end
    refreshText()
  end
  refreshText()
  return dd
end

-- Icon button ----------------------------------------------------------------------------------
-- BigNoteBox's layered icon button (UI/IconButton.lua), normal look only: background, plate,
-- hover, symbol, Forever border; the pressed symbol is its own drawing. Art in Assets:
-- bt-background, bt-button, bt-button-pressed, bt-hover, bt-border-forever, bt-<symbol>-normal/-press.
-- o = { onClick, tip, tipSub }. The button owns its mouse scripts; add behaviour with HookScript.
function UI.IconButton(parent, size, symbol, o)
  o = o or {}
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(size, size)
  local function layer(sub, file)
    local t = btn:CreateTexture(nil, "ARTWORK", nil, sub)
    t:SetAllPoints()
    if file then t:SetTexture(UI.ART .. file) end
    return t
  end
  local bg = layer(0, "bt-background")
  local plate = layer(1)
  local hover = layer(2, "bt-hover")
  local sym = layer(3)
  local border = layer(4, "bt-border-forever")
  local over, down = false, false
  local function refresh()
    local dim = not btn:IsEnabled()
    local pressed = down and not dim
    plate:SetTexture(UI.ART .. (pressed and "bt-button-pressed" or "bt-button"))
    sym:SetTexture(UI.ART .. "bt-" .. symbol .. (pressed and "-press" or "-normal"))
    hover:SetShown(over and not pressed and not dim)
    local d, ds = 1, 1
    if dim then d, ds = 0.6, 0.35 end
    for _, t in ipairs({ bg, plate, hover, border }) do
      t:SetDesaturated(dim)
      t:SetVertexColor(d, d, d)
    end
    sym:SetDesaturated(dim)
    sym:SetVertexColor(ds, ds, ds)
  end
  if o.onClick then btn:SetScript("OnClick", function(self, mb) ns.Safe(o.onClick, "icon button", self, mb) end) end
  btn:SetScript("OnEnter", function(self)
    over = true
    refresh()
    if o.tip then
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:AddLine(o.tip, 1, 1, 1)
      if o.tipSub then GameTooltip:AddLine(o.tipSub, 0.78, 0.78, 0.78, true) end
      GameTooltip:Show()
    end
  end)
  btn:SetScript("OnLeave", function(self)
    over, down = false, false
    refresh()
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
  end)
  btn:SetScript("OnMouseDown", function() down = true refresh() end)
  btn:SetScript("OnMouseUp", function() down = false refresh() end)
  btn:SetScript("OnEnable", refresh)
  btn:SetScript("OnDisable", refresh)
  btn:HookScript("OnHide", function() over, down = false, false refresh() end)
  refresh()
  return btn
end

-- Gradient and border --------------------------------------------------------------------------
-- A plain texture shaded from colour a to colour b ({ r, g, b, a }). "HORIZONTAL": a = left,
-- b = right; "VERTICAL": a = bottom, b = top. The modern form takes ColorMixins; older clients
-- had SetGradientAlpha with numbers. file: shade a white texture (a round corner) instead of a plain one.
function UI.Gradient(tex, orient, a, b, file)
  if file then tex:SetTexture(file) else tex:SetColorTexture(1, 1, 1, 1) end
  local ok = CreateColor and pcall(tex.SetGradient, tex, orient,
    CreateColor(a[1], a[2], a[3], a[4] or 1), CreateColor(b[1], b[2], b[3], b[4] or 1))
  if not ok and tex.SetGradientAlpha then
    pcall(tex.SetGradientAlpha, tex, orient, a[1], a[2], a[3], a[4] or 1, b[1], b[2], b[3], b[4] or 1)
  end
end

-- A 1 px frame around f, in its own colour.
function UI.Border(f, r, g, b, a)
  local function line()
    local t = f:CreateTexture(nil, "BORDER", nil, 7)
    t:SetColorTexture(r, g, b, a or 1)
    return t
  end
  local top, bottom, left, right = line(), line(), line(), line()
  top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  top:SetHeight(1)
  bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(1)
  left:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  left:SetWidth(1)
  right:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  right:SetWidth(1)
end

-- Rounded box ----------------------------------------------------------------------------------
-- A rectangle with rounded corners (Assets/round-corner, a quarter disc), shaded from o.bottom to
-- o.top, with an optional 1 px rounded frame (o.border, Assets/round-ring; for boxes rounded on all
-- four corners). Corners can be square: :SetCorners(tl, tr, bl, br).
-- o = { radius, bottom = {r,g,b,a}, top = {r,g,b,a}, border = {r,g,b,a}, layer, sub }.
-- Returns a box with :SetCorners(...), :SetShown(on), :Layout() (also on the frame's size change).
local CORNERS = { tl = { 0, 1, 0, 1 }, tr = { 1, 0, 0, 1 }, bl = { 0, 1, 1, 0 }, br = { 1, 0, 1, 0 } }
local CORNER_POINT = { tl = "TOPLEFT", tr = "TOPRIGHT", bl = "BOTTOMLEFT", br = "BOTTOMRIGHT" }
local function lerp(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t,
           (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * t }
end

function UI.RoundBox(f, o)
  local R = o.radius or 6     -- 6, 7, 8, 10 or 12 with a border (Assets/round-ring-<R>)
  local layer, sub = o.layer or "BACKGROUND", o.sub or 1
  local box = { round = { tl = true, tr = true, bl = true, br = true } }
  local all = {}
  local function tex(level)
    local t = f:CreateTexture(nil, layer, nil, level)
    all[#all + 1] = t
    return t
  end
  local c = {}
  for k, point in pairs(CORNER_POINT) do
    c[k] = tex(sub)
    c[k]:SetSize(R, R)
    c[k]:SetPoint(point, f, point, 0, 0)
  end
  local top, mid, bot = tex(sub), tex(sub), tex(sub)
  top:SetPoint("TOPLEFT", c.tl, "TOPRIGHT")
  top:SetPoint("BOTTOMRIGHT", c.tr, "BOTTOMLEFT")
  mid:SetPoint("TOPLEFT", c.tl, "BOTTOMLEFT")
  mid:SetPoint("BOTTOMRIGHT", c.br, "TOPRIGHT")
  bot:SetPoint("TOPLEFT", c.bl, "TOPRIGHT")
  bot:SetPoint("BOTTOMRIGHT", c.br, "BOTTOMLEFT")

  if o.border then
    local col = o.border
    local function solid()
      local t = tex(sub + 1)
      t:SetColorTexture(col[1], col[2], col[3], col[4] or 1)
      return t
    end
    for k, point in pairs(CORNER_POINT) do
      local t = tex(sub + 1)
      t:SetSize(R, R)
      t:SetPoint(point, f, point, 0, 0)
      t:SetTexture(UI.ART .. "round-ring-" .. R)
      t:SetTexCoord(unpack(CORNERS[k]))
      t:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
    end
    local tl = solid()
    tl:SetPoint("TOPLEFT", f, "TOPLEFT", R, 0)
    tl:SetPoint("TOPRIGHT", f, "TOPRIGHT", -R, 0)
    tl:SetHeight(1)
    local bl = solid()
    bl:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", R, 0)
    bl:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -R, 0)
    bl:SetHeight(1)
    local ll = solid()
    ll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -R)
    ll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, R)
    ll:SetWidth(1)
    local rl = solid()
    rl:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -R)
    rl:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, R)
    rl:SetWidth(1)
  end

  -- The fill is shaded per piece, each with its own slice of the bottom-to-top gradient
  function box:Layout()
    local H = f:GetHeight()
    if not H or H < 2 * R then H = 2 * R end
    local a, b = R / H, (H - R) / H
    local lo, hi = o.bottom, o.top or o.bottom
    local function shade(t, from, to, file)
      UI.Gradient(t, "VERTICAL", lerp(lo, hi, from), lerp(lo, hi, to), file)
    end
    for k, t in pairs(c) do
      local file = box.round[k] and (UI.ART .. "round-corner") or nil
      if k == "tl" or k == "tr" then shade(t, b, 1, file) else shade(t, 0, a, file) end
      if file then t:SetTexCoord(unpack(CORNERS[k])) else t:SetTexCoord(0, 1, 0, 1) end
    end
    shade(top, b, 1)
    shade(mid, a, b)
    shade(bot, 0, a)
  end
  function box:SetCorners(tl, tr, bl, br)
    box.round = { tl = tl and true or false, tr = tr and true or false, bl = bl and true or false, br = br and true or false }
    box:Layout()
  end
  function box:SetShown(on)
    for _, t in ipairs(all) do t:SetShown(on) end
  end
  f:HookScript("OnSizeChanged", function() box:Layout() end)
  box:Layout()
  return box
end

-- Segmented control ----------------------------------------------------------------------------
--   [ Canals | Undercity | Everywhere ]
-- A row of joined buttons, one of them picked (as macOS). Widths follow the texts.
-- o = { items = fn() -> { { value, text, icon, tip }, ... }, get = fn() -> value, set = fn(value),
--       height }. Returns a frame with :Refresh() (reads items and value again), :SetEnabled(on).
function UI.Segmented(parent, width, o)
  local H = o.height or 24
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, H)
  UI.RoundBox(f, { radius = 7, sub = 2, bottom = { 0, 0, 0, 0.6 }, top = { 0.14, 0.11, 0.07, 0.6 },
    border = { 1, 0.82, 0, 0.35 } })
  local buttons, items = {}, {}
  local enabled = true

  local function button(i)
    local b = CreateFrame("Button", nil, f)
    -- The picked look, inside the frame line; only the outer ends of the row are rounded
    local inner = CreateFrame("Frame", nil, b)
    inner:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.pick = UI.RoundBox(inner, { radius = 6, sub = 4, bottom = { 0.5, 0.33, 0.05, 0.95 }, top = { 0.93, 0.72, 0.24, 0.95 } })
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    b.sep = b:CreateTexture(nil, "BORDER")
    b.sep:SetColorTexture(1, 0.82, 0, 0.3)
    b.sep:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -3)
    b.sep:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 3)
    b.sep:SetWidth(1)
    local top = CreateFrame("Frame", nil, b)
    top:SetAllPoints(b)
    top:SetFrameLevel(inner:GetFrameLevel() + 2)
    b.text = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetWordWrap(false)
    b.icon = top:CreateTexture(nil, "OVERLAY")
    b.icon:SetSize(14, 14)
    b.icon:SetPoint("RIGHT", b.text, "LEFT", -3, 0)
    b:SetScript("OnClick", function(self)
      local it = items[self.index]
      if it and it[1] ~= o.get() then ns.Safe(o.set, "segment", it[1]) end
      f:Refresh()
    end)
    b:SetScript("OnEnter", function(self)
      local it = items[self.index]
      if not it or not it[4] then return end
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:AddLine(it[2], 1, 1, 1)
      GameTooltip:AddLine(it[4], 0.8, 0.8, 0.8, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    buttons[i] = b
    return b
  end

  function f:Refresh()
    items = o.items() or {}
    local cur = o.get()
    local need, total = {}, 0
    for i, it in ipairs(items) do
      local b = buttons[i] or button(i)
      b.index = i
      b.text:SetText(it[2])
      need[i] = b.text:GetStringWidth() + 22 + (it[3] and 17 or 0)
      total = total + need[i]
    end
    local x = 0
    for i, it in ipairs(items) do
      local b = buttons[i]
      local w = math.floor(need[i] * width / math.max(1, total) + 0.5)
      if i == #items then w = width - x end
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0)
      b:SetSize(w, H)
      x = x + w
      -- No divider next to the picked choice: its gold edge is the divider (Kim)
      local prevPicked = i > 1 and items[i - 1][1] == cur
      b.sep:SetShown(i > 1 and it[1] ~= cur and not prevPicked)
      b.icon:SetShown(it[3] ~= nil)
      if it[3] then b.icon:SetTexture(it[3]) end
      b.text:ClearAllPoints()
      b.text:SetPoint("CENTER", b, "CENTER", it[3] and 8 or 0, 0)
      b.text:SetWidth(math.max(10, w - 10 - (it[3] and 17 or 0)))
      local on = it[1] == cur
      local first, last = i == 1, i == #items
      b.pick:SetCorners(first, last, first, last)
      b.pick:SetShown(on)
      -- Dark on the gold, without the drop shadow (it smeared the letters, Kim)
      if on then
        b.text:SetTextColor(0.14, 0.08, 0)
        b.text:SetShadowOffset(0, 0)
      else
        b.text:SetTextColor(1, 0.82, 0)
        b.text:SetShadowOffset(1, -1)
      end
      b:SetEnabled(enabled)
      b:Show()
    end
    for i = #items + 1, #buttons do buttons[i]:Hide() end
    f:SetAlpha(enabled and 1 or 0.4)
  end
  function f:SetEnabled(on)
    enabled = on and true or false
    f:Refresh()
  end
  return f
end

-- Light slider ---------------------------------------------------------------------------------
--   Gamma      [ dark ======|=====O====== light ]    +0.10
-- Simple mode's slider: the track is a gradient (what the value does to the picture), the mark in
-- the middle is 0 ("no change"), a gold line under the track runs from the mark to the thumb.
-- Right-click puts it back to 0. The range should be symmetric around 0.
-- o = { label, min, max, step, from = { r, g, b }, to = { r, g, b }, get = fn() -> v,
--       set = fn(v), fmt = fn(v) -> text, tip, lineH = height of the middle mark (the row
--       spacing joins stacked sliders' marks into one line) }. :Refresh(), :SetEnabled(on).
function UI.LightSlider(parent, width, o)
  local LABEL_W, VALUE_W, H = 84, 96, 30
  local INSET   -- half the thumb width, set once the thumb is known
  local h = CreateFrame("Frame", nil, parent)
  h:SetSize(width, H)
  local lbl = UI.Label(h, o.label, "GameFontNormal")
  lbl:SetPoint("LEFT", h, "LEFT", 0, 0)
  lbl:SetWidth(LABEL_W)
  local val = UI.Label(h, "", "GameFontHighlight")
  val:SetPoint("RIGHT", h, "RIGHT", 0, 0)
  val:SetWidth(VALUE_W)
  val:SetJustifyH("LEFT")   -- right next to the track, so the track can be long (Kim)
  if o.tip then
    local hot = CreateFrame("Frame", nil, h)
    hot:SetPoint("LEFT", h, "LEFT", 0, 0)
    hot:SetSize(LABEL_W, H)
    hot:EnableMouse(true)
    tooltip(hot, o.label, o.tip .. "\n\nRight-click the slider: back to no change.")
  end

  local sl = CreateFrame("Slider", nil, h)
  sl:SetPoint("LEFT", h, "LEFT", LABEL_W - 6, 0)
  sl:SetPoint("RIGHT", h, "RIGHT", -VALUE_W + 2, 0)
  sl:SetHeight(H)
  sl:SetOrientation("HORIZONTAL")
  sl:SetMinMaxValues(o.min, o.max)
  sl:SetValueStep(o.step)
  pcall(sl.SetObeyStepOnDrag, sl, true)
  sl:EnableMouse(true)
  pcall(sl.EnableMouseWheel, sl, false)
  -- Duskfall's own gold diamond (Assets/diamond: gem facets lit from the top left). The slider
  -- moves its thumb to a layer of its choosing, so the layer is set again afterwards: on top of
  -- the middle line (Kim)
  local thumb = sl:CreateTexture(nil, "OVERLAY", nil, 7)
  thumb:SetTexture(UI.ART .. "diamond")
  thumb:SetSize(22, 22)
  sl:SetThumbTexture(thumb)
  thumb:SetDrawLayer("OVERLAY", 7)
  -- The thumb's centre travels from half its width to the other end minus that: the track too
  INSET = 11

  local well = sl:CreateTexture(nil, "BACKGROUND")
  well:SetPoint("LEFT", sl, "LEFT", INSET - 2, 0)
  well:SetPoint("RIGHT", sl, "RIGHT", -INSET + 2, 0)
  well:SetHeight(12)
  well:SetColorTexture(0, 0, 0, 0.85)
  local track = sl:CreateTexture(nil, "ARTWORK")
  track:SetPoint("LEFT", sl, "LEFT", INSET, 0)
  track:SetPoint("RIGHT", sl, "RIGHT", -INSET, 0)
  track:SetHeight(8)
  UI.Gradient(track, "HORIZONTAL", o.from, o.to)
  local shine = sl:CreateTexture(nil, "ARTWORK", nil, 2)
  shine:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
  shine:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, 0)
  shine:SetHeight(4)
  UI.Gradient(shine, "VERTICAL", { 1, 1, 1, 0 }, { 1, 1, 1, 0.3 })
  local mark = sl:CreateTexture(nil, "ARTWORK", nil, 5)
  mark:SetColorTexture(1, 0.86, 0.55, 0.4)
  mark:SetSize(2, o.lineH or 16)
  local fill = sl:CreateTexture(nil, "ARTWORK", nil, 3)
  fill:SetColorTexture(1, 0.82, 0, 0.95)
  fill:SetHeight(2)

  local cur, muted = 0, false
  local function snap(v) return math.floor(v / o.step + 0.5) * o.step end
  local function xOf(v)
    local w = sl:GetWidth() - 2 * INSET
    return INSET + (v - o.min) / (o.max - o.min) * w
  end
  local function show()
    if math.abs(cur) < o.step / 2 then val:SetText(o.zero and o.zero() or "|cff9d9d9dNo change|r")
    else val:SetText(o.fmt and o.fmt(cur) or tostring(cur)) end
    local x0, x1 = xOf(0), xOf(cur)
    mark:ClearAllPoints()
    mark:SetPoint("CENTER", sl, "LEFT", x0, 0)
    fill:ClearAllPoints()
    if math.abs(x1 - x0) < 1 then
      fill:Hide()
    else
      fill:SetPoint("TOPLEFT", sl, "LEFT", math.min(x0, x1), -6)
      fill:SetWidth(math.abs(x1 - x0))
      fill:Show()
    end
  end
  sl:SetScript("OnValueChanged", function(_, v)
    v = snap(v)
    if math.abs(v - cur) < o.step / 2 then return end
    cur = v
    show()
    if not muted then ns.Safe(o.set, "slider", v) end
  end)
  sl:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" and self:IsEnabled() then self:SetValue(0) end
  end)
  sl:SetScript("OnSizeChanged", show)

  function h:Refresh()
    local v = tonumber(o.get()) or 0
    muted = true
    sl:SetValue(v)
    muted = false
    cur = v
    show()
  end
  function h:SetEnabled(on)
    pcall(sl.SetEnabled, sl, on and true or false)
    sl:EnableMouse(on and true or false)
    h:SetAlpha(on and 1 or 0.45)
  end
  h:Refresh()
  return h
end

-- Clear X, search box, help icon ----------------------------------------------------------------
-- BigNoteBox's round clear X (Dukul's art, Assets/clear-x): coloured, never tinted; pressed =
-- dimmed and 1 px down-right.
function UI.ClearX(parent, size, onClick, tip)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(size, size)
  local tx = btn:CreateTexture(nil, "ARTWORK")
  tx:SetSize(size, size)
  tx:SetPoint("CENTER")
  tx:SetTexture(UI.ART .. "clear-x")
  local hi = btn:CreateTexture(nil, "HIGHLIGHT")
  hi:SetAllPoints(tx)
  hi:SetTexture(UI.ART .. "clear-x")
  hi:SetBlendMode("ADD")
  hi:SetAlpha(0.25)
  local function look(down)
    tx:SetPoint("CENTER", down and 1 or 0, down and -1 or 0)
    tx:SetAlpha(down and 0.5 or 1)
  end
  btn:HookScript("OnMouseDown", function() look(true) end)
  btn:HookScript("OnMouseUp", function() look(false) end)
  btn:HookScript("OnHide", function() look(false) end)
  btn:HookScript("OnLeave", function(self)
    look(false)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
  end)
  if tip then
    btn:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(tip, 1, 1, 1)
      GameTooltip:Show()
    end)
  end
  if onClick then btn:SetScript("OnClick", onClick) end
  return btn
end

-- A search box: grey placeholder while empty, the clear X only once something is typed.
-- o = { placeholder, onChange = fn(text) }. Returns the edit box (:GetText, :SetText).
function UI.SearchBox(parent, width, o)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetSize(width - 6, 22)
  eb:SetAutoFocus(false)
  eb:SetTextInsets(0, 22, 0, 0)
  local ph = eb:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  ph:SetPoint("LEFT", eb, "LEFT", 0, 0)
  ph:SetText(o.placeholder or "Search")
  local x = UI.ClearX(eb, 16, function()
    eb:SetText("")
    eb:ClearFocus()
  end, "Clear")
  x:SetPoint("RIGHT", eb, "RIGHT", -2, 0)
  x:Hide()
  local function sync()
    local t = eb:GetText() or ""
    x:SetShown(t ~= "")
    ph:SetShown(t == "" and not eb:HasFocus())
  end
  eb:SetScript("OnTextChanged", function(self)
    sync()
    if o.onChange then ns.Safe(o.onChange, "search", self:GetText() or "") end
  end)
  eb:SetScript("OnEditFocusGained", sync)
  eb:SetScript("OnEditFocusLost", sync)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  sync()
  return eb
end

-- A small, quiet "?" next to a feature: faint until hovered, a tooltip on hover, and a click
-- opens that topic in Help (ns.Help.Open).
function UI.HelpIcon(parent, topic, title, text)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(16, 16)
  b:SetNormalTexture(UI.ART .. "help-normal")
  b:SetHighlightTexture(UI.ART .. "help-hover")
  b:SetPushedTexture(UI.ART .. "help-press")
  b:SetAlpha(0.35)
  b:SetScript("OnEnter", function(self)
    self:SetAlpha(1)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title, 1, 1, 1)
    if text then GameTooltip:AddLine(text, 0.8, 0.8, 0.8, true) end
    GameTooltip:AddLine("Click: more in Help.", 0.62, 0.71, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self)
    self:SetAlpha(0.35)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
  end)
  b:SetScript("OnClick", function() if ns.Help then ns.Help.Open(topic) end end)
  return b
end

-- Scroll bars ----------------------------------------------------------------------------------
-- A list's scroll bar shows only when there is something to scroll (Kim).
function UI.AutoHideScroll(box, bar)
  if ScrollUtil and ScrollUtil.AddManagedScrollBarVisibilityBehavior then
    pcall(ScrollUtil.AddManagedScrollBarVisibilityBehavior, box, bar)
  end
end

-- Copy box -------------------------------------------------------------------------------------
-- Addons cannot write the clipboard (C_System.SetClipboard is nil on Forever): BigNoteBox's way.
-- The text sits selected in a hidden edit box with the keyboard focus, and a small box near the
-- button (or the pointer) says "Press Ctrl+C to copy". Ctrl+C copies and closes it, Esc or a click
-- closes it. The box is TOOLTIP strata and must never take the keyboard itself, or Ctrl+C would
-- go to it instead of the edit box (BNB). It closes with the frame it is anchored to.
-- UI.Copy(title, text, anchor): title is shown as the preview's label.
local copyHelper, copyHint

local function propagate(f, on)
  if InCombatLockdown() then return end
  pcall(f.SetPropagateKeyboardInput, f, on)
end

local function buildCopy()
  copyHelper = CreateFrame("EditBox", nil, UIParent)
  copyHelper:SetSize(1, 1)
  copyHelper:SetAlpha(0)
  copyHelper:SetPoint("CENTER")
  copyHelper:SetAutoFocus(false)
  copyHelper:SetMultiLine(true)
  copyHelper:SetMaxLetters(0)
  copyHelper:Hide()

  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("TOOLTIP")
  f:SetFrameLevel(200)
  f:SetSize(260, 64)
  f:Hide()
  UI.RoundBox(f, { radius = 10, bottom = { 0.04, 0.03, 0.02, 0.97 }, top = { 0.14, 0.11, 0.07, 0.97 },
    border = { 1, 0.82, 0, 0.45 } })
  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetSize(24, 24)
  icon:SetPoint("LEFT", f, "LEFT", 12, 8)
  if not pcall(icon.SetAtlas, icon, "groupfinder-icon-keyboard", true) then icon:Hide() end
  local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lbl:SetPoint("TOPLEFT", f, "TOPLEFT", 46, -10)
  lbl:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  lbl:SetJustifyH("LEFT")
  lbl:SetText("Press |cff66bb6aCtrl+C|r to copy")
  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -3)
  sub:SetTextColor(0.55, 0.55, 0.55)
  sub:SetText("Press Esc to cancel")
  local prev = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  prev:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -4)
  prev:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  prev:SetJustifyH("LEFT")
  prev:SetWordWrap(false)
  prev:SetTextColor(0.78, 0.78, 0.78)
  f.preview = prev

  -- Breathes gently so it is seen
  local ag = f:CreateAnimationGroup()
  ag:SetLooping("REPEAT")
  local a1 = ag:CreateAnimation("Alpha")
  a1:SetFromAlpha(1)
  a1:SetToAlpha(0.8)
  a1:SetDuration(0.7)
  a1:SetSmoothing("IN_OUT")
  a1:SetOrder(1)
  local a2 = ag:CreateAnimation("Alpha")
  a2:SetFromAlpha(0.8)
  a2:SetToAlpha(1)
  a2:SetDuration(0.7)
  a2:SetSmoothing("IN_OUT")
  a2:SetOrder(2)
  f.pulse = ag

  function f.Dismiss()
    f.pulse:Stop()
    f:Hide()
    copyHelper:ClearFocus()
    copyHelper:Hide()
  end
  f:SetScript("OnUpdate", function(self)
    if self.anchor and not self.anchor:IsVisible() then self.Dismiss() end
  end)
  f:EnableMouse(true)
  f:SetScript("OnMouseDown", function(self) self.Dismiss() end)

  copyHelper:SetScript("OnKeyDown", function(self, key)
    if key == "C" and IsControlKeyDown() then
      propagate(self, false)       -- the copy is done by the edit box; keep "C" from opening the character pane
      copyHint.Dismiss()
    elseif key == "ESCAPE" then
      propagate(self, false)
      copyHint.Dismiss()
    else
      propagate(self, true)
    end
  end)
  copyHelper:SetScript("OnEditFocusLost", function()
    if copyHint:IsShown() then copyHint.Dismiss() end
  end)
  copyHint = f
end

function UI.Copy(title, text, anchor)
  if not copyHelper then buildCopy() end
  copyHint.preview:SetText((title and (title .. ":  ") or "") .. "|cffffffff" .. tostring(text or ""):gsub("[\r\n]+", " ") .. "|r")
  copyHint:ClearAllPoints()
  copyHint.anchor = anchor
  if anchor then
    copyHint:SetPoint("TOP", anchor, "BOTTOM", 0, -6)
  else
    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    local w, h = copyHint:GetSize()
    local x, y = cx + 16, cy + 16
    if x + w > GetScreenWidth() then x = cx - w - 4 end
    if y + h > GetScreenHeight() then y = cy - h - 4 end
    copyHint:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
  end
  copyHelper:Show()
  copyHelper:SetText(tostring(text or ""))
  copyHint:Show()
  copyHint:Raise()
  copyHint.pulse:Play()
  -- A tick later: the click that opened it must not take the focus back
  C_Timer.After(0, function()
    if copyHint:IsShown() then
      copyHelper:SetFocus()
      copyHelper:HighlightText()
    end
  end)
end

-- Confirm popup --------------------------------------------------------------------------------
-- Esc and No do nothing (BNB lesson: a popup's cancel must never do the action).
StaticPopupDialogs["DUSKFALL_CONFIRM"] = {
  text = "%s",
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, data) if data then ns.Safe(data, "confirm") end end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  noCancelOnEscape = true,
  preferredIndex = 3,
}

function UI.Confirm(text, onAccept)
  StaticPopup_Show("DUSKFALL_CONFIRM", text, nil, onAccept)
end
