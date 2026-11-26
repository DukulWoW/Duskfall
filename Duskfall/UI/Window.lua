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
  if ns.Help then ns.Help.Hide() end
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
  f:SetAlpha(0.95)   -- as see-through as BigNoteBox's main window (Kim)
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
  -- Raise a frame and everything in it, keeping their order (a control made of child frames)
  local function raise(fr, lvl)
    local old = fr:GetFrameLevel()
    fr:SetFrameLevel(lvl)
    for _, c in ipairs({ fr:GetChildren() }) do raise(c, lvl + (c:GetFrameLevel() - old)) end
  end
  local function liftBadge()
    local top = f:GetFrameLevel()
    for _, child in ipairs({ f:GetChildren() }) do
      if child ~= badge and child ~= f.advCheck and child ~= f.helpBtn and child:GetFrameLevel() > top then
        top = child:GetFrameLevel()
      end
    end
    badge:SetFrameLevel(top + 5)
    if f.advCheck then raise(f.advCheck, top + 5) end
    if f.helpBtn then f.helpBtn:SetFrameLevel(top + 5) end
  end
  badge.Lift = liftBadge
  local icon = badge:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture(UI.ART .. "icon")
  -- Advanced mode, left of the close button (Kim): Places shows the full list and Look editor
  -- Simple | Advanced as a small picker (Kim: two views of the same page)
  local adv = UI.Segmented(f, 136, { height = 18,
    items = function()
      return { { "simple", "Simple", nil, "Places and Styles in a few plain choices." },
               { "advanced", "Advanced", nil, "Every place you have been, the full Look editor and every " ..
                 "condition and option." } }
    end,
    get = function() return ns.cfg.advanced and "advanced" or "simple" end,
    set = function(v) W.SetAdvanced(v == "advanced") end })
  local close = f.CloseButton or _G.DuskfallWindowCloseButton
  -- Help, between Advanced and the close button: our link-button look with Kim's coloured "?"
  -- (Assets/bt-help-normal / -press), as the About tab's buttons
  local help = UI.IconButton(f, 22, "help", { tip = "Help", tipSub = "How Duskfall works.",
    onClick = function() if ns.Help then ns.Help.Toggle() end end })
  if close then help:SetPoint("RIGHT", close, "LEFT", -2, 0)
  else help:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, 0) end
  f.helpBtn = help
  adv:SetPoint("RIGHT", help, "LEFT", -8, 0)
  adv:Refresh()   -- the picker makes its buttons in Refresh
  f.advCheck = adv
  pcall(ButtonFrameTemplate_HideButtonBar, f)
  if ns.CursorLight then ns.CursorLight.Attach(f) end
  if f.Inset then f.Inset:Hide() end
  UI.Wood(f)
  -- The cursor light also catches the wood, the window's border and the logo (Kim; UI/CursorLight.lua)
  if ns.CursorLight then
    local CL = ns.CursorLight
    if f.Bg then CL.Copy(f.Bg, "fill") end
    if f.NineSlice then
      for _, r in ipairs({ f.NineSlice:GetRegions() }) do
        if r.IsObjectType and r:IsObjectType("Texture") then CL.Copy(r, "edge") end
      end
    end
    CL.Copy(icon, "art")
  end
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
    local helpOpen = ns.Help and ns.Help.Shown()
    if helpOpen then ns.Help.Hide() end
    if helpOpen or (t and t.page.Back and t.page.Back()) then
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
    if self.advCheck then self.advCheck:Refresh() end
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

-- Simple or Advanced mode (title bar switch): Places and Styles. From another tab it shows Places.
function W.SetAdvanced(on)
  ns.cfg.advanced = on and true or false
  if frame and frame.advCheck then frame.advCheck:Refresh() end
  if frame and frame.selected ~= "places" and frame.selected ~= "styles" then W.Select("places") end
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

-- TEMPORARY preview (Kim, 2026-11-26; remove after test T8): /dusk framepreview steps the main
-- window through: the game's frame -> a fully custom frame (rounded, gold edge, our title line and
-- round close X, pill tabs) -> the game's frame tinted like the icon's ring (gold top left, blue
-- bottom right) -> back. Nothing is saved; a /reload undoes it too.
local preview
function W.FramePreview()
  local f = frame
  if not f then
    ns.OpenWindow("settings", true)
    f = frame
    if not f then return end
  end
  if not preview then
    preview = { on = false, tabs = {} }
    local skin = CreateFrame("Frame", nil, f)
    skin:SetAllPoints()
    skin:SetFrameLevel(f:GetFrameLevel())
    UI.RoundBox(skin, { radius = 12, bottom = { 0.05, 0.035, 0.02, 0.97 }, top = { 0.17, 0.12, 0.07, 0.97 },
      border = { 1, 0.82, 0, 0.6 } })
    UI.Glow(skin, nil, 0.7)
    local line = skin:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.35)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", skin, "TOPLEFT", 12, -28)
    line:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -12, -28)
    skin:Hide()
    preview.skin = skin
    local x = UI.ClearX(f, 20, function() f:Hide() end, "Close")
    x:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -4)
    x:SetFrameLevel(f:GetFrameLevel() + 500)
    x:Hide()
    preview.x = x
    for _, t in ipairs(tabs) do
      local b = t.button
      local pill = CreateFrame("Frame", nil, b)
      pill:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -4)
      pill:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 6)
      pill:SetFrameLevel(b:GetFrameLevel())
      local normal = UI.RoundBox(pill, { radius = 8, bottom = { 0.05, 0.035, 0.02, 0.95 }, top = { 0.2, 0.15, 0.09, 0.95 },
        border = { 1, 0.82, 0, 0.45 } })
      local picked = UI.RoundBox(pill, { radius = 8, sub = 3, bottom = { 0.5, 0.33, 0.05, 1 }, top = { 0.95, 0.75, 0.26, 1 },
        border = { 1, 0.92, 0.55, 0.95 } })
      pill:Hide()
      preview.tabs[#preview.tabs + 1] = { t = t, pill = pill, normal = normal, picked = picked }
    end
    preview.paint = function()
      for _, e in ipairs(preview.tabs) do
        local sel = frame.selected == e.t.id
        e.picked:SetShown(sel)
        e.normal:SetShown(not sel)
        local fs = e.t.button:GetFontString()
        if fs then
          if sel then fs:SetTextColor(0.14, 0.08, 0) fs:SetShadowOffset(0, 0)
          else fs:SetTextColor(1, 0.82, 0) fs:SetShadowOffset(1, -1) end
        end
      end
    end
    hooksecurefunc(W, "Select", function() if preview.on then preview.paint() end end)
  end
  -- The tinted game frame: each border piece greyed, then shaded; corners solid, edges blending
  -- between their two corners, so the whole border sweeps from gold (top left) to blue (bottom right)
  local GOLD, BLUE = { 1, 0.85, 0.4, 1 }, { 0.36, 0.5, 1, 1 }
  local MID = { (GOLD[1] + BLUE[1]) / 2, (GOLD[2] + BLUE[2]) / 2, (GOLD[3] + BLUE[3]) / 2, 1 }
  local PIECES = {
    TopLeftCorner = { GOLD }, TopRightCorner = { MID }, BottomLeftCorner = { MID }, BottomRightCorner = { BLUE },
    TopEdge = { "HORIZONTAL", GOLD, MID }, BottomEdge = { "HORIZONTAL", MID, BLUE },
    LeftEdge = { "VERTICAL", MID, GOLD }, RightEdge = { "VERTICAL", BLUE, MID },
  }
  local function tint(on)
    local ns9 = f.NineSlice
    if not ns9 then return end
    for key, spec in pairs(PIECES) do
      local t = ns9[key]
      if t then
        t:SetDesaturated(on)
        if not on then t:SetVertexColor(1, 1, 1, 1)
        elseif #spec == 1 then t:SetVertexColor(spec[1][1], spec[1][2], spec[1][3], 1)
        elseif CreateColor then
          -- Straight on the piece: its art and texture coordinates stay as they are
          local a, b = spec[2], spec[3]
          pcall(t.SetGradient, t, spec[1], CreateColor(a[1], a[2], a[3], 1), CreateColor(b[1], b[2], b[3], 1))
        end
      end
    end
  end
  preview.mode = ((preview.mode or 0) + 1) % 3
  tint(preview.mode == 2)
  preview.on = preview.mode == 1
  local on = preview.on
  local a = on and 0 or 1
  if f.NineSlice then f.NineSlice:SetAlpha(a) end
  if f.TopTileStreaks then f.TopTileStreaks:SetAlpha(a) end
  if f.Bg then f.Bg:SetAlpha(a) end
  if f.CloseButton then f.CloseButton:SetShown(not on) end
  preview.skin:SetShown(on)
  preview.x:SetShown(on)
  for _, e in ipairs(preview.tabs) do
    for _, r in ipairs({ e.t.button:GetRegions() }) do
      if r.IsObjectType and r:IsObjectType("Texture") then r:SetAlpha(a) end
    end
    e.pill:SetShown(on)
  end
  if on then preview.paint() else W.Select(frame.selected) end
  local names = { [0] = "the game's frame", "fully custom", "the game's frame, tinted gold to blue" }
  ns.Print("frame preview: %s (/dusk framepreview again for the next).", names[preview.mode])
end
