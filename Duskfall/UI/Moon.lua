-- Duskfall UI/Moon.lua (C-06): the day / night moon on the minimap opens Duskfall.
-- It is not GameTimeFrame but an anonymous child of MinimapCluster.MinimapContainer (made in
-- Blizzard_Minimap/Camelot/Diel.lua), found by its .Background atlas "UI-HUD-Minimap-NightCycle"
-- (A12, fstack). Clicking it does nothing by default, so it takes the minimap button's clicks
-- (ns.LauncherClick) and adds Duskfall's lines under its tooltip. Scripts are hooked, never
-- replaced; settings.moon = false switches it off again (mouse back as it was).
-- Public: ns.Moon.Apply(), ns.Moon.Found()
local ADDON, ns = ...
local M = {}
ns.Moon = M

local ATLAS = "ui-hud-minimap-nightcycle"
local moon, hooked, mouseWas

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
end

function M.Apply()
  if not moon then return end
  if on() then
    hook()
    moon:EnableMouse(true)
  elseif hooked then
    moon:EnableMouse(mouseWas and true or false)
  end
end

function M.Found() return moon ~= nil end

-- The minimap is built by a Blizzard addon: look at login, and again a little later.
local tries = 0
local function look()
  tries = tries + 1
  moon = moon or find()
  if moon then
    M.Apply()
    ns.Debug("minimap moon found")
  elseif tries < 4 then
    C_Timer.After(2 * tries, function() ns.Safe(look, "moon") end)
  else
    ns.Debug("minimap moon not found")
  end
end
ns.Listen("ENABLE", look)
