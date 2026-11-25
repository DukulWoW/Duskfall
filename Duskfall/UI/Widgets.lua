-- Duskfall UI/Widgets.lua: the building blocks of the settings window.
-- Patterns from BigNoteBox (UI/Widgets.lua, UI/Chrome.lua) and Kahoof (UI/Theme.lua):
--   * every slider is UI.Slider, on MinimalSliderWithSteppersTemplate (the modern settings
--     slider; never OptionsSliderTemplate), label + default above, value right, Reset button
--   * dropdowns are WowStyle1DropdownTemplate + SetupMenu (SetupMenu runs its function at once)
--   * the Forever look: wood background tiled on the window's Bg, soft glow on panels
-- Public: UI.ART, UI.Wood(f), UI.Glow(host, region), UI.Header(parent, text), UI.Label(...),
--         UI.Button(parent, text, w, onClick), UI.Check(parent, o), UI.Slider(parent, width, o),
--         UI.Dropdown(parent, width, o), UI.Confirm(text, onAccept), UI.SLIDER_H,
--         UI.IconButton(parent, size, symbol, o), UI.Copy(title, text)
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
function UI.Button(parent, text, w, onClick, h)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
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

-- Copy box -------------------------------------------------------------------------------------
-- Addons cannot write the clipboard (C_System.SetClipboard is nil on Forever, BNB): show the text
-- selected in a popup so Ctrl+C copies it.
StaticPopupDialogs["DUSKFALL_COPY"] = {
  text = "%s\n\nPress Ctrl+C to copy.",
  button1 = CLOSE or "Close",
  hasEditBox = true,
  editBoxWidth = 320,
  OnShow = function(self, data)
    local eb = self.editBox or self.EditBox
    if eb then
      eb:SetText(data or self.data or "")
      eb:HighlightText()
      eb:SetFocus()
    end
  end,
  EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
  EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

function UI.Copy(title, text)
  StaticPopup_Show("DUSKFALL_COPY", title, nil, text)
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
