-- Duskfall UI/HDR.lua: the HDR tab, right of Styles (Kim, 2026-11-27). Forever's Graphics options
-- have no HDR settings, but the client has the CVars (Kim's probe, 2026-11-27; none protected,
-- all apply at once, the client accepts any value, so the slider ranges are ours):
--   HDROutput            0 / 1      HDR on or off (default 0)
--   HDRPeakBrightness    nits       the screen's peak (default 400), used when useHDRPeakBrightness = 1
--   HDRBrightness        nits       paper white, normal white (default 203), used when useHDRBrightness = 1
--   HDRFactor            0.5 - 3    HDR strength (default 2)
-- RenderFormat is left alone (what its numbers mean is unknown). These are game-wide, not per place.
local ADDON, ns = ...
local L = ns.L
local UI, W = ns.UI, ns.Window

local DEFAULTS = { HDROutput = 0, HDRPeakBrightness = 400, useHDRPeakBrightness = 0, HDRBrightness = 203,
                   useHDRBrightness = 0, HDRFactor = 2 }
local RANGE = { HDRPeakBrightness = { 200, 4000, 50 }, HDRBrightness = { 80, 500, 5 }, HDRFactor = { 0.5, 3, 0.1 } }

local function has(cvar) return C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(cvar) ~= nil end
local function get(cvar) return tonumber(C_CVar.GetCVar(cvar)) end
local function set(cvar, v)
  local r = RANGE[cvar]
  if r then v = math.max(r[1], math.min(r[2], v)) end
  pcall(C_CVar.SetCVar, cvar, tostring(v))
end
local function on(cvar) return (get(cvar) or 0) ~= 0 end

W.AddTab("hdr", "HDR", function(page)
  UI.Glow(page, nil, 0.8)
  local FULL_W = 728
  local title = UI.Label(page, "HDR", "GameFontNormalHuge")   --noloc
  title:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -14)
  local help = UI.HelpIcon(page, "hdr", "HDR", L["HDR_HELP_TIP"])   --noloc
  help:SetPoint("LEFT", title, "RIGHT", 8, 0)
  local intro = UI.Label(page, L["HDR_INTRO"])
  intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  intro:SetWidth(FULL_W)
  intro:SetTextColor(0.7, 0.7, 0.7)

  -- Kim: a plain warning, in red, for players without an HDR screen
  local warn = UI.Label(page, L["HDR_WARN"], "GameFontNormal")
  warn:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -6)
  warn:SetWidth(FULL_W)
  warn:SetTextColor(1, 0.35, 0.3)

  if not has("HDROutput") then
    local none = UI.Label(page, L["HDR_NONE"], "GameFontNormalLarge")
    none:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -30)
    return
  end

  local controls = {}
  local function refresh() for _, c in ipairs(controls) do if c.Refresh then c:Refresh() end end end

  -- HDR output: the big switch
  local top = UI.Card(page, 12, -100, FULL_W, 74)
  local outT = UI.Label(top, L["HDR_OUTPUT"], "GameFontNormalLarge")
  outT:SetPoint("TOPLEFT", top, "TOPLEFT", 16, -14)
  local outD = UI.Label(top, L["HDR_OUTPUT_DESC"])
  outD:SetPoint("TOPLEFT", outT, "BOTTOMLEFT", 0, -6)
  outD:SetTextColor(0.68, 0.68, 0.68)
  local out = UI.Switch(page, { label = "HDR", big = true,   --noloc
    tip = L["HDR_OUTPUT_TIP"],
    get = function() return on("HDROutput") end,
    set = function(v) set("HDROutput", v and 1 or 0) refresh() end })
  out:SetPoint("RIGHT", top, "RIGHT", -24, 0)
  controls[#controls + 1] = out

  -- Brightness
  local SL_W = FULL_W - 32 - 130
  local box = UI.Card(page, 12, -186, FULL_W, 250)
  local bT = UI.Label(box, L["CH_BRIGHTNESS"], "GameFontNormalLarge")
  bT:SetPoint("TOPLEFT", box, "TOPLEFT", 16, -14)
  local bD = UI.Label(box, L["HDR_BOX_DESC"])
  bD:SetPoint("TOPLEFT", bT, "BOTTOMLEFT", 0, -6)
  bD:SetWidth(FULL_W - 32)
  bD:SetTextColor(0.68, 0.68, 0.68)

  local y = -70
  local function row(cvar, useCvar, label, tip, fmt)
    local r = RANGE[cvar]
    local sl = UI.Slider(page, SL_W, { label = label, min = r[1], max = r[2], step = r[3], default = DEFAULTS[cvar],
      fmt = fmt, tip = tip,
      get = function() return get(cvar) or DEFAULTS[cvar] end,
      onChange = function(v) set(cvar, v) end })
    sl:SetPoint("TOPLEFT", box, "TOPLEFT", 16, y)
    controls[#controls + 1] = sl
    if useCvar then
      local use = UI.Check(page, { label = L["HDR_USE"], tip = L["HDR_USE_TIP"],
        get = function() return on(useCvar) end,
        set = function(v)
          set(useCvar, v and 1 or 0)
          sl:SetEnabled(v)
        end })
      use:SetPoint("LEFT", sl, "RIGHT", 24, -6)
      controls[#controls + 1] = use
      local oldRefresh = sl.Refresh
      function sl:Refresh()
        oldRefresh(self)
        self:SetEnabled(on(useCvar))
      end
    end
    y = y - (UI.SLIDER_H + 22)
    return sl, useCvar and controls[#controls] or nil
  end
  local nits = function(v) return L["HDR_NITS"]:format(v) end
  local s1, u1 = row("HDRPeakBrightness", "useHDRPeakBrightness", L["HDR_PEAK"], L["HDR_PEAK_TIP"], nits)
  local s2, u2 = row("HDRBrightness", "useHDRBrightness", L["HDR_PAPER"], L["HDR_PAPER_TIP"], nits)
  local s3 = row("HDRFactor", nil, L["DS_STRENGTH"], L["HDR_FACTOR_TIP"],
    function(v) return string.format("%.1f", v) end)
  -- Kim (1.3.1): "Use it" lines up with the HDR switch's label above (24 from the right edge)
  local useW = math.max(u1:GetWidth(), u2:GetWidth())
  local w = FULL_W - 16 - 24 - useW - 24
  -- (each "Use it" hangs off its own slider's right edge, so it moves with the width)
  for _, sl in ipairs({ s1, s2, s3 }) do sl:SetWidth(w) end

  local reset = UI.Button(page, L["HDR_RESET"], 160, function()
    for k, v in pairs(DEFAULTS) do if k ~= "HDROutput" then set(k, v) end end
    refresh()
  end, 24)
  reset:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -12)
  UI.Tooltip(reset, L["HDR_RESET"], L["HDR_RESET_TIP"])

  page:HookScript("OnShow", refresh)
  refresh()
end)
