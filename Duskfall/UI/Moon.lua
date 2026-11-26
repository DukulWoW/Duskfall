-- Duskfall UI/Moon.lua (C-06): the day / night moon on the minimap opens Duskfall.
-- It is not GameTimeFrame but an anonymous child of MinimapCluster.MinimapContainer (made in
-- Blizzard_Minimap/Camelot/Diel.lua), found by its .Background atlas "UI-HUD-Minimap-NightCycle"
-- (A12, fstack). Clicking it does nothing by default, so it takes the minimap button's clicks
-- (ns.LauncherClick) and adds Duskfall's lines under its tooltip. Hooking the moon's own mouse
-- scripts did nothing on Forever (Kim, 2026-11-26), so an invisible button of our own lies on top
-- of it, one strata up so no minimap frame catches the click first. The moon itself is never
-- changed; settings.moon = false hides the button.
-- Minimap addons may hide, fade or move the moon off screen: M.Usable() checks it can really be
-- seen and clicked, and the minimap button in "auto" mode shows itself when it can't. Checked at
-- login, again after other addons have set up, on every loading screen, when the moon is shown
-- or hidden, and when the Duskfall window opens.
-- Public: ns.Moon.Apply(), ns.Moon.Found(), ns.Moon.Searched(), ns.Moon.Usable(), ns.Moon.Check(),
--         ns.Moon.AddRing(host, anchor, size), ns.Moon.UpdateRings()
local ADDON, ns = ...
local UI = ns.UI
local M = {}
ns.Moon = M

-- The atlas follows the clock: "...-DayCycle" by day, "...-NightCycle" by night (Kim's /dusk moon,
-- 2026-11-26: only the night one was looked for, so by day the moon was never found)
local ATLAS = { ["ui-hud-minimap-daycycle"] = true, ["ui-hud-minimap-nightcycle"] = true }
local moon, hooked, catcher
local searched = false     -- the search is over (found or given up)

local function find()
  local host = MinimapCluster and MinimapCluster.MinimapContainer
  if not host or not host.GetChildren then return nil end
  for _, child in ipairs({ host:GetChildren() }) do
    local bg = child.Background
    if bg and bg.GetAtlas then
      local ok, atlas = pcall(bg.GetAtlas, bg)
      if ok and type(atlas) == "string" and ATLAS[atlas:lower()] then return child end
    end
  end
  return nil
end

local function on() return ns.cfg and ns.cfg.moon ~= false end

-- Shown with all its parents, not faded out, a real size, and somewhere on the screen.
local function seen(region)
  if not region or not region:IsVisible() then return false end
  local a = region.GetEffectiveAlpha and region:GetEffectiveAlpha() or 1
  if a < 0.1 then return false end
  local w, h = region:GetSize()
  if (w or 0) < 6 or (h or 0) < 6 then return false end
  local l, b = region:GetLeft(), region:GetBottom()
  if not l or not b then return false end
  local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
  local s = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
  local cx, cy = (l + w / 2) * s, (b + h / 2) * s
  return cx > 0 and cy > 0 and cx < sw and cy < sh
end

function M.Usable()
  if not moon or not on() then return false end
  return seen(moon) and seen(moon.Background)
end

function M.Found() return moon ~= nil end
function M.Searched() return searched end

-- Tells the minimap button (auto mode) whether the moon can stand in for it.
function M.Check()
  if not searched then return end
  -- Not found at login (the minimap may be built later): look again now
  if not moon then
    moon = find()
    if moon then
      ns.Debug("minimap moon found late")
      M.Apply()
      return
    end
  end
  if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
end

local function describe(f)
  if not f then return "nil" end
  local name = f.GetName and f:GetName()
  local parent = f.GetParent and f:GetParent()
  local pname = parent and parent.GetName and parent:GetName()
  return string.format("%s (parent %s, %s %d, mouse %s, shown %s)", name or "anonymous", pname or "anonymous",
    f.GetFrameStrata and f:GetFrameStrata() or "?", f.GetFrameLevel and f:GetFrameLevel() or -1,
    tostring(f.IsMouseEnabled and f:IsMouseEnabled()), tostring(f.IsVisible and f:IsVisible()))
end

-- /dusk moon: what Duskfall knows about the moon, then (after 3 s, hover the moon) what is under the mouse.
function M.Report()
  ns.Print("moon: searched %s, found %s, usable %s, setting %s.", tostring(searched), tostring(moon ~= nil),
    tostring(M.Usable()), tostring(on()))
  if moon then ns.Print("moon frame: %s", describe(moon)) end
  if catcher then ns.Print("click catcher: %s", describe(catcher)) end
  local host = MinimapCluster and MinimapCluster.MinimapContainer
  if host and host.GetChildren then
    local n = 0
    for _, child in ipairs({ host:GetChildren() }) do
      n = n + 1
      local bg = child.Background
      local atlas = bg and bg.GetAtlas and bg:GetAtlas()
      if atlas then ns.Print("  container child %d: .Background atlas %s", n, tostring(atlas)) end
    end
    ns.Print("  MinimapContainer has %d children.", n)
  else
    ns.Print("  no MinimapCluster.MinimapContainer.")
  end
  ns.Print("hover the moon now: in 3 seconds the frames under the mouse are listed.")
  C_Timer.After(3, function()
    local foci = GetMouseFoci and GetMouseFoci() or {}
    if #foci == 0 then ns.Print("under the mouse: nothing that takes the mouse.") end
    for i, f in ipairs(foci) do ns.Print("under the mouse %d: %s", i, describe(f)) end
  end)
end

-- The glow (Kim): while a setting is in effect where you stand, the sun glare (UI.GlowRing)
-- behind the icon. settings.ringGlow = false switches it off. Used on the moon badge and on the
-- minimap button (UI/Broker.lua).
local rings = {}

local function ringWanted()
  return ns.cfg and ns.cfg.enabled and ns.cfg.ringGlow ~= false and ns.Detect.state.source
    and next(ns.Detect.state.source) ~= nil
end

-- host: the frame it lives on; anchor: the region it centres on; size: its width and height.
function M.AddRing(host, anchor, size)
  local r = UI.GlowRing(host, anchor, size)
  rings[#rings + 1] = r
  r.Set(ringWanted())
  return r
end

function M.UpdateRings()
  local on = ringWanted() and true or false
  for _, r in ipairs(rings) do r.Set(on) end
end
ns.Listen("EVALUATED", function() ns.Safe(M.UpdateRings, "glow ring") end)
ns.Listen("ONOFF", function() ns.Safe(M.UpdateRings, "glow ring") end)

local function hook()
  if hooked or not moon then return end
  hooked = true
  catcher = CreateFrame("Button", nil, moon)
  catcher:SetAllPoints(moon)
  catcher:SetFrameStrata("MEDIUM")
  catcher:RegisterForClicks("AnyUp")
  -- A tiny Duskfall icon on the moon's lower right: the moon opens Duskfall (Kim). On the catcher,
  -- so it shows and hides with the takeover.
  local badge = catcher:CreateTexture(nil, "OVERLAY")
  badge:SetSize(15, 15)
  badge:SetTexture(UI.ART .. "icon")
  -- It goes round the moon's rim like the hour hand of a clock (Kim): 12 at the top, 3 on the
  -- right, 6 at the bottom, 9 on the left; 3 at night sits where 3 in the afternoon does. Same
  -- clock as Duskfall's own (server or local).
  local disc = moon.Background or catcher
  local function place()
    local env = ns.Situations.Snapshot()
    local a = ((env.hour % 12) + env.min / 60) / 12 * 2 * math.pi
    local r = math.max(8, (disc:GetWidth() or 30) / 2 + 1)   -- centred just outside the rim (Kim)
    badge:ClearAllPoints()
    badge:SetPoint("CENTER", disc, "CENTER", r * math.sin(a), r * math.cos(a))
  end
  -- Behind it, the glow ring while a setting is in effect where you stand (M.AddRing)
  M.AddRing(catcher, badge, 36)
  -- Grey while Duskfall is off (Kim)
  local function dim() badge:SetDesaturated(not ns.cfg.enabled) end
  dim()
  ns.Listen("ONOFF", function() ns.Safe(dim, "moon badge") end)
  M.PlaceBadge = place
  place()
  C_Timer.NewTicker(30, function()
    if catcher:IsVisible() then ns.Safe(place, "moon badge") end
  end)
  catcher:HookScript("OnShow", function() ns.Safe(place, "moon badge") end)
  catcher:SetScript("OnClick", function(_, button)
    ns.Debug("moon click %s", tostring(button))
    ns.Safe(ns.LauncherClick, "moon click", button)
  end)
  catcher:SetScript("OnEnter", function(self)
    -- The moon's own tooltip first, if it has one, then Duskfall's lines
    local own = moon:GetScript("OnEnter")
    if own then pcall(own, moon) end
    if GameTooltip:IsOwned(moon) and GameTooltip:IsShown() then
      GameTooltip:AddLine(" ")
    else
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    end
    ns.Safe(ns.FillTooltip, "moon tooltip", GameTooltip)
    GameTooltip:Show()
  end)
  catcher:SetScript("OnLeave", function(self)
    local own = moon:GetScript("OnLeave")
    if own then pcall(own, moon) end
    if GameTooltip:IsOwned(self) or GameTooltip:IsOwned(moon) then GameTooltip:Hide() end
  end)
  -- A minimap addon hiding or showing it: look again on the next frame (after its layout)
  local again = function() C_Timer.After(0, function() ns.Safe(M.Check, "moon check") end) end
  moon:HookScript("OnShow", again)
  moon:HookScript("OnHide", again)
end

function M.Apply()
  if moon then
    if on() then
      hook()
      catcher:Show()
    elseif catcher then
      catcher:Hide()
    end
  end
  M.Check()
end

-- The minimap is built by a Blizzard addon: look at login, and again a little later.
local tries = 0
local function look()
  tries = tries + 1
  moon = moon or find()
  if moon or tries >= 4 then
    searched = true
    ns.Debug(moon and "minimap moon found" or "minimap moon not found")
    M.Apply()
    -- Other minimap addons set up during login: check once more when they are done
    C_Timer.After(3, function() ns.Safe(M.Check, "moon check") end)
  else
    C_Timer.After(2 * tries, function() ns.Safe(look, "moon") end)
  end
end
ns.Listen("ENABLE", look)
ns.On("PLAYER_ENTERING_WORLD", function()
  C_Timer.After(1, function() ns.Safe(M.Check, "moon check") end)
end)
