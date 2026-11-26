-- Duskfall UI/Window.lua: the settings window. ButtonFrameTemplate (Forever draws its own metal
-- frame on it), the wood background and glow from Kahoof, classic tabs outside the bottom edge
-- (what the addon does on the left: Places, Styles; global things on the right: Settings, About),
-- and a status strip that shows what Duskfall is doing right now. Built on first open.
-- Tabs register through W.AddTab(id, title, builder, side); builder(page) runs once.
-- A tab with sub-pages sets page.Back = fn() -> true when it went back (ESC goes back first).
-- Public: ns.OpenWindow(), W.AddTab(id, title, builder, side), W.Select(id), W.UpdateStatus(),
--         W.SetAdvanced(on) (fires MODE), W.frame
local ADDON, ns = ...
local W = {}
ns.Window = W
local UI, C = ns.UI, ns.Channels

local WIDTH, HEIGHT = 780, 560
local ICON_SIZE, ICON_OUT = 62, 18   -- our round icon, and how far it sits out of the top-left corner
local PAGE_TOP = 34                  -- page content starts this far below the window top
local tabs = {}          -- { id, title, builder, side, page, button }
local frame

function W.AddTab(id, title, builder, side)
  tabs[#tabs + 1] = { id = id, title = title, builder = builder, side = side or "left" }
end

local function statusText()
  local st = ns.Detect.state
  local env = st.env
  local style = ns.Resolver.ActiveStyle()
  local place = "?"
  if env then
    if env.instance then place = env.instanceName or "?"
    elseif env.sub then place = (env.zoneName or "?") .. " > " .. env.sub
    elseif env.zoneName then place = env.zoneName end
  end
  local cur = C.ReadAll() or {}
  local vals = {}
  for _, ch in ipairs(C.list) do
    local v = cur[ch.key]
    local s = ch.short .. " " .. (v and C.Format(ch.key, v) or "-")
    if st.held[ch.key] ~= nil then s = "|cffd09060" .. s .. "|r"
    elseif st.source and st.source[ch.key] then s = "|cffc8b070" .. s .. "|r" end
    vals[#vals + 1] = s
  end
  local onoff = ""
  if not ns.cfg.enabled then onoff = "|cffff4040Off|r   " end
  return string.format("%sStyle: |cffc0c0c0%s|r     Here: |cffc0c0c0%s|r     %s", onoff, style.name or "?", place,
    table.concat(vals, "  "))
end

function W.UpdateTitle()
  if not frame then return end
  local t = "Duskfall"
  if not ns.cfg.enabled then t = "Duskfall  |cffff6060(Off)|r" end
  if frame.SetTitle then frame:SetTitle(t)
  elseif frame.TitleContainer and frame.TitleContainer.TitleText then frame.TitleContainer.TitleText:SetText(t) end
end

function W.UpdateStatus()
  if frame and frame:IsShown() then frame.status:SetText(statusText()) end
end

local function current()
  for _, t in ipairs(tabs) do
    if t.id == frame.selected then return t end
  end
end

-- Tabs are selected one by one (as BigNoteBox does), never with PanelTemplates_SetTab: that
-- re-anchors the whole row in a line, which broke the left / right groups (Kim's screenshot).
function W.Select(id)
  for _, t in ipairs(tabs) do
    if t.id == id then
      if not t.page.built then
        t.page.built = true
        ns.Safe(t.builder, "tab " .. t.id, t.page)
      end
      t.page:Show()
      pcall(PanelTemplates_SelectTab, t.button)
      frame.selected = id
      ns.cfg.windowTab = id
    else
      t.page:Hide()
      pcall(PanelTemplates_DeselectTab, t.button)
    end
  end
end

local function savePosition(f)
  local point, _, rel, x, y = f:GetPoint(1)
  ns.cfg.window = { point = point, rel = rel, x = x, y = y }
end

local function build()
  local f = CreateFrame("Frame", "DuskfallWindow", UIParent, "ButtonFrameTemplate")
  frame = f
  W.frame = f
  f:SetSize(WIDTH, HEIGHT)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  local pos = ns.cfg.window
  if type(pos) == "table" and pos.point then
    f:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x or 0, pos.y or 0)
  else
    f:SetPoint("CENTER")
  end
  W.UpdateTitle()
  -- The window without the portrait ring (as BNB's windows), and our round icon on its own,
  -- half out of the top-left corner so it never covers page titles (Kim)
  pcall(ButtonFrameTemplate_HidePortrait, f)
  local badge = CreateFrame("Frame", nil, f)
  badge:SetSize(ICON_SIZE, ICON_SIZE)
  badge:SetPoint("TOPLEFT", f, "TOPLEFT", -ICON_OUT, ICON_OUT)
  -- Above the template's border (NineSlice), title and close button, which sit on child frames of
  -- their own: one level over the highest of them (at +30 on the window it was behind the border)
  local function liftBadge()
    local top = f:GetFrameLevel()
    for _, child in ipairs({ f:GetChildren() }) do
      if child ~= badge and child ~= f.advCheck and child:GetFrameLevel() > top then top = child:GetFrameLevel() end
    end
    badge:SetFrameLevel(top + 5)
    if f.advCheck then f.advCheck:SetFrameLevel(top + 5) end
  end
  badge.Lift = liftBadge
  local icon = badge:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture(UI.ART .. "icon")
  -- Advanced mode, left of the close button (Kim): Places shows the full list and Look editor
  local adv = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  adv:SetSize(22, 22)
  local advText = adv.Text or adv.text
  if not advText then
    advText = adv:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    advText:SetPoint("LEFT", adv, "RIGHT", 0, 0)
  end
  advText:SetFontObject("GameFontNormalSmall")
  advText:SetText("Advanced")
  local close = f.CloseButton or _G.DuskfallWindowCloseButton
  if close then adv:SetPoint("RIGHT", close, "LEFT", -(advText:GetStringWidth() + 6), 0)
  else adv:SetPoint("TOPRIGHT", f, "TOPRIGHT", -100, 0) end
  adv:SetChecked(ns.cfg.advanced and true or false)
  adv:SetScript("OnClick", function(self) W.SetAdvanced(self:GetChecked()) end)
  UI.Tooltip(adv, "Advanced mode", "Places shows every place you have been and the full Look editor, " ..
    "with every condition and option. Off: the simple page.")
  f.advCheck = adv
  pcall(ButtonFrameTemplate_HideButtonBar, f)
  if f.Inset then f.Inset:Hide() end
  UI.Wood(f)
  UI.Glow(f, f.Bg, 0.6)

  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    savePosition(self)
  end)
  tinsert(UISpecialFrames, "DuskfallWindow")

  -- ESC on a sub-page goes back to its overview first. Keyboard input can't be stopped from
  -- passing on in combat, so there ESC simply closes the window (UISpecialFrames).
  -- Propagation is left on at all times except for the one ESC that went back, and switched on
  -- again on the next frame, so keys can never get stuck in the window if combat starts.
  f:EnableKeyboard(true)
  pcall(f.SetPropagateKeyboardInput, f, true)
  f:SetScript("OnKeyDown", function(self, key)
    if InCombatLockdown() or key ~= "ESCAPE" then return end
    local t = current()
    if t and t.page.Back and t.page.Back() then
      pcall(self.SetPropagateKeyboardInput, self, false)
      C_Timer.After(0, function()
        if not InCombatLockdown() then pcall(self.SetPropagateKeyboardInput, self, true) end
      end)
    end
  end)

  -- Tabs: classic tabs hanging under the bottom edge, left group from the left, right group
  -- from the right
  local lastLeft, lastRight
  local rightTabs = {}
  for i, t in ipairs(tabs) do
    -- Not named <window>Tab<n>: Blizzard's tab code finds tabs by that name and lines them all up
    -- in one row, which stretched Settings between Styles and About (Kim's screenshots)
    local b = CreateFrame("Button", "DuskfallTabButton" .. i, f, "PanelTabButtonTemplate")
    b:SetText(t.title)
    b:SetID(i)
    b:SetScript("OnClick", function() W.Select(t.id) end)
    pcall(PanelTemplates_TabResize, b, 12)
    t.button = b
    if t.side == "right" then
      rightTabs[#rightTabs + 1] = b
    else
      b:ClearAllPoints()
      if lastLeft then b:SetPoint("LEFT", lastLeft, "RIGHT", 4, 0)
      else b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, 2) end
      lastLeft = b
    end

    local page = CreateFrame("Frame", nil, f)
    page:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -PAGE_TOP)
    page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 34)
    page:Hide()
    t.page = page
  end
  -- Right group: the last one sits at the right edge, the others go leftwards from it
  for i = #rightTabs, 1, -1 do
    local b = rightTabs[i]
    b:ClearAllPoints()
    if lastRight then b:SetPoint("RIGHT", lastRight, "LEFT", -4, 0)
    else b:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -12, 2) end
    lastRight = b
  end

  -- Status strip
  -- Status strip on its own frame above the pages: a page's glow (a child frame) drew over a
  -- string on the window itself, and the RIGHT anchor stretched it to mid-window (it vanished)
  local strip = CreateFrame("Frame", nil, f)
  strip:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 10)
  strip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 10)
  strip:SetHeight(16)
  strip:SetFrameLevel(f:GetFrameLevel() + 20)
  local status = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  status:SetAllPoints(strip)
  status:SetJustifyH("CENTER")
  status:SetTextColor(0.6, 0.6, 0.6)
  status:SetWordWrap(false)
  f.status = status

  -- The tab template sets its own look when it is first shown (every tab gold): select again
  -- after that, on the next frame
  f:SetScript("OnShow", function(self)
    badge.Lift()
    if ns.Moon then ns.Safe(ns.Moon.Check, "moon check") end
    W.UpdateStatus()
    if self.selected then
      W.Select(self.selected)
      C_Timer.After(0, function() if self:IsShown() and self.selected then W.Select(self.selected) end end)
    end
  end)
  local want = ns.cfg.windowTab
  local known = false
  for _, t in ipairs(tabs) do if t.id == want then known = true end end
  if not known then want = tabs[1].id end
  W.Select(want)
  -- A new frame starts shown: hide it, or the first toggle below hides it again (two clicks to open)
  f:Hide()
end

-- Simple or Advanced mode (title bar switch). Shows Places, the tab it changes.
function W.SetAdvanced(on)
  ns.cfg.advanced = on and true or false
  if frame and frame.advCheck then frame.advCheck:SetChecked(ns.cfg.advanced) end
  if frame and frame.selected ~= "places" then W.Select("places") end
  ns.Fire("MODE", ns.cfg.advanced)
end

-- tabID: open on that tab (closes it if it is already showing, unless keepOpen)
function ns.OpenWindow(tabID, keepOpen)
  if not ns.db or not ns.Detect.state.started then ns.Print("not ready yet.") return end
  if not frame then build() end
  if tabID then
    -- Same tab already showing: the command closes the window again (a toggle)
    if not keepOpen and frame:IsShown() and frame.selected == tabID then frame:Hide() return end
    W.Select(tabID)
    frame:Show()
  elseif frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
  end
  W.UpdateStatus()
end

ns.Listen("EVALUATED", function() W.UpdateStatus() end)
ns.Listen("ONOFF", function()
  W.UpdateTitle()
  W.UpdateStatus()
end)
-- Values move during a transition: keep the strip current while it runs.
C_Timer.NewTicker(0.25, function()
  if frame and frame:IsShown() and ns.Transition.IsRunning() then W.UpdateStatus() end
end)
