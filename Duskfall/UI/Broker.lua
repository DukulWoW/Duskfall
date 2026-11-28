-- Duskfall UI/Broker.lua (B-05): the LibDataBroker object (a data source: broker bars show its
-- text, LibDBIcon only the icon), the minimap button (LibDBIcon) and the addon compartment.
-- Clicks, the same everywhere (as planned for the moon icon, C-06):
--   left: the window on Places   shift-left: the mini panel for where you stand (1.3.0)
--   right: Duskfall on / off     shift-right: Settings
-- Broker text (Settings > Display): the Look in effect, the values, both, nothing, or the Light
-- slider's value for here (1.3.0, Kim): then the mouse wheel over it moves that slider, 5% a notch.
-- Bars that pass the wheel on call dataobj.OnMouseWheel (XIV_Databar_Continued); for the others the
-- bar's button gets a wheel script while our tooltip shows on it, only when it has none of its own.
-- Public: ns.ActiveLooks(), ns.StateText(), ns.HereText(), ns.ValuesText(), ns.LauncherClick(button),
--         ns.FillTooltip(tooltip), ns.UpdateMinimapButton(), ns.UpdateBroker()
-- Globals for the TOC: Duskfall_OnAddonCompartmentClick / Enter / Leave
local ADDON, ns = ...
local L = ns.L
local UI, C, D = ns.UI, ns.Channels, ns.Detect

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
local NAME = "Duskfall"   --noloc
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
  if D.state.comparing == "peek" then return L["BR_PEEK"] end
  if not ns.cfg or not ns.cfg.enabled then return L["WIN_OFF"] end
  if D.state.comparing then return L["BR_BEFORE"] end
  if D.state.preview then return L["BR_PREVIEWING"] end
  local names = {}
  for _, look in ipairs(ns.ActiveLooks()) do names[#names + 1] = look.name or "?" end
  if #names == 0 then return L["BR_BASELINE"] end
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
  elseif IsShiftKeyDown() then
    if ns.OpenMiniHere then ns.OpenMiniHere() end
  else
    if ns.OpenWindow then ns.OpenWindow("places") end
  end
end

function ns.FillTooltip(tt)
  tt:AddLine(TITLE)
  if not ns.db or not D.state.started then
    tt:AddLine(L["BR_STARTING"], 0.7, 0.7, 0.7)
    return
  end
  local onoff = "|cff40ff40" .. L["BR_ON"] .. "|r"
  if not ns.cfg.enabled then onoff = "|cffff4040" .. L["WIN_OFF"] .. "|r" end
  tt:AddDoubleLine("Duskfall", onoff,   --noloc
    0.8, 0.8, 0.8)
  tt:AddDoubleLine(L["STYLE_DEFAULT"], ns.Resolver.ActiveStyle().name or "?", 0.8, 0.8, 0.8, 1, 1, 1)
  tt:AddDoubleLine(L["PL_HERE"], ns.HereText(), 0.8, 0.8, 0.8, 1, 1, 1)
  if ns.cfg.enabled then
    tt:AddDoubleLine(L["BR_LOOK"], ns.StateText(), 0.8, 0.8, 0.8, 1, 0.82, 0)
  end
  tt:AddLine(ns.ValuesText(), 1, 1, 1)
  tt:AddLine(" ")
  tt:AddLine(L["BR_LEFT"], 1, 1, 1)
  tt:AddLine(L["BR_SHIFT_LEFT"], 1, 1, 1)
  tt:AddLine(L["BR_RIGHT"], 1, 1, 1)
  tt:AddLine(L["BR_SHIFT_RIGHT"], 1, 1, 1)
end

-- Light from the broker ------------------------------------------------------------------------
local WHEEL_STEP = 0.05
local function lightMode() return ns.cfg and ns.cfg.brokerText == "light" end
local function lightReady()
  return lightMode() and ns.cfg.enabled and D.state.started and D.state.comparing ~= "before"
    and ns.StatusDisplay and ns.StatusDisplay.LightSet ~= nil
end

local function wheel(_, delta)
  if not lightReady() or not delta or delta == 0 then return end
  local SD = ns.StatusDisplay
  local x = SD.LightGet() + (delta > 0 and WHEEL_STEP or -WHEEL_STEP)
  x = math.floor(x / WHEEL_STEP + 0.5) * WHEEL_STEP
  x = math.max(-1, math.min(1, x))
  SD.LightSet(x)
  ns.UpdateBroker()
end

-- Bars that don't pass the wheel on: the button our tooltip is on gets a wheel script of its own
-- (only if it has none), which works only while our tooltip shows there (a bar may reuse the button).
local tipOwner
local hookedTips = {}
local function hookOwner(tt)
  if not lightMode() or not tt or not tt.GetOwner then return end
  local owner = tt:GetOwner()
  tipOwner = owner
  if not hookedTips[tt] then
    hookedTips[tt] = true
    tt:HookScript("OnHide", function() tipOwner = nil end)
  end
  if not owner or owner.duskfallWheel or not owner.EnableMouseWheel or not owner.GetScript then return end
  if owner.IsForbidden and owner:IsForbidden() then return end
  if owner.IsProtected and owner:IsProtected() then return end
  if DBIcon and owner == DBIcon:GetMinimapButton(NAME) then return end   -- the minimap's own wheel
  if owner:GetScript("OnMouseWheel") then return end
  owner.duskfallWheel = true
  pcall(owner.EnableMouseWheel, owner, true)
  pcall(owner.SetScript, owner, "OnMouseWheel", function(self, delta)
    if tipOwner == self then ns.Safe(wheel, "broker wheel", self, delta) end
  end)
end

local obj
if LDB then
  obj = LDB:NewDataObject(NAME, {
    type = "data source",   --noloc
    icon = UI.ART .. "icon",
    label = NAME,
    text = "",
    OnClick = function(_, button) ns.Safe(ns.LauncherClick, "broker click", button) end,
    OnTooltipShow = function(tt)
      ns.Safe(ns.FillTooltip, "broker tooltip", tt)
      if lightReady() then tt:AddLine(L["BR_WHEEL"], 1, 1, 1) end
      tt:AddLine(L["BR_DRAG"], 0.6, 0.6, 0.6)
      ns.Safe(hookOwner, "broker wheel hook", tt)
    end,
    OnMouseWheel = function(frame, delta) ns.Safe(wheel, "broker wheel", frame, delta) end,
  })
end

function ns.UpdateBroker()
  if not obj or not ns.cfg then return end
  local mode = ns.cfg.brokerText or "look"
  local text = ""
  if mode == "look" then text = ns.StateText()
  elseif mode == "values" then text = ns.ValuesText()
  elseif mode == "both" then text = ns.StateText() .. "  " .. ns.ValuesText()
  elseif mode == "light" then
    if not ns.cfg.enabled then text = L["WIN_OFF"]
    elseif ns.StatusDisplay and ns.StatusDisplay.LightGet then
      text = ns.StatusDisplay.LightText(ns.StatusDisplay.LightGet())
    end
  end
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
  if ns.cfg and (ns.cfg.brokerText == "values" or ns.cfg.brokerText == "both") and ns.Transition.IsRunning() then
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
