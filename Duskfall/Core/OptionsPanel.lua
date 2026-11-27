-- Duskfall OptionsPanel.lua: the ESC > Options > AddOns entry (same pattern as BigNoteBox and
-- BigChatBox): logo, name, version, "by Dukul" and an "Open Settings" button.
-- Until the settings window exists (B-04) the button prints the command list and closes Options.
-- Also the key bindings (Bindings.xml): toggle Duskfall on / off, hold to see before.
local ADDON, ns = ...

-- Key bindings need globals: the header, the label and the function Bindings.xml calls.
BINDING_HEADER_DUSKFALL = "Duskfall"
BINDING_NAME_DUSKFALL_TOGGLE = "Toggle Duskfall on/off"
BINDING_NAME_DUSKFALL_COMPARE = "Hold to see before (your own settings)"

-- runOnUp: keystate is "down" while pressed, "up" when let go
function Duskfall_Compare(keystate)
  if ns.Detect then ns.Detect.Compare(keystate == "down") end
end

function Duskfall_ToggleEnabled()
  if not ns.db or not ns.Detect.state.started then return end
  local on = not ns.cfg.enabled
  ns.Detect.SetEnabled(on)
  if on then ns.Print("on.") else ns.Print("off; your baseline is back.") end
end

local function openSettings()
  if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
  if ns.OpenWindow then ns.OpenWindow("settings", true) end
end
ns.OpenSettings = openSettings

local function create()
  if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
  local panel = CreateFrame("Frame", "DuskfallOptionsPanel", UIParent)
  panel.name = "Duskfall"

  local logo = panel:CreateTexture(nil, "ARTWORK")
  logo:SetSize(128, 128)
  logo:SetPoint("CENTER", panel, "CENTER", 0, 80)
  logo:SetTexture("Interface\\AddOns\\Duskfall\\Assets\\icon")

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge3")
  title:SetPoint("TOP", logo, "BOTTOM", 0, -8)
  title:SetText("Duskfall")

  local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  version:SetPoint("TOP", title, "BOTTOM", 0, -4)
  version:SetText("Version " .. ns.VERSION)
  version:SetTextColor(0.7, 0.7, 0.7)

  local author = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  author:SetPoint("TOP", version, "BOTTOM", 0, -2)
  author:SetText("by Dukul")
  author:SetTextColor(0.55, 0.55, 0.55)

  local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  hint:SetPoint("TOP", author, "BOTTOM", 0, -10)
  hint:SetText("Gamma, brightness, contrast and bloom for every place. Type /dusk for status.")

  local btn = CreateFrame("Button", nil, panel, "SharedButtonLargeTemplate")
  btn:SetSize(300, 60)
  btn:SetPoint("TOP", hint, "BOTTOM", 0, -16)
  btn:SetText("Open Settings")
  pcall(DynamicResizeButton_Resize, btn)
  btn:SetScript("OnClick", function() ns.Safe(openSettings, "options") end)

  local cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
  Settings.RegisterAddOnCategory(cat)
  ns.settingsCategory = cat
end

ns.On("ADDON_LOADED", function(name)
  if name == ADDON then create() end
end)
