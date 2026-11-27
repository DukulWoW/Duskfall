-- Duskfall UI/Widgets.lua: the building blocks of the settings window.
-- Patterns from BigNoteBox (UI/Widgets.lua, UI/Chrome.lua) and Kahoof (UI/Theme.lua):
--   * every slider is our own (UI.LightSlider: gradient track, gold diamond; Kim 2026-11-26);
--     UI.Slider puts a label + default above it, the value right and a Reset button
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
-- The icon's ring: gold at the top left, Duskfall blue at the bottom right (window frame, sweeps)
UI.RING_GOLD, UI.RING_BLUE = { 1, 0.85, 0.4 }, { 0.36, 0.5, 1 }

-- Forever look ---------------------------------------------------------------------------------
-- The window's background, tiled: Kim's slate (Assets/bg-slate, 2026-11-26, on trial; was "wood",
-- Kahoof's, still in Assets to go back)
UI.BACKGROUND = "bg-slate"
function UI.Wood(f)
  local bg = f.Bg
  if not bg then
    bg = f:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints(f)
  end
  bg:SetTexture(UI.ART .. UI.BACKGROUND, "REPEAT", "REPEAT")
  bg:SetHorizTile(true)
  bg:SetVertTile(true)
  bg:SetVertexColor(1, 1, 1, 1)
  return bg
end

-- Soft glow that lifted a panel off the wood. Off since the cursor light (Kim, 2026-11-26):
-- UI.GLOW = true brings it back everywhere. Returns the texture (hidden when off).
UI.GLOW = false
function UI.Glow(host, region, alpha)
  local glow = host:CreateTexture(nil, "BACKGROUND", nil, 7)
  glow:SetAllPoints(region or host)
  glow:SetTexture(UI.ART .. "glow")
  if alpha then glow:SetAlpha(alpha) end
  glow:SetShown(UI.GLOW)
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
-- Our own button (Kim, 2026-11-26: the red Blizzard ones looked borrowed): a rounded box like the
-- cards, dark and warm with a gold edge and gold text. Kinds (b:SetKind):
--   "normal"  as above
--   "main"    gold filled, dark text: the one main action on a page (Open Duskfall, Try it, Paste)
--   "danger"  dark with a faint red edge: Reset, Delete, Remove
-- Hover brightens it, pressing moves the text 1 px down-right, disabled greys it. :SetText,
-- :SetEnabled, :GetFontString work as on any button.
local BUTTON_LOOK = {
  normal = { bottom = { 0.09, 0.06, 0.03, 0.92 }, top = { 0.26, 0.19, 0.1, 0.92 }, border = { 1, 0.82, 0, 0.55 },
             text = { 1, 0.82, 0 }, shadow = true },
  main   = { bottom = { 0.5, 0.33, 0.05, 1 }, top = { 0.95, 0.75, 0.26, 1 }, border = { 1, 0.92, 0.55, 0.95 },
             text = { 0.14, 0.08, 0 }, shadow = false },
  danger = { bottom = { 0.1, 0.03, 0.02, 0.92 }, top = { 0.27, 0.09, 0.06, 0.92 }, border = { 0.95, 0.35, 0.22, 0.6 },
             text = { 1, 0.72, 0.55 }, shadow = true },
  -- Disabled, whatever the kind: grey (Kim: the beige disabled Paste didn't read as "not now")
  off    = { bottom = { 0.08, 0.08, 0.08, 0.85 }, top = { 0.18, 0.18, 0.18, 0.85 }, border = { 0.55, 0.55, 0.55, 0.4 },
             text = { 0.5, 0.5, 0.5 }, shadow = true },
}
-- Hover (Kim): the button fills, fading in over HOVER_FADE seconds, so it shows even under the cursor
-- light: normal fills gold, main gets brighter, danger fills red; the text turns to match.
local BUTTON_HOT = {
  normal = { bottom = { 0.55, 0.37, 0.06, 1 }, top = { 0.98, 0.79, 0.3, 1 }, border = { 1, 0.92, 0.55, 0.95 },
             text = { 0.14, 0.08, 0 } },
  main   = { bottom = { 0.72, 0.52, 0.12, 1 }, top = { 1, 0.9, 0.5, 1 }, border = { 1, 0.97, 0.75, 1 },
             text = { 0.14, 0.08, 0 } },
  danger = { bottom = { 0.4, 0.06, 0.03, 1 }, top = { 0.85, 0.24, 0.14, 1 }, border = { 1, 0.55, 0.4, 0.95 },
             text = { 1, 0.94, 0.88 } },
}
local HOVER_FADE = 0.15

function UI.Button(parent, text, w, onClick, h)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w or 120, h or 22)
  -- Drawn on the button itself (textures, not child frames), so the text is always on top
  local boxes, hots = {}, {}
  for k, L in pairs(BUTTON_LOOK) do
    boxes[k] = UI.RoundBox(b, { radius = 7, bottom = L.bottom, top = L.top, border = L.border })
    boxes[k]:SetShown(false)
  end
  for k, L in pairs(BUTTON_HOT) do
    hots[k] = UI.RoundBox(b, { radius = 7, sub = 3, unlit = true, bottom = L.bottom, top = L.top, border = L.border })
    hots[k]:SetShown(false)
  end
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("CENTER", b, "CENTER", 0, 0)
  fs:SetWordWrap(false)
  b:SetFontString(fs)
  b:SetPushedTextOffset(1, -1)
  local kind, heat, want = "normal", 0, 0
  local function paint()
    local on = b:IsEnabled()
    local L = BUTTON_LOOK[on and kind or "off"]
    local H = BUTTON_HOT[kind]
    for k, box in pairs(boxes) do box:SetShown(k == (on and kind or "off")) end
    for k, box in pairs(hots) do
      box:SetShown(on and k == kind and heat > 0)
      box:SetAlpha(heat)
    end
    local e = on and heat or 0
    local t1, t2 = L.text, H.text
    fs:SetTextColor(t1[1] + (t2[1] - t1[1]) * e, t1[2] + (t2[2] - t1[2]) * e, t1[3] + (t2[3] - t1[3]) * e)
    local shadow = L.shadow and e < 0.5
    fs:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
  end
  local function step(self, dt)
    if heat < want then heat = math.min(want, heat + dt / HOVER_FADE)
    elseif heat > want then heat = math.max(want, heat - dt / HOVER_FADE) end
    paint()
    if heat == want then self:SetScript("OnUpdate", nil) end
  end
  local function hover(on)
    want = (on and b:IsEnabled()) and 1 or 0
    if heat ~= want then b:SetScript("OnUpdate", step) end
  end
  function b:SetKind(k)
    kind = BUTTON_HOT[k] and k or "normal"
    paint()
  end
  b:SetScript("OnEnter", function() hover(true) end)
  b:SetScript("OnLeave", function() hover(false) end)
  b:SetScript("OnEnable", paint)
  b:SetScript("OnDisable", function(self)
    want, heat = 0, 0
    self:SetScript("OnUpdate", nil)
    paint()
  end)
  b:HookScript("OnHide", function(self)
    want, heat = 0, 0
    self:SetScript("OnUpdate", nil)
    paint()
  end)
  b:SetText(text)
  paint()
  if onClick then b:SetScript("OnClick", function(self) ns.Safe(onClick, "button", self) end) end
  return b
end

-- Glow ring ------------------------------------------------------------------------------------
-- The moon's glow (Kim): a sun glare (Interface/Glues/Models/UI_Tauren/UI_Goblin_Sunglare, file
-- 1063590, from the login screen) turning slowly and breathing slowly, fading in and out over
-- GLOW_FADE seconds. A soft gold disc (Assets/dot) where the image is missing. Its animation runs
-- only while it shows. Used by the moon badge, the minimap button (UI/Moon.lua M.AddRing) and the
-- big on / off switch. host: the frame it lives on (it draws under host's children); anchor:
-- the region it centres on; size: its width and height; o = { turn, breath } (radians a second).
-- Returns { Set(on) }.
local GLOW_FILE = 1063590
local GLOW_PATH = "Interface\\Glues\\Models\\UI_Tauren\\UI_Goblin_Sunglare"
local GLOW_TURN = 2 * math.pi / 60   -- one turn a minute
local GLOW_BREATH = 0.7              -- about 9 s a breath
local GLOW_FADE = 0.8

function UI.GlowRing(host, anchor, size, o)
  o = o or {}
  local glow = host:CreateTexture(nil, "ARTWORK", nil, -1)
  glow:SetSize(size, size)
  glow:SetPoint("CENTER", anchor, "CENTER")
  glow:SetBlendMode("ADD")
  glow:Hide()
  local ok = pcall(glow.SetTexture, glow, GLOW_FILE) and glow:GetTexture()
  if not ok then ok = pcall(glow.SetTexture, glow, GLOW_PATH) and glow:GetTexture() end
  if not ok then
    glow:SetTexture(UI.ART .. "dot")
    glow:SetVertexColor(1, 0.8, 0.35)
  end
  local turn, breath = o.turn or GLOW_TURN, o.breath or GLOW_BREATH
  local anim = CreateFrame("Frame", nil, host)
  local clock, level, want = 0, 0, 0
  anim:SetScript("OnUpdate", function(self, dt)
    clock = clock + dt
    if level < want then level = math.min(want, level + dt / GLOW_FADE)
    elseif level > want then level = math.max(want, level - dt / GLOW_FADE) end
    if level <= 0 and want == 0 then
      glow:Hide()
      self:Hide()
      return
    end
    glow:SetAlpha(level * (0.65 + 0.35 * math.sin(clock * breath)))
    pcall(glow.SetRotation, glow, clock * turn)
  end)
  anim:Hide()
  local r = {}
  function r.Set(on)
    want = on and 1 or 0
    if on then
      glow:SetAlpha(level * 0.65)
      glow:Show()
      anim:Show()
    elseif level > 0 then
      anim:Show()   -- fades out, then hides itself
    end
  end
  return r
end

-- Switch ---------------------------------------------------------------------------------------
-- An iOS-style on / off switch in place of every checkbox (Kim, 2026-11-26). A pill, a gold
-- gradient when on and Duskfall blue to dark blue when off, with a white knob that slides across
-- while the colours crossfade. o.big: larger, "On" / "Off" under the label and the moon's glow
-- behind it while on (only the main Duskfall on / off). The label is part of the button.
-- o = { label, tip, get = fn() -> bool, set = fn(bool), onClick = fn(self, on), big }.
-- Returns the button: :Refresh(), :SetChecked(on, instant), :GetChecked(), :SetEnabled(on),
-- :SetLabel(text), .Text, .onToggle = fn(self, on) (for list rows that are reused; never set
-- OnClick, it does the toggling).
local SWITCH_TIME = 0.2
local GOLD_LO, GOLD_HI = { 0.6, 0.4, 0.04, 1 }, { 1, 0.86, 0.36, 1 }
local BLUE_LO, BLUE_HI = { 0.03, 0.05, 0.2, 1 }, { 0.2, 0.33, 0.8, 1 }   -- 0x3355cc: the D in the title

function UI.Switch(parent, o)
  local big = o.big
  local W, H = big and 54 or 34, big and 28 or 18
  local R = H / 2
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(W, big and 34 or 26)
  b:RegisterForClicks("LeftButtonUp")
  local track = CreateFrame("Frame", nil, b)
  track:SetSize(W, H)
  track:SetPoint("LEFT", b, "LEFT", 0, 0)
  local L = b:GetFrameLevel()
  local layers = {}
  local function layer(n, inset)
    local f = CreateFrame("Frame", nil, track)
    f:SetPoint("TOPLEFT", track, "TOPLEFT", -inset, inset)
    f:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", inset, -inset)
    f:SetFrameLevel(L + n)
    layers[#layers + 1] = { f, n }
    return f
  end
  UI.RoundBox(layer(1, 1), { radius = R + 1, bottom = { 0, 0, 0, 0.75 }, top = { 0, 0, 0, 0.55 } })
  local off = layer(2, 0)
  UI.RoundBox(off, { radius = R, bottom = BLUE_LO, top = BLUE_HI })
  local on = layer(3, 0)
  UI.RoundBox(on, { radius = R, bottom = GOLD_LO, top = GOLD_HI })
  -- A soft shine over the top half
  local shine = CreateFrame("Frame", nil, track)
  shine:SetPoint("TOPLEFT", track, "TOPLEFT", 2, -1)
  shine:SetPoint("TOPRIGHT", track, "TOPRIGHT", -2, -1)
  shine:SetHeight(math.floor(H / 2))
  layers[#layers + 1] = { shine, 4 }
  UI.RoundBox(shine, { radius = math.floor(H / 2) - 1, bottom = { 1, 1, 1, 0 }, top = { 1, 1, 1, 0.22 } })
  -- The knob, with a soft shadow
  local K = H - 4
  local knob = CreateFrame("Frame", nil, track)
  knob:SetSize(K, K)
  layers[#layers + 1] = { knob, 5 }
  local shadow = knob:CreateTexture(nil, "BACKGROUND")
  shadow:SetTexture(UI.ART .. "dot")
  shadow:SetVertexColor(0, 0, 0, 0.45)
  shadow:SetSize(K + 2, K + 2)
  shadow:SetPoint("CENTER", knob, "CENTER", 0.5, -1)
  local disc = knob:CreateTexture(nil, "ARTWORK")
  disc:SetAllPoints()
  UI.Gradient(disc, "VERTICAL", { 0.8, 0.8, 0.84, 1 }, { 1, 1, 1, 1 }, UI.ART .. "dot")
  if ns.CursorLight then
    local lit = ns.CursorLight.NewTwin(knob, "ARTWORK", 2, "art")
    lit:SetAllPoints(disc)
    UI.Gradient(lit, "VERTICAL", { 0.8, 0.8, 0.84, 1 }, { 1, 1, 1, 1 }, UI.ART .. "dot")
  end
  local hover = knob:CreateTexture(nil, "OVERLAY")
  hover:SetAllPoints()
  hover:SetTexture(UI.ART .. "dot")
  hover:SetBlendMode("ADD")
  hover:SetVertexColor(1, 0.9, 0.6, 0.3)
  hover:Hide()
  -- Frame levels follow the button's (it may be raised after it is made)
  local function levels()
    local base = b:GetFrameLevel()
    track:SetFrameLevel(base)
    for _, l in ipairs(layers) do l[1]:SetFrameLevel(base + l[2]) end
  end
  levels()
  hooksecurefunc(b, "SetFrameLevel", levels)

  local text = b:CreateFontString(nil, "OVERLAY", big and "GameFontNormalLarge" or "GameFontHighlight")
  b.Text = text
  local state
  if big then
    text:SetPoint("TOPLEFT", track, "TOPRIGHT", 10, 5)
    state = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    state:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
  else
    text:SetPoint("LEFT", track, "RIGHT", 8, 0)
  end
  local glow = big and UI.GlowRing(b, track, W * 2.2, { breath = 1.2 }) or nil

  local checked, pos, enabled = false, 0, true
  local function place()
    local e = pos * pos * (3 - 2 * pos)
    knob:ClearAllPoints()
    knob:SetPoint("LEFT", track, "LEFT", 2 + e * (W - H), 0)
    on:SetAlpha(e)
    off:SetAlpha(1 - e)
  end
  local function look()
    if state then state:SetText(checked and "|cff40ff40On|r" or "|cff9d9d9dOff|r") end
    if glow then glow.Set(checked and enabled) end
  end
  local function step(self, dt)
    local want = checked and 1 or 0
    if pos < want then pos = math.min(want, pos + dt / SWITCH_TIME)
    elseif pos > want then pos = math.max(want, pos - dt / SWITCH_TIME) end
    place()
    if pos == want then self:SetScript("OnUpdate", nil) end
  end
  local function animate()
    if not b:IsVisible() then
      pos = checked and 1 or 0
      place()
      return
    end
    b:SetScript("OnUpdate", step)
  end

  local function fit()
    local w = text:GetStringWidth() or 0
    if state then w = math.max(w, state:GetStringWidth() or 0, 24) end
    b:SetWidth(W + (w > 0 and (big and 10 or 8) + w or 0))
  end
  function b:SetLabel(t)
    text:SetText(t or "")
    fit()
  end
  function b:SetChecked(v, instant)
    v = v and true or false
    if v == checked then return end
    checked = v
    look()
    if instant then
      self:SetScript("OnUpdate", nil)
      pos = checked and 1 or 0
      place()
    else
      animate()
    end
  end
  function b:GetChecked() return checked end
  function b:SetEnabled(v)
    enabled = v and true or false
    if enabled then self:Enable() else self:Disable() end
    self:SetAlpha(enabled and 1 or 0.45)
    look()
  end
  function b:Refresh()
    if o.get then self:SetChecked(o.get()) end
  end
  b:SetScript("OnClick", function(self)
    if not enabled then return end
    self:SetChecked(not checked)
    if PlaySound and SOUNDKIT then
      pcall(PlaySound, checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end
    if o.set then ns.Safe(o.set, "switch", checked) end
    if o.onClick then ns.Safe(o.onClick, "switch", self, checked) end
    if self.onToggle then ns.Safe(self.onToggle, "switch", self, checked) end
  end)
  b:SetScript("OnEnter", function() if enabled then hover:Show() end end)
  b:SetScript("OnLeave", function() hover:Hide() end)
  b:HookScript("OnShow", function()
    levels()
    pos = checked and 1 or 0
    place()
    look()
  end)
  tooltip(b, o.label, o.tip)

  b:SetLabel(o.label)
  if o.get then checked = o.get() and true or false end
  pos = checked and 1 or 0
  place()
  look()
  return b
end

-- The old checkbox name: every checkbox is a switch now (Kim)
function UI.Check(parent, o) return UI.Switch(parent, o) end

-- Slider ---------------------------------------------------------------------------------------
--   Label  Default: 0.5 s                          0.5 s
--   <----------------|---------------->  [ Reset ]
-- o = { label, min, max, step, value | get, default, fmt = fn(v) -> text, onChange(v), tip }
-- Drawn with UI.LightSlider (steppers on, the mark at the default; right-click = default). No
-- mouse wheel (it scrolls the page, as in BNB). Returns a holder: :SetValue(v, silent),
-- :GetValue(), :SetEnabled(on), :Refresh() (reads o.get).

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

  -- Our own slider (Kim): gold track, the diamond, < > steppers; the mark is the default
  local enabled = true
  local sync
  local cur = snap(o.get and o.get() or o.value)
  local light = UI.LightSlider(h, 10, { labelW = 0, valueW = 0, min = o.min, max = o.max, step = step,
    mid = o.default or o.min, lineH = 14, steppers = true,
    from = { 0.32, 0.25, 0.12 }, to = { 1, 0.85, 0.45 },
    get = function() return cur end,
    set = function(v)
      local n = snap(v)
      if same(n, cur) then return end
      cur = n
      sync()
      if o.onChange then ns.Safe(o.onChange, "slider", n) end
    end })
  light:SetPoint("TOPLEFT", h, "TOPLEFT", 0, -12)
  light:SetPoint("RIGHT", reset, "LEFT", -6, 0)

  sync = function()
    val:SetText(fmt(cur))
    local atDef = o.default == nil or same(cur, o.default)
    reset:SetEnabled(enabled and not atDef)
  end

  -- silent: no onChange. Otherwise the slider's own set updates cur and calls onChange.
  local function setValue(v, silent)
    if silent then
      cur = snap(v)
      light:SetValue(cur, true)
      sync()
    else
      light:SetValue(snap(v))
    end
  end
  reset:SetScript("OnClick", function() if o.default ~= nil then setValue(o.default) end end)
  if o.tip then
    local hot = CreateFrame("Frame", nil, h)
    hot:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)
    hot:SetPoint("BOTTOMRIGHT", h, "TOPRIGHT", 0, -14)
    hot:EnableMouse(true)
    tooltip(hot, o.label, o.tip)
  end

  function h:SetValue(v, silent) setValue(v, silent) end
  function h:GetValue() return cur end
  function h:SetEnabled(on)
    enabled = on and true or false
    light:SetEnabled(enabled)
    sync()
  end
  function h:Refresh() if o.get then setValue(o.get(), true) end end
  setValue(cur, true)
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
-- A square link button in our buttons' normal look (rounded, dark, gold edge; Kim) with
-- BigNoteBox's coloured symbol on top (Assets/bt-<symbol>-normal, -press when pressed, 1 px down).
-- Hover brightens it, disabled greys the symbol. o = { onClick, tip, tipSub }. The button owns its
-- mouse scripts; add behaviour with HookScript.
function UI.IconButton(parent, size, symbol, o)
  o = o or {}
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(size, size)
  UI.RoundBox(btn, { radius = 7, bottom = { 0.09, 0.06, 0.03, 0.92 }, top = { 0.26, 0.19, 0.1, 0.92 },
    border = { 1, 0.82, 0, 0.55 } })
  local hover = UI.RoundBox(btn, { radius = 7, layer = "ARTWORK", unlit = true, bottom = { 1, 1, 1, 0.03 },
    top = { 1, 1, 1, 0.14 } })
  hover:SetShown(false)
  local sym = btn:CreateTexture(nil, "OVERLAY")
  sym:SetSize(size - 4, size - 4)
  local over, down = false, false
  local function refresh()
    local dim = not btn:IsEnabled()
    local pressed = down and not dim
    sym:SetTexture(UI.ART .. "bt-" .. symbol .. (pressed and "-press" or "-normal"))
    sym:ClearAllPoints()
    sym:SetPoint("CENTER", pressed and 1 or 0, pressed and -1 or 0)
    sym:SetDesaturated(dim)
    sym:SetAlpha(dim and 0.45 or 1)
    hover:SetShown(over and not pressed and not dim)
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
-- o = { radius, bottom = {r,g,b,a}, top = {r,g,b,a}, border = {r,g,b,a}, layer, sub, unlit,
--       sweep = true: the border sweeps from gold (top left) to Duskfall blue (bottom right), as the
--       icon's ring and the main window's frame; border[4] is its alpha }.
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
  -- Every piece has a twin for the cursor light (UI/CursorLight.lua), painted the same way;
  -- o.unlit = none (the light's own haze, hover overlays)
  local twins = {}
  local CL = not o.unlit and layer ~= "HIGHLIGHT" and ns.CursorLight or nil
  local function tex(level, kind)
    local t = f:CreateTexture(nil, layer, nil, level)
    all[#all + 1] = t
    if CL then
      local w = CL.NewTwin(f, layer, level + 3, kind)
      w:SetAllPoints(t)
      twins[t] = w
    end
    return t
  end
  local function both(t, method, ...)
    t[method](t, ...)
    local w = twins[t]
    if w then w[method](w, ...) end
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
    -- Corner colours: one colour, or the gold-to-blue sweep
    local cc = { tl = col, tr = col, bl = col, br = col }
    if o.sweep then
      local A = col[4] or 1
      local g, b2 = UI.RING_GOLD, UI.RING_BLUE
      local m = { (g[1] + b2[1]) / 2, (g[2] + b2[2]) / 2, (g[3] + b2[3]) / 2 }
      cc = { tl = { g[1], g[2], g[3], A }, br = { b2[1], b2[2], b2[3], A }, tr = { m[1], m[2], m[3], A },
             bl = { m[1], m[2], m[3], A } }
    end
    local function solid()
      local t = tex(sub + 1, "edge")
      both(t, "SetColorTexture", col[1], col[2], col[3], col[4] or 1)
      return t
    end
    -- A line shaded between two corner colours (only with sweep)
    local function shadeLine(t, orient, a, b)
      if not o.sweep then return end
      UI.Gradient(t, orient, a, b)
      if twins[t] then UI.Gradient(twins[t], orient, a, b) end
    end
    for k, point in pairs(CORNER_POINT) do
      local t = tex(sub + 1, "edge")
      t:SetSize(R, R)
      t:SetPoint(point, f, point, 0, 0)
      both(t, "SetTexture", UI.ART .. "round-ring-" .. R)
      both(t, "SetTexCoord", unpack(CORNERS[k]))
      local c = cc[k]
      both(t, "SetVertexColor", c[1], c[2], c[3], c[4] or 1)
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
    shadeLine(tl, "HORIZONTAL", cc.tl, cc.tr)
    shadeLine(bl, "HORIZONTAL", cc.bl, cc.br)
    shadeLine(ll, "VERTICAL", cc.bl, cc.tl)
    shadeLine(rl, "VERTICAL", cc.br, cc.tr)
  end

  -- The fill is shaded per piece, each with its own slice of the bottom-to-top gradient
  function box:Layout()
    local H = f:GetHeight()
    if not H or H < 2 * R then H = 2 * R end
    local a, b = R / H, (H - R) / H
    local lo, hi = o.bottom, o.top or o.bottom
    local function shade(t, from, to, file)
      UI.Gradient(t, "VERTICAL", lerp(lo, hi, from), lerp(lo, hi, to), file)
      if twins[t] then UI.Gradient(twins[t], "VERTICAL", lerp(lo, hi, from), lerp(lo, hi, to), file) end
    end
    for k, t in pairs(c) do
      local file = box.round[k] and (UI.ART .. "round-corner") or nil
      if k == "tl" or k == "tr" then shade(t, b, 1, file) else shade(t, 0, a, file) end
      if file then both(t, "SetTexCoord", unpack(CORNERS[k])) else both(t, "SetTexCoord", 0, 1, 0, 1) end
    end
    shade(top, b, 1)
    shade(mid, a, b)
    shade(bot, 0, a)
  end
  function box:SetCorners(tl, tr, bl, br)
    box.round = { tl = tl and true or false, tr = tr and true or false, bl = bl and true or false, br = br and true or false }
    box:Layout()
  end
  function box:SetAlpha(v)
    for _, t in ipairs(all) do t:SetAlpha(v) end
  end
  function box:SetShown(on)
    for _, t in ipairs(all) do t:SetShown(on) end
    if CL then for _, w in pairs(twins) do CL.Want(w, on) end end
  end
  f:HookScript("OnSizeChanged", function() box:Layout() end)
  box:Layout()
  return box
end

-- Back button: round, in the buttons' normal look (dark, gold edge) with our gold chevron
-- pointing left (Kim). o = { tip, tipSub, onClick }. Same size rules as UI.IconButton.
function UI.BackButton(parent, size, o)
  o = o or {}
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  local R = math.min(12, math.floor(size / 2))
  UI.RoundBox(b, { radius = R, bottom = { 0.09, 0.06, 0.03, 0.92 }, top = { 0.26, 0.19, 0.1, 0.92 },
    border = { 1, 0.82, 0, 0.55 } })
  local hover = UI.RoundBox(b, { radius = R, layer = "ARTWORK", unlit = true, bottom = { 1, 1, 1, 0.03 }, top = { 1, 1, 1, 0.14 } })
  hover:SetShown(false)
  local arrow = b:CreateTexture(nil, "OVERLAY")
  arrow:SetSize(size - 8, size - 8)
  arrow:SetPoint("CENTER", -1, 0)
  arrow:SetTexture(UI.ART .. "chevron")
  arrow:SetVertexColor(1, 0.82, 0)
  arrow:SetRotation(math.pi)
  b:SetScript("OnMouseDown", function() arrow:SetPoint("CENTER", 0, -1) end)
  b:SetScript("OnMouseUp", function() arrow:SetPoint("CENTER", -1, 0) end)
  b:SetScript("OnEnter", function(self)
    hover:SetShown(true)
    if o.tip then
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:AddLine(o.tip, 1, 1, 1)
      if o.tipSub then GameTooltip:AddLine(o.tipSub, 0.78, 0.78, 0.78, true) end
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(self)
    hover:SetShown(false)
    arrow:SetPoint("CENTER", -1, 0)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
  end)
  if o.onClick then b:SetScript("OnClick", function(self, mb) ns.Safe(o.onClick, "back", self, mb) end) end
  return b
end

-- Card: a rounded, softly shaded box with a faint gold edge (the Settings pages' look), placed on
-- host at host's own frame level, so everything in host's child frames draws over it.
-- Returns the card frame.
function UI.Card(host, x, y, w, h)
  local c = CreateFrame("Frame", nil, host)
  c:SetPoint("TOPLEFT", host, "TOPLEFT", x, y)
  c:SetSize(w, h)
  c:SetFrameLevel(host:GetFrameLevel())
  UI.RoundBox(c, { radius = 10, bottom = { 0, 0, 0, 0.45 }, top = { 0.2, 0.15, 0.09, 0.4 },
    border = { 1, 0.82, 0, 0.22 } })
  return c
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

-- The colours of each channel's slider track: dark to light, as the value works on the picture.
UI.CHANNEL_GRADIENT = {
  gamma = { from = { 0.05, 0.05, 0.09 }, to = { 0.96, 0.93, 0.82 } },
  brightness = { from = { 0.13, 0.1, 0.07 }, to = { 1, 0.93, 0.66 } },
  contrast = { from = { 0.4, 0.4, 0.43 }, to = { 0.96, 0.56, 0.16 } },
  bloom = { from = { 0.2, 0.18, 0.26 }, to = { 1, 0.87, 0.56 } },
}

-- Light slider ---------------------------------------------------------------------------------
--   Gamma      [ dark ======|=====O====== light ]    +0.10
-- Simple mode's slider: the track is a gradient (what the value does to the picture), the mark in
-- the middle is 0 ("no change"), a gold line under the track runs from the mark to the thumb.
-- Right-click puts it back to 0. The range should be symmetric around 0.
-- o = { label, min, max, step, from = { r, g, b }, to = { r, g, b }, get = fn() -> v,
--       mid = the mark's value (default 0), labelW / valueW = column widths (0 = none),
--       set = fn(v), fmt = fn(v) -> text, tip, lineH = height of the middle mark (the row
--       spacing joins stacked sliders' marks into one line), steppers = true for < > buttons at
--       the ends (one step each; Advanced and Settings, Kim) }. :Refresh(), :SetEnabled(on),
--       :SetRange(min, max, mid), :SetValue(v, silent), :GetValue().
function UI.LightSlider(parent, width, o)
  local LABEL_W, VALUE_W, H = o.labelW or 84, o.valueW or 96, 30
  local MID = o.mid or 0      -- the mark: "no change" (0) or, for fixed values, the game default
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
  if VALUE_W == 0 then val:Hide() end
  if o.tip then
    local hot = CreateFrame("Frame", nil, h)
    hot:SetPoint("LEFT", h, "LEFT", 0, 0)
    hot:SetSize(LABEL_W, H)
    hot:EnableMouse(true)
    tooltip(hot, o.label, o.tip .. "\n\nRight-click the slider: back to the middle mark.")
  end

  local STEP_W = o.steppers and 16 or 0
  local sl = CreateFrame("Slider", nil, h)
  sl:SetPoint("LEFT", h, "LEFT", (LABEL_W > 0 and LABEL_W - 6 or 0) + STEP_W, 0)
  sl:SetPoint("RIGHT", h, "RIGHT", -VALUE_W + 2 - STEP_W, 0)
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
  -- The cursor light catches the diamond (UI/CursorLight.lua); it follows the thumb
  if ns.CursorLight then
    local lit = ns.CursorLight.NewTwin(sl, "OVERLAY", 7, "edge")
    lit:SetAllPoints(thumb)
    lit:SetTexture(UI.ART .. "diamond")
  end
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
  if ns.CursorLight then
    local lit = ns.CursorLight.NewTwin(sl, "ARTWORK", 1, "fill")
    lit:SetAllPoints(track)
    UI.Gradient(lit, "HORIZONTAL", o.from, o.to)
  end
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
    if math.abs(cur - MID) < o.step / 2 then val:SetText(o.zero and o.zero() or "|cff9d9d9dNo change|r")
    else val:SetText(o.fmt and o.fmt(cur) or tostring(cur)) end
    local x0, x1 = xOf(MID), xOf(cur)
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
    if button == "RightButton" and self:IsEnabled() then self:SetValue(MID) end
  end)
  sl:SetScript("OnSizeChanged", show)

  -- Steppers: the game's own slider arrows (atlas), "<" ">" where the atlas is missing
  local steppers = {}
  if o.steppers then
    local function stepper(dir)
      local b = CreateFrame("Button", nil, h)
      b:SetSize(STEP_W, 18)
      if dir < 0 then b:SetPoint("RIGHT", sl, "LEFT", 1, 0) else b:SetPoint("LEFT", sl, "RIGHT", -1, 0) end
      local atlas = dir < 0 and "Minimal_SliderBar_Button_Left" or "Minimal_SliderBar_Button_Right"
      local has = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
      local t = b:CreateTexture(nil, "ARTWORK")
      t:SetPoint("CENTER")
      if has then
        t:SetAtlas(atlas, true)
      else
        t:Hide()
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("CENTER")
        fs:SetText(dir < 0 and "<" or ">")
      end
      local hl = b:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints(t)
      if has then hl:SetAtlas(atlas) hl:SetBlendMode("ADD") hl:SetAlpha(0.4) end
      b:SetScript("OnMouseDown", function() t:SetPoint("CENTER", 1, -1) end)
      b:SetScript("OnMouseUp", function() t:SetPoint("CENTER", 0, 0) end)
      b:SetScript("OnClick", function()
        if not sl:IsEnabled() then return end
        local lo, hi = sl:GetMinMaxValues()
        sl:SetValue(math.max(lo, math.min(hi, cur + dir * o.step)))
      end)
      steppers[#steppers + 1] = b
    end
    stepper(-1)
    stepper(1)
  end

  local function setValue(v, silent)
    v = tonumber(v) or 0
    muted = silent and true or false
    sl:SetValue(v)
    muted = false
    cur = v
    show()
  end
  function h:Refresh() setValue(o.get(), true) end
  function h:SetValue(v, silent) setValue(v, silent) end
  function h:GetValue() return cur end
  function h:SetRange(lo, hi, mid)
    o.min, o.max = lo, hi
    if mid ~= nil then MID = mid end
    muted = true
    sl:SetMinMaxValues(lo, hi)
    muted = false
    show()
  end
  function h:SetEnabled(on)
    pcall(sl.SetEnabled, sl, on and true or false)
    sl:EnableMouse(on and true or false)
    for _, b in ipairs(steppers) do b:SetEnabled(on and true or false) end
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
-- o = { placeholder, onChange = fn(text), height }. Returns the edit box (:GetText, :SetText).
function UI.SearchBox(parent, width, o)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetSize(width - 6, o.height or 22)
  -- Taller than the template: its 8 px end caps skew when stretched (Kim), so our own rounded
  -- box instead, covering the frame exactly, and the text moved in off its edge.
  local inset = 0
  if o.height then
    for _, k in ipairs({ "Left", "Middle", "Right" }) do
      local t = eb[k]
      if t and t.Hide then t:Hide() end
    end
    UI.RoundBox(eb, { radius = 6, bottom = { 0, 0, 0, 0.7 }, top = { 0.04, 0.03, 0.02, 0.7 },
      border = { 0.8, 0.72, 0.55, 0.6 } })
    inset = 9
  end
  eb:SetAutoFocus(false)
  eb:SetTextInsets(inset, o.height and 24 or 22, 0, 0)
  local ph = eb:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  ph:SetPoint("LEFT", eb, "LEFT", inset, 0)
  ph:SetText(o.placeholder or "Search")
  local x = UI.ClearX(eb, 16, function()
    eb:SetText("")
    eb:ClearFocus()
  end, "Clear")
  x:SetPoint("RIGHT", eb, "RIGHT", o.height and -7 or -2, 0)
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

-- Gentle fade in / out for our windows (Kim, 2026-11-27: "all windows fade gently, but not too long").
-- UI.Fader(f, o): f fades in on every show (from its alpha at attach time, or o.alpha) and gets
--   f:FadeHide([seconds])  fade out, then the real Hide (OnHide fires at the end)
--   f:IsOpen()             shown and not fading out (use this for toggles)
--   f:Show()               during a fade-out it turns back and fades in from where it is
-- Hide() itself is left alone (secure code calls it through UISpecialFrames: wrapping it would carry
-- our taint into the game menu), so ESC in combat still closes at once. Out of combat, o.esc = true
-- catches ESC on the frame and fades it instead; a second ESC while it fades closes it at once and
-- passes on (the game menu opens as usual).
UI.FADE_IN, UI.FADE_OUT = 0.3, 0.3   -- Kim, 2026-11-27
local function smooth(t) return t * t * (3 - 2 * t) end
function UI.Fader(f, o)
  o = o or {}
  local target = o.alpha or f:GetAlpha()
  local from, to, dur, t0, closing = 0, target, 1, 0, false
  local driver = CreateFrame("Frame", nil, f)
  driver:Hide()
  local function run(a, b, seconds)
    from, to, dur, t0 = a, b, math.max(0.01, seconds), GetTime()
    f:SetAlpha(a)
    driver:Show()
  end
  driver:SetScript("OnUpdate", function(self)
    local p = math.min(1, (GetTime() - t0) / dur)
    f:SetAlpha(from + (to - from) * smooth(p))
    if p < 1 then return end
    self:Hide()
    if closing then
      closing = false
      f:Hide()
      f:SetAlpha(target)
    end
  end)
  f:HookScript("OnShow", function()
    closing = false
    run(0, target, o.fadeIn or UI.FADE_IN)
  end)
  f:HookScript("OnHide", function()
    closing = false
    driver:Hide()
    f:SetAlpha(target)
  end)
  local show = f.Show
  function f:Show()
    if closing then
      closing = false
      run(self:GetAlpha(), target, (o.fadeIn or UI.FADE_IN) * (1 - self:GetAlpha() / math.max(target, 0.01)))
    end
    show(self)
  end
  function f:FadeHide(seconds)
    if not self:IsShown() or closing then return end
    if not self:IsVisible() then self:Hide() return end   -- its parent is hidden: nothing to see
    closing = true
    local a = self:GetAlpha()
    run(a, 0, (seconds or o.fadeOut or UI.FADE_OUT) * a / math.max(target, 0.01))
  end
  function f:IsOpen() return self:IsShown() and not closing end
  function f:IsClosing() return closing end
  if o.esc then
    f:EnableKeyboard(true)
    pcall(f.SetPropagateKeyboardInput, f, true)
    f:HookScript("OnKeyDown", function(self, key)
      if key ~= "ESCAPE" or InCombatLockdown() then return end
      if self.escHandled then self.escHandled = nil return end   -- a page used this ESC (Window.lua)
      if closing then self:Hide() return end
      self:FadeHide()
      pcall(self.SetPropagateKeyboardInput, self, false)
      C_Timer.After(0, function()
        if not InCombatLockdown() then pcall(self.SetPropagateKeyboardInput, self, true) end
      end)
    end)
  end
  return f
end
