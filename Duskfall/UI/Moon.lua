-- Duskfall UI/Moon.lua (C-06): the day / night moon on the minimap opens Duskfall.
-- It is not GameTimeFrame but an anonymous child of MinimapCluster.MinimapContainer (made in
-- Blizzard_Minimap/Camelot/Diel.lua), found by its .Background atlas "UI-HUD-Minimap-NightCycle"
-- (A12, fstack). Clicking it does nothing by default, so it takes the minimap button's clicks
-- (ns.LauncherClick) and adds Duskfall's lines under its tooltip. Scripts are hooked, never
-- replaced; settings.moon = false switches it off again (mouse back as it was).
-- Minimap addons may hide, fade or move the moon off screen: M.Usable() checks it can really be
-- seen and clicked, and the minimap button in "auto" mode shows itself when it can't. Checked at
-- login, again after other addons have set up, on every loading screen, when the moon is shown
-- or hidden, and when the Duskfall window opens.
-- Public: ns.Moon.Apply(), ns.Moon.Found(), ns.Moon.Searched(), ns.Moon.Usable(), ns.Moon.Check()
local ADDON, ns = ...
local M = {}
ns.Moon = M

local ATLAS = "ui-hud-minimap-nightcycle"
local moon, hooked, mouseWas
local searched = false     -- the search is over (found or given up)

local function find()
  local host = MinimapCluster and MinimapCluster.MinimapContainer
  if not host or not host.GetChildren then return nil end
  for _, child in ipairs({ host:GetChildren() }) do
    local bg = child.Background
    if bg and bg.GetAtlas then
      local ok, atlas = pcall(bg.GetAtlas, bg)
      if ok and type(atlas) == "string" and atlas:lower() == ATLAS then return child end
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
  if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
end

local function hook()
  if hooked or not moon then return end
  hooked = true
  mouseWas = moon:IsMouseEnabled()
  moon:HookScript("OnMouseUp", function(self, button)
    if not on() or not self:IsMouseOver() then return end
    ns.Safe(ns.LauncherClick, "moon click", button)
  end)
  moon:HookScript("OnEnter", function(self)
    if not on() then return end
    -- Under the moon's own tooltip if it has one, else a tooltip of our own
    if not GameTooltip:IsOwned(self) then
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    else
      GameTooltip:AddLine(" ")
    end
    ns.Safe(ns.FillTooltip, "moon tooltip", GameTooltip)
    GameTooltip:Show()
  end)
  moon:HookScript("OnLeave", function(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
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
      moon:EnableMouse(true)
    elseif hooked then
      moon:EnableMouse(mouseWas and true or false)
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
