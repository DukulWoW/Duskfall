-- Duskfall UI/Window.lua: the settings window. ButtonFrameTemplate (Forever draws its own metal
-- frame on it), the wood background and glow from Kahoof, classic tabs outside the bottom edge
-- (what the addon does on the left: Places, Styles; global things on the right: Settings, About),
-- and a status strip that shows what Duskfall is doing right now. Built on first open.
-- Tabs register through W.AddTab(id, title, builder, side); builder(page) runs once.
-- A tab with sub-pages sets page.Back = fn() -> true when it went back (ESC goes back first).
-- Public: ns.OpenWindow(), W.AddTab(id, title, builder, side), W.Select(id), W.UpdateStatus(),
--         W.SetAdvanced(on) (fires MODE), W.frame
local ADDON, ns = ...
local L = ns.L
local W = {}
ns.Window = W
local UI, C = ns.UI, ns.Channels

-- The icon's ring colours (Kim, 2026-11-26: "looks epic"): the window border sweeps from gold at
-- the top left to Duskfall blue at the bottom right; the tabs are blue, the picked one gold.
local GOLD = { UI.RING_GOLD[1], UI.RING_GOLD[2], UI.RING_GOLD[3], 1 }
local BLUE = { UI.RING_BLUE[1], UI.RING_BLUE[2], UI.RING_BLUE[3], 1 }
local MID = { (GOLD[1] + BLUE[1]) / 2, (GOLD[2] + BLUE[2]) / 2, (GOLD[3] + BLUE[3]) / 2, 1 }
W.GOLD, W.BLUE = GOLD, BLUE
-- Border pieces: corners solid, edges blending between their two corners
local PIECES = {
  TopLeftCorner = { GOLD }, TopRightCorner = { MID }, BottomLeftCorner = { MID }, BottomRightCorner = { BLUE },
  TopEdge = { "HORIZONTAL", GOLD, MID }, BottomEdge = { "HORIZONTAL", MID, BLUE },
  LeftEdge = { "VERTICAL", MID, GOLD }, RightEdge = { "VERTICAL", BLUE, MID },
}
-- Greyed first, so the colours come out clean; the gradient goes straight on the piece (its art
-- and texture coordinates stay)
local function tintPiece(t, spec)
  if not t then return end
  t:SetDesaturated(true)
  if #spec == 1 then
    t:SetVertexColor(spec[1][1], spec[1][2], spec[1][3], 1)
  elseif CreateColor then
    local a, b = spec[2], spec[3]
    pcall(t.SetGradient, t, spec[1], CreateColor(a[1], a[2], a[3], 1), CreateColor(b[1], b[2], b[3], 1))
  end
end

-- Tabs: every picture of a tab (not its hover highlight) greyed and coloured, gold when picked;
-- the picked tab's text gold too (Kim)
local function paintTab(b, picked)
  local col = picked and GOLD or BLUE
  for _, r in ipairs({ b:GetRegions() }) do
    if r.IsObjectType and r:IsObjectType("Texture") and r:GetDrawLayer() ~= "HIGHLIGHT" then
      r:SetDesaturated(true)
      r:SetVertexColor(col[1], col[2], col[3], 1)
    end
  end
  local fs = b:GetFontString()
  if fs then
    fs:SetTextColor(1, 0.82, 0)
    fs:SetShadowOffset(1, -1)
  end
end

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
  if not ns.cfg.enabled then onoff = "|cffff4040" .. L["WIN_OFF"] .. "|r   " end
  return onoff .. L["PL_STYLE"]:format("|cffc0c0c0" .. (style.name or "?") .. "|r") .. "     "
    .. L["WIN_HERE"]:format("|cffc0c0c0" .. place .. "|r") .. "     " .. table.concat(vals, "  ")
end

function W.UpdateTitle()
  if not frame then return end
  local t = "Duskfall"   --noloc
  if not ns.cfg.enabled then t = "Duskfall  |cffff6060" .. L["WIN_TITLE_OFF"] .. "|r" end   --noloc
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
-- Overlays (Help, Patch Notes): a panel over the pages, under the title bar, down to the bottom
-- edge. While one shows, the page under it is see-through-proof (alpha 0) and the status strip is
-- hidden (Kim). One at a time; picking a tab or closing the window closes them.
-- W.NewOverlay(title) -> f with f.closeBtn (top right) and f.title; f:Show() / f:FadeHide().
local overlays = {}
-- The page frame of a tab (built or not)
function W.PageOf(id)
  for _, t in ipairs(tabs) do
    if t.id == id then return t.page end
  end
end

-- instant: hide at once (a Help link opens a page: it must show now, not behind a fading Help)
function W.CloseOverlays(instant)
  local any = false
  for _, o in ipairs(overlays) do
    if instant and o:IsShown() then
      o:Hide()
      any = true
    elseif o:IsOpen() then
      o:FadeHide()
      any = true
    end
  end
  return any
end
function W.NewOverlay(titleText)
  local win = frame
  local f = CreateFrame("Frame", nil, win)
  f:SetPoint("TOPLEFT", win, "TOPLEFT", 6, -26)
  f:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -6, 5)
  f:SetFrameLevel(win:GetFrameLevel() + 40)
  f:EnableMouse(true)
  -- Solid under the wood: the wood art is partly see-through, and the page under it showed (Kim)
  local base = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  base:SetAllPoints()
  base:SetColorTexture(0.07, 0.05, 0.03, 1)
  local bg = f:CreateTexture(nil, "BACKGROUND", nil, 0)
  bg:SetAllPoints()
  bg:SetTexture(UI.ART .. "Backgrounds\\wood", "REPEAT", "REPEAT")
  bg:SetHorizTile(true)
  bg:SetVertTile(true)
  UI.Glow(f, nil, 0.8)
  f.title = UI.Label(f, titleText, "GameFontNormalHuge")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -16)
  f.closeBtn = UI.Button(f, L["BTN_CLOSE"], 90, function() f:FadeHide() end)
  f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -16)
  win:HookScript("OnHide", function() f:Hide() end)
  UI.Fader(f)   -- ESC: the window's OnKeyDown closes it (before the page)
  f:HookScript("OnShow", function(self)
    -- From one overlay to another (Help <-> Patch Notes): swap at once, no fade (Kim)
    local swapped = false
    for _, o in ipairs(overlays) do
      if o ~= self and o:IsShown() then o:Hide() swapped = true end
    end
    if swapped then self:FadeSkip() end
    -- Every tab page out of sight while it shows (it is a page of its own, Kim)
    for _, t in ipairs(tabs) do if t.page then t.page:SetAlpha(0) end end
    if win.strip then win.strip:Hide() end
  end)
  f:HookScript("OnHide", function(self)
    for _, o in ipairs(overlays) do
      if o ~= self and o:IsShown() then return end
    end
    for _, t in ipairs(tabs) do if t.page then t.page:SetAlpha(1) end end
    W.UpdateStrip()
  end)
  overlays[#overlays + 1] = f
  f:Hide()
  return f
end

-- The status strip shows on every tab but About (Kim, 2026-11-27: the flags sit there), and never
-- under an overlay
function W.UpdateStrip()
  if not (frame and frame.strip) then return end
  local covered = false
  for _, o in ipairs(overlays) do if o:IsShown() then covered = true end end
  frame.strip:SetShown(not covered and frame.selected ~= "about")
end

function W.Select(id)
  -- Only a change of tab closes an overlay: the window's OnShow selects its tab again (now and
  -- next frame), which closed the Patch Notes the toast had just opened
  if not frame or frame.selected ~= id then W.CloseOverlays() end
  for _, t in ipairs(tabs) do
    if t.id == id then
      if not t.page.built then
        t.page.built = true
        ns.Safe(t.builder, "tab " .. t.id, t.page)
      end
      t.page:Show()
      pcall(PanelTemplates_SelectTab, t.button)
      paintTab(t.button, true)
      -- The About tab keeps the old wood (Kim); everything else the slate
      local file = UI.ART .. (id == "about" and "Backgrounds\\wood" or UI.BACKGROUND)
      for _, bg in ipairs({ frame.Bg, frame.bgLit }) do
        if bg then bg:SetTexture(file, "REPEAT", "REPEAT") bg:SetHorizTile(true) bg:SetVertTile(true) end
      end
      frame.selected = id
      ns.cfg.windowTab = id
      W.UpdateStrip()
    else
      t.page:Hide()
      pcall(PanelTemplates_DeselectTab, t.button)
      paintTab(t.button, false)
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
      if child ~= badge and child ~= f.advCheck and child ~= f.helpBtn and child ~= f.closeBtn
        and child ~= f.snowLayer
        and child:GetFrameLevel() > top then
        top = child:GetFrameLevel()
      end
    end
    badge:SetFrameLevel(top + 5)
    if f.snowLayer then f.snowLayer:SetFrameLevel(top + 4) end   -- winter: over the border, under the badge
    if f.advCheck then raise(f.advCheck, top + 5) end
    if f.helpBtn then f.helpBtn:SetFrameLevel(top + 5) end
    if f.closeBtn then f.closeBtn:SetFrameLevel(top + 5) end
  end
  badge.Lift = liftBadge
  local icon = badge:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture(UI.ART .. "icon")
  -- Winter (UI/Winter.lua): the snowman ledge resting on the title bar's bottom line (about 22 px
  -- down), mirrored so the tail runs off to the right, its square end tucked behind the badge's
  -- ring (Kim: the cut corner under it left a gap). On its own frame, kept one level under the
  -- badge and over the border (liftBadge)
  if ns.Winter then
    local snowLayer = CreateFrame("Frame", nil, f)
    snowLayer:SetAllPoints(f)
    snowLayer:EnableMouse(false)
    f.snowLayer = snowLayer
    ns.Winter.Piece(snowLayer, "snowman", function(t, seat) t:SetPoint("TOPLEFT", f, "TOPLEFT", 24, seat - 20) end,
      { scale = 0.4, mirror = true })
    -- and a heap in the bottom-left corner, on every tab (the snowflake switch has the right; Kim),
    -- mirrored so its straight side leans on the left border, resting on the bottom border
    ns.Winter.Piece(badge, "corner", function(t, seat) t:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 10, seat + 5) end,
      { scale = 0.55, mirror = true })
  end
  -- Advanced mode, left of the close button (Kim): Places shows the full list and Look editor
  -- Simple | Advanced as a small picker (Kim: two views of the same page)
  local TB = 16   -- the title bar controls (picker, help, close) share one height (Kim)
  local adv = UI.Segmented(f, 132, { height = TB,
    items = function()
      return { { "simple", L["WIN_SIMPLE"], nil, L["WIN_SIMPLE_TIP"] },
               { "advanced", L["SP_ADVANCED"], nil, L["WIN_ADVANCED_TIP"] } }
    end,
    get = function() return ns.cfg.advanced and "advanced" or "simple" end,
    set = function(v) W.SetAdvanced(v == "advanced") end })
  -- Close: our own round title button (UI.TitleButton, Assets/Buttons/tb-x), in the place of the template's
  -- red one (hidden, still the anchor); ESC closes the window as before
  local old = f.CloseButton or _G.DuskfallWindowCloseButton
  -- Right-click: back to the middle of the screen (Kim)
  local close = UI.TitleButton(f, TB + 2, "x", { tip = L["BTN_CLOSE"], tipSub = L["WIN_CLOSE_TIP"], onClick = function() f:FadeHide() end,
    onRightClick = function()
      f:ClearAllPoints()
      f:SetPoint("CENTER")
      ns.cfg.window = nil
    end })
  if old then
    close:SetPoint("CENTER", old, "CENTER", -2, 0)
    old:SetAlpha(0)
    old:EnableMouse(false)
  else
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -4)
  end
  f.closeBtn = close
  -- Help, between Advanced and the close button: the same round title button with a "?"
  local help = UI.TitleButton(f, TB + 2, "help", { tip = L["BTN_HELP"], tipSub = L["WIN_HELP_TIP"],
    onClick = function() if ns.Help then ns.Help.Toggle() end end })
  help:SetPoint("RIGHT", close, "LEFT", -4, 0)
  f.helpBtn = help
  adv:SetPoint("RIGHT", help, "LEFT", -8, 0)
  adv:Refresh()   -- the picker makes its buttons in Refresh
  f.advCheck = adv
  pcall(ButtonFrameTemplate_HideButtonBar, f)
  if ns.CursorLight then ns.CursorLight.Attach(f) end
  if f.Inset then f.Inset:Hide() end
  UI.Wood(f)
  -- The cursor light also catches the wood, the window's border and the logo (Kim; UI/CursorLight.lua)
  -- The border in the icon's ring colours; the light's copies of it get the same tint
  local CL = ns.CursorLight
  if f.NineSlice then
    for key, spec in pairs(PIECES) do
      local t = f.NineSlice[key]
      if t then
        local lit = CL and CL.Copy(t, "edge")
        tintPiece(t, spec)
        tintPiece(lit, spec)
      end
    end
  end
  if CL then
    if f.Bg then f.bgLit = CL.Copy(f.Bg, "fill") end
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
  UI.KeyboardOn(f)   -- in combat: once combat ends
  f:SetScript("OnKeyDown", function(self, key)
    if InCombatLockdown() or key ~= "ESCAPE" then return end
    local t = current()
    local overlayOpen = W.CloseOverlays()
    if overlayOpen or (t and t.page.Back and t.page.Back()) then
      self.escHandled = true   -- not a close (UI.Fader's ESC)
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
  f.strip = strip   -- hidden under overlays (Help, Patch Notes; Kim)
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
  UI.Fader(f, { esc = true })   -- after every SetScript above (it hooks OnShow / OnKeyDown)
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
-- Builds the window and one tab's page without showing either (Kim, 1.3.0: shift-left-click on a
-- launcher opens the mini panel, which lives in the Places tab). false = Duskfall not ready yet.
function W.Prepare(id)
  if not ns.db or not ns.Detect.state.started then return false end
  if not frame then build() end
  for _, t in ipairs(tabs) do
    if t.id == id and t.page and not t.page.built then
      t.page.built = true
      ns.Safe(t.builder, "tab " .. t.id, t.page)
    end
  end
  return true
end

function ns.OpenWindow(tabID, keepOpen)
  if not ns.db or not ns.Detect.state.started then ns.Print(L["SL_NOT_READY"]) return end
  if not frame then build() end
  if tabID then
    -- Same tab already showing: the command closes the window again (a toggle)
    if not keepOpen and frame:IsOpen() and frame.selected == tabID then frame:FadeHide() return end
    W.Select(tabID)
    frame:Show()
  elseif frame:IsOpen() then
    frame:FadeHide()
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
