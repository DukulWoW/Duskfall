-- Duskfall UI/Broker.lua (B-05): the LibDataBroker object (a data source: broker bars show its
-- text, LibDBIcon only the icon), the minimap button (LibDBIcon) and the addon compartment.
-- Clicks, the same everywhere (as planned for the moon icon, C-06):
--   left: the window on Places   right: Duskfall on / off   shift-right: Settings
-- Broker text (Settings > Display): the Look in effect, the values, both, or nothing.
-- Public: ns.ActiveLooks(), ns.StateText(), ns.HereText(), ns.ValuesText(), ns.LauncherClick(button),
--         ns.FillTooltip(tooltip), ns.UpdateMinimapButton(), ns.UpdateBroker()
-- Globals for the TOC: Duskfall_OnAddonCompartmentClick / Enter / Leave
local ADDON, ns = ...
local UI, C, D = ns.UI, ns.Channels, ns.Detect

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
local NAME = "Duskfall"
local TITLE = "|cff9fb4ffDuskfall|r"

-- The Looks that set a channel right now, in channel order, each once.
function ns.ActiveLooks()
  local out, seen = {}, {}
  local src = D.state.source or {}
  for _, ch in ipairs(C.list) do
    local look = src[ch.key]
    if look and not seen[look] then
      seen[look] = true
      out[#out + 1] = look
    end
  end
  return out
end

-- "Off", "Previewing", the names of the Looks in effect, or "Baseline".
function ns.StateText()
  if not ns.cfg or not ns.cfg.enabled then return "Off" end
  if D.state.preview then return "Previewing" end
  local names = {}
  for _, look in ipairs(ns.ActiveLooks()) do names[#names + 1] = look.name or "?" end
  if #names == 0 then return "Baseline" end
  return table.concat(names, " + ")
end

function ns.HereText()
  local env = D.state.env
  if not env then return "?" end
  if env.instance then return env.instanceName or "?" end
  if env.sub then return (env.zoneName or "?") .. " > " .. env.sub end
  return env.zoneName or "?"
end

-- "G 1.40  B 48  C 65  Bl 1.00" from the values on screen.
function ns.ValuesText()
  local cur = C.ReadAll() or {}
  local out = {}
  for _, ch in ipairs(C.list) do
    local v = cur[ch.key]
    out[#out + 1] = ch.short .. " " .. (v and C.Format(ch.key, v) or "-")
  end
  return table.concat(out, "  ")
end

function ns.LauncherClick(button)
  if not ns.db or not D.state.started then return end
  if button == "RightButton" then
    if IsShiftKeyDown() then
      if ns.OpenWindow then ns.OpenWindow("settings", true) end
    else
      Duskfall_ToggleEnabled()
    end
  else
    if ns.OpenWindow then ns.OpenWindow("places") end
  end
end

function ns.FillTooltip(tt)
  tt:AddLine(TITLE)
  if not ns.db or not D.state.started then
    tt:AddLine("Starting...", 0.7, 0.7, 0.7)
    return
  end
  local onoff = "|cff40ff40On|r"
  if not ns.cfg.enabled then onoff = "|cffff4040Off|r" end
  tt:AddDoubleLine("Duskfall", onoff, 0.8, 0.8, 0.8)
  tt:AddDoubleLine("Style", ns.Resolver.ActiveStyle().name or "?", 0.8, 0.8, 0.8, 1, 1, 1)
  tt:AddDoubleLine("Here", ns.HereText(), 0.8, 0.8, 0.8, 1, 1, 1)
  if ns.cfg.enabled then
    tt:AddDoubleLine("Look", ns.StateText(), 0.8, 0.8, 0.8, 1, 0.82, 0)
  end
  tt:AddLine(ns.ValuesText(), 1, 1, 1)
  tt:AddLine(" ")
  tt:AddLine("Left-click: open Duskfall", 1, 1, 1)
  tt:AddLine("Right-click: switch on or off", 1, 1, 1)
  tt:AddLine("Shift-right-click: settings", 1, 1, 1)
end

local obj
if LDB then
  obj = LDB:NewDataObject(NAME, {
    type = "data source",
    icon = UI.ART .. "icon",
    label = NAME,
    text = "",
    OnClick = function(_, button) ns.Safe(ns.LauncherClick, "broker click", button) end,
    OnTooltipShow = function(tt)
      ns.Safe(ns.FillTooltip, "broker tooltip", tt)
      tt:AddLine("Drag to move the minimap button.", 0.6, 0.6, 0.6)
    end,
  })
end

function ns.UpdateBroker()
  if not obj or not ns.cfg then return end
  local mode = ns.cfg.brokerText or "look"
  local text = ""
  if mode == "look" then text = ns.StateText()
  elseif mode == "values" then text = ns.ValuesText()
  elseif mode == "both" then text = ns.StateText() .. "  " .. ns.ValuesText() end
  obj.text = text
end

-- settings.minimapButton: "auto" (only when the minimap moon can't be used, see UI/Moon.lua),
-- "always" or "never". Until the moon search is done, auto keeps the button hidden.
function ns.UpdateMinimapButton()
  local m = ns.cfg.minimapButton or "auto"
  local show = m == "always" or (m == "auto" and ns.Moon and not ns.Moon.Usable() and ns.Moon.Searched())
  ns.cfg.minimap.hide = not show
  if not DBIcon then return end
  if show then DBIcon:Show(NAME) else DBIcon:Hide(NAME) end
end

ns.Listen("READY", function()
  local m = ns.cfg.minimapButton or "auto"
  ns.cfg.minimap.hide = m ~= "always"
  if DBIcon and obj then
    DBIcon:Register(NAME, obj, ns.cfg.minimap)
    -- The same glow ring as the moon badge, behind the button's icon
    local btn = DBIcon:GetMinimapButton(NAME)
    if btn and ns.Moon and ns.Moon.AddRing then ns.Moon.AddRing(btn, btn.icon or btn, 40) end
    -- Its icon grey while Duskfall is off (Kim)
    if btn and btn.icon then
      local function dim() btn.icon:SetDesaturated(not ns.cfg.enabled) end
      dim()
      ns.Listen("ONOFF", function() ns.Safe(dim, "minimap button") end)
    end
  end
end)
ns.Listen("EVALUATED", function() ns.UpdateBroker() end)
ns.Listen("ONOFF", function() ns.UpdateBroker() end)

-- Values move during a transition: keep "values" broker text current (only in that mode).
C_Timer.NewTicker(0.5, function()
  if ns.cfg and ns.cfg.brokerText ~= "look" and ns.cfg.brokerText ~= "none" and ns.Transition.IsRunning() then
    ns.UpdateBroker()
  end
end)

-- Addon compartment (TOC: AddonCompartmentFunc / FuncOnEnter / FuncOnLeave) -------------------
function Duskfall_OnAddonCompartmentClick(_, button)
  ns.Safe(ns.LauncherClick, "compartment", button)
end

function Duskfall_OnAddonCompartmentEnter(_, frame)
  GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
  ns.Safe(ns.FillTooltip, "compartment tooltip", GameTooltip)
  GameTooltip:Show()
end

function Duskfall_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end
