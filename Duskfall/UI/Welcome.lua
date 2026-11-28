-- Duskfall UI/Welcome.lua: a small welcome on the first login after a new install (Kim, 2026-11-26:
-- "nothing fancy"). Shown once, a few seconds after login, then db.welcomed is set; tables from
-- before v3 count as welcomed (Core.lua migration). /dusk welcome shows it again.
-- Public: ns.Welcome.Show()
local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local WL = {}
ns.Welcome = WL

local Y = "|cffffd100"
local DELAY = 4   -- seconds after login, so it does not land in the loading-screen rush
local frame

local function build()
  local f = CreateFrame("Frame", "DuskfallWelcome", UIParent)
  f:SetSize(480, 276)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  -- As the main window (Kim): the slate, cut round (Assets/round-rect-mask, made for this 2:1
  -- panel), at its own scale; the thin border sweeping gold to blue
  local slate = f:CreateTexture(nil, "BACKGROUND", nil, 0)
  slate:SetAllPoints()
  slate:SetTexture(UI.ART .. UI.BACKGROUND)
  slate:SetTexCoord(0, 480 / 512, 0, 276 / 512)
  local cut = f:CreateMaskTexture()
  cut:SetAllPoints()
  cut:SetTexture(UI.ART .. "Shapes\\round-rect-mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  slate:AddMaskTexture(cut)
  if ns.CursorLight then
    local lit = ns.CursorLight.Copy(slate, "fill")
    if lit then lit:AddMaskTexture(cut) end
  end
  UI.RoundBox(f, { radius = 12, bottom = { 0, 0, 0, 0 }, top = { 0, 0, 0, 0 },
    border = { 1, 0.82, 0, 0.85 }, sweep = true })
  -- The round icon half out of the top-left corner, as on the main window
  local badge = CreateFrame("Frame", nil, f)
  badge:SetSize(56, 56)
  badge:SetPoint("TOPLEFT", f, "TOPLEFT", -16, 16)
  badge:SetFrameLevel(f:GetFrameLevel() + 10)
  local icon = badge:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture(UI.ART .. "icon")

  local title = UI.Label(f, L["WL_TITLE"], "GameFontNormalHuge")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 52, -16)
  local body = UI.Label(f, L["WL_BODY"], "GameFontHighlight")
  body:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -58)
  body:SetPoint("RIGHT", f, "RIGHT", -20, 0)
  body:SetJustifyV("TOP")
  body:SetSpacing(2)
  body:SetTextColor(0.9, 0.88, 0.84)

  -- The starter Style (Kim): off unless ticked; used when the welcome is closed either way
  local starter = UI.Check(f, { label = L["WL_STARTER"], tip = L["WL_STARTER_TIP"] })
  starter:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 50)
  local function takeStarter()
    if starter:GetChecked() and ns.AddonImport then
      starter:SetChecked(false, true)
      ns.AddonImport.AddStarter(false)
    end
  end
  local open = UI.Button(f, L["WL_OPEN"], 140, function()
    takeStarter()
    f:FadeHide()
    if ns.OpenWindow then ns.OpenWindow("places", true) end
  end, 26)
  open:SetKind("main")
  open:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
  local later = UI.Button(f, L["WL_LATER"], 90, function() takeStarter() f:FadeHide() end, 26)
  later:SetPoint("RIGHT", open, "LEFT", -8, 0)

  -- The About tab's link buttons (sites and bug reports), bottom left (Kim)
  local SZ, GAP = 28, 8
  local n = 0
  for _, l in ipairs(ns.LINKS or {}) do
    if l.url then
      local b = UI.IconButton(f, SZ, l.key, {
        tip = l.name, tipSub = l.sub or L["LINK_COPY"]:format(l.name),
        onClick = function(self) UI.Copy(l.name, l.url, self) end,
      })
      b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16 + n * (SZ + GAP), 13)
      n = n + 1
    end
  end

  tinsert(UISpecialFrames, "DuskfallWelcome")
  if ns.CursorLight then ns.CursorLight.Attach(f) end
  UI.Fader(f, { esc = true })
  f:Hide()
  f.takeStarter = takeStarter
  frame = f
end

-- The arrow (Kim, 1.3.0): while the welcome shows, a gold arrow bobs next to the minimap's Day/Night
-- indicator (or Duskfall's minimap button when the indicator can't be used; nothing when neither
-- shows) with a small label. Clicking the label or the arrow opens Help on the indicator page and
-- closes the welcome; it goes with the welcome, or when the indicator / button is clicked.
-- The Help page about the indicator shows it too (WL.Point), with a shorter label ("help" mode).
-- Players who had Duskfall before 1.3.0 never see the welcome: they get the arrow once on their
-- next login ("news" mode; db.indicatorShown), gone after NEWS_SECONDS if not clicked (Kim).
local pointer
local BOB, BOB_SPEED = 7, 4.5   -- px the arrow moves to and fro, and how fast
local NEWS_SECONDS = 60

local function target()
  if ns.Moon and ns.Moon.Usable() then return ns.Moon.Disc() end
  local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
  local b = DBIcon and DBIcon:GetMinimapButton("Duskfall")   --noloc
  if b and b:IsVisible() then return b end
  return nil
end

local function hidePointer()
  if pointer and pointer:IsShown() then pointer:FadeHide() end
end
local function hideIf(mode)
  if pointer and pointer.mode == mode then hidePointer() end
end

local function buildPointer()
  local p = CreateFrame("Button", nil, UIParent)
  p:SetFrameStrata("DIALOG")
  p:SetFrameLevel(60)
  p:SetClampedToScreen(true)
  p:RegisterForClicks("LeftButtonUp")
  local arrow = p:CreateTexture(nil, "OVERLAY")
  arrow:SetSize(34, 34)
  arrow:SetTexture(UI.ART .. "Shapes\\arrow")
  arrow:SetVertexColor(1, 0.82, 0)
  local box = CreateFrame("Frame", nil, p)
  box:SetWidth(236)
  UI.RoundBox(box, { radius = 10, bottom = { 0.03, 0.02, 0.01, 0.92 }, top = { 0.14, 0.11, 0.07, 0.92 },
    border = { 1, 0.82, 0, 0.85 }, sweep = true })
  local head = UI.Label(box, L["WL_POINT"], "GameFontNormal")
  -- Fixed widths, so the wrapped height is known before the box is laid out (Kim's screenshot: the
  -- second line ran out of the box)
  local TEXT_W = 236 - 24
  head:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -10)
  head:SetWidth(TEXT_W)
  local sub = UI.Label(box, L["WL_POINT_SUB"], "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -4)
  sub:SetWidth(TEXT_W)
  sub:SetJustifyH("LEFT")
  sub:SetSpacing(2)
  sub:SetTextColor(0.85, 0.83, 0.78)
  local hl = box:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", 3, -3)
  hl:SetPoint("BOTTOMRIGHT", -3, 3)
  hl:SetColorTexture(1, 1, 1, 0.05)
  p.arrow, p.box, p.head, p.sub = arrow, box, head, sub

  -- Lay it out on the side of the target that has room; the arrow points at the target.
  function p.Aim(t, mode)
    p.mode = mode
    local help = mode == "help"
    head:SetText(help and L["WL_POINT_HERE"] or L["WL_POINT"])
    sub:SetShown(not help)
    local hh, sh = head:GetStringHeight() or 14, sub:GetStringHeight() or 28
    local h = help and (hh + 22) or math.max(48, hh + 4 + sh + 26)
    box:SetHeight(h)
    p:SetSize(236 + 40, h)
    local left = (t:GetCenter() or 0) * t:GetEffectiveScale() > UIParent:GetWidth() * UIParent:GetEffectiveScale() / 2
    arrow:ClearAllPoints()
    box:ClearAllPoints()
    if left then
      arrow:SetRotation(0)
      arrow:SetPoint("RIGHT", p, "RIGHT", 0, 0)
      box:SetPoint("RIGHT", arrow, "LEFT", 2, 0)
    else
      arrow:SetRotation(math.pi)
      arrow:SetPoint("LEFT", p, "LEFT", 0, 0)
      box:SetPoint("LEFT", arrow, "RIGHT", -2, 0)
    end
    p.target, p.left = t, left
    p.hideAt = mode == "news" and (GetTime() + NEWS_SECONDS) or nil
  end
  local clock = 0
  p:SetScript("OnUpdate", function(self, dt)
    clock = clock + dt
    local t = self.target
    if not t or not t:IsVisible() then self:Hide() return end
    if self.hideAt and GetTime() > self.hideAt then
      self.hideAt = nil
      self:FadeHide()
    end
    local x = 4 + BOB * (0.5 + 0.5 * math.sin(clock * BOB_SPEED))
    self:ClearAllPoints()
    if self.left then self:SetPoint("RIGHT", t, "LEFT", -x, 0)
    else self:SetPoint("LEFT", t, "RIGHT", x, 0) end
  end)
  p:SetScript("OnClick", function(self)
    if self.mode == "help" then hidePointer() return end   -- Help is open on that page already
    if frame and frame:IsShown() then
      if frame.takeStarter then frame.takeStarter() end
      frame:FadeHide()
    end
    hidePointer()
    if ns.OpenWindow then ns.OpenWindow("places", true) end
    if ns.Help and ns.Help.Open then ns.Help.Open("indicator") end
  end)
  UI.Fader(p, {})
  p:Hide()
  -- Clicking the indicator or the button itself: the arrow has done its job
  hooksecurefunc(ns, "LauncherClick", function() ns.Safe(hidePointer, "welcome arrow") end)
  pointer = p
end

local function showPointer()
  if not frame or not frame:IsShown() then return end
  local t = target()
  if not t then return end
  if not pointer then buildPointer() end
  pointer.Aim(t, "welcome")
  C_Timer.After(0, function() if pointer:IsShown() then pointer.Aim(t, "welcome") end end)   -- text measured again
  pointer:Show()
end

-- Once for players from before 1.3.0 (they never see the welcome); only marked as shown when it
-- could point at something
local function showNews()
  if not ns.db or ns.db.indicatorShown or InCombatLockdown() then return end
  if frame and frame:IsShown() then return end
  local t = target()
  if not t then return end
  ns.db.indicatorShown = true
  if not pointer then buildPointer() end
  pointer.Aim(t, "news")
  C_Timer.After(0, function() if pointer:IsShown() then pointer.Aim(t, "news") end end)
  pointer:Show()
end

-- Help's indicator page (UI/Help.lua): on = show the arrow there, off = take it away again.
function WL.Point(on)
  if not on then hideIf("help") return end
  if frame and frame:IsShown() then return end   -- the welcome's own arrow is up
  local t = target()
  if not t then return end
  if not pointer then buildPointer() end
  pointer.Aim(t, "help")
  C_Timer.After(0, function() if pointer:IsShown() then pointer.Aim(t, "help") end end)
  pointer:Show()
end

function WL.Show()
  if not frame then
    build()
    frame:HookScript("OnHide", function() ns.Safe(hideIf, "welcome arrow", "welcome") end)
  end
  frame:Show()
  if ns.db then ns.db.welcomed, ns.db.indicatorShown = true, true end
  -- A moment later: the minimap may still be settling after login
  C_Timer.After(0.4, function() ns.Safe(showPointer, "welcome arrow") end)
end

ns.Listen("ENABLE", function()
  if not ns.db then return end
  if ns.db.welcomed then
    -- After the update toast and the minimap have settled
    if not ns.db.indicatorShown then C_Timer.After(DELAY + 4, function() ns.Safe(showNews, "news arrow") end) end
    return
  end
  C_Timer.After(DELAY, function()
    if ns.db and not ns.db.welcomed and not InCombatLockdown() then WL.Show() end
  end)
end)
