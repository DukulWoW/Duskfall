-- Duskfall UI/Window.lua: the settings window. ButtonFrameTemplate (Forever draws its own metal
-- frame on it), the wood background and glow from Kahoof, four top tabs, and a status strip that
-- shows what Duskfall is doing right now. Built on first open.
-- Tabs register through W.AddTab(name, builder); builder(page) runs once, page:OnShow refreshes.
-- Public: ns.OpenWindow(), W.AddTab(id, title, builder), W.Select(id), W.frame
local ADDON, ns = ...
local W = {}
ns.Window = W
local UI, C = ns.UI, ns.Channels

local WIDTH, HEIGHT = 780, 560
local tabs = {}          -- { id, title, builder, page, button }
local frame

function W.AddTab(id, title, builder)
  tabs[#tabs + 1] = { id = id, title = title, builder = builder }
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
    if st.held[ch.key] ~= nil then s = "|cffff9f40" .. s .. "|r"
    elseif st.source and st.source[ch.key] then s = "|cffffd100" .. s .. "|r" end
    vals[#vals + 1] = s
  end
  local onoff = ""
  if not ns.cfg.enabled then onoff = "|cffff4040Off|r   " end
  return string.format("%sStyle: |cffffffff%s|r     Here: |cffffffff%s|r     %s", onoff, style.name or "?", place,
    table.concat(vals, "  "))
end

function W.UpdateStatus()
  if frame and frame:IsShown() then frame.status:SetText(statusText()) end
end

function W.Select(id)
  for i, t in ipairs(tabs) do
    if t.id == id then
      if not t.page.built then
        t.page.built = true
        ns.Safe(t.builder, "tab " .. t.id, t.page)
      end
      t.page:Show()
      PanelTemplates_SetTab(frame, i)
      frame.selected = id
      ns.cfg.windowTab = id
    else
      t.page:Hide()
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
  if f.SetTitle then f:SetTitle("Duskfall")
  elseif f.TitleContainer and f.TitleContainer.TitleText then f.TitleContainer.TitleText:SetText("Duskfall") end
  local portrait = (f.PortraitContainer and f.PortraitContainer.portrait) or f.portrait
  if portrait then portrait:SetTexture(UI.ART .. "icon") end
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

  -- Tabs
  local prev
  for i, t in ipairs(tabs) do
    local b = CreateFrame("Button", "DuskfallWindowTab" .. i, f, "PanelTopTabButtonTemplate")
    b:SetText(t.title)
    b:SetID(i)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
    else b:SetPoint("TOPLEFT", f, "TOPLEFT", 64, -26) end
    b:SetScript("OnClick", function() W.Select(t.id) end)
    pcall(PanelTemplates_TabResize, b, 12)
    t.button = b
    prev = b

    local page = CreateFrame("Frame", nil, f)
    page:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -64)
    page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 34)
    page:Hide()
    t.page = page
  end
  f.Tabs = {}
  for i, t in ipairs(tabs) do f.Tabs[i] = t.button end
  PanelTemplates_SetNumTabs(f, #tabs)

  -- Status strip
  local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 12)
  status:SetPoint("RIGHT", f, "RIGHT", -16, 0)
  status:SetJustifyH("LEFT")
  status:SetWordWrap(false)
  f.status = status

  f:SetScript("OnShow", function() W.UpdateStatus() end)
  W.Select(ns.cfg.windowTab or tabs[1].id)
  if not f.selected then W.Select(tabs[1].id) end
  -- A new frame starts shown: hide it, or the first toggle below hides it again (two clicks to open)
  f:Hide()
end

function ns.OpenWindow()
  if not ns.db or not ns.Detect.state.started then ns.Print("not ready yet.") return end
  if not frame then build() end
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
    W.UpdateStatus()
  end
end

ns.Listen("EVALUATED", function() W.UpdateStatus() end)
-- Values move during a transition: keep the strip current while it runs.
C_Timer.NewTicker(0.25, function()
  if frame and frame:IsShown() and ns.Transition.IsRunning() then W.UpdateStatus() end
end)
