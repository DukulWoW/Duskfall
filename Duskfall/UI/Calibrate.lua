-- Duskfall UI/Calibrate.lua: a calibration chart for the baseline (Kim, 2026-11-27; the idea from
-- Advanced Graphics Tuner, made our own). An overlay in the main window (W.NewOverlay) with three
-- strips drawn as plain colours (Gamma, Brightness and Contrast change the interface too, Kim):
--   black level   squares from pure black up to 18/255, on black: Brightness
--   white level   squares from 237/255 up to pure white, on white: Contrast
--   grey ramp     21 even steps from black to white: Gamma
-- and the three baseline sliders. While it is open the screen shows the baseline (D.Calibrate);
-- Save keeps the new baseline, Cancel (or closing) puts the old one back.
-- Public: ns.Calibrate.Open()
local ADDON, ns = ...
local L = ns.L
local UI, W, C, D = ns.UI, ns.Window, ns.Channels, ns.Detect
local CB = {}
ns.Calibrate = CB

local GAME_DEFAULT = { gamma = 1.0, brightness = 50, contrast = 50 }
local STEP = { gamma = 0.01, brightness = 1, contrast = 1 }
local KEYS = { "gamma", "brightness", "contrast" }

local frame, sliders, saved, kept

local function strip(parent, y, label, hint, count, bg, value, numbers)
  local t = UI.Label(parent, label, "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y)
  local h = UI.Label(parent, hint, "GameFontHighlight")
  h:SetPoint("LEFT", t, "RIGHT", 12, -1)
  h:SetTextColor(0.8, 0.78, 0.74)
  local W_ALL, H = 724, 46
  local back = parent:CreateTexture(nil, "ARTWORK")
  back:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y - 26)
  back:SetSize(W_ALL, H)
  local bgv = bg >= 0 and bg or 0   -- the grey steps: no gaps, so no background shows
  back:SetColorTexture(bgv, bgv, bgv, 1)
  local gap = bg >= 0 and 6 or 0
  local w = (W_ALL - gap * (count + 1)) / count
  for i = 1, count do
    local v = value(i)
    local sq = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    sq:SetSize(w, H - 2 * gap)
    sq:SetPoint("TOPLEFT", back, "TOPLEFT", gap + (i - 1) * (w + gap), -gap)
    sq:SetColorTexture(v, v, v, 1)
    if numbers then
      local n = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      n:SetPoint("TOP", sq, "BOTTOM", 0, -gap - 3)
      n:SetText(tostring(i))
      n:SetTextColor(0.6, 0.6, 0.6)
    end
  end
end

local function writeBaseline()
  if ns.db.baseline then C.WriteAll(ns.db.baseline) end
end

local function build()
  local f = W.NewOverlay(L["BL_CALIBRATE"])
  f.closeBtn:SetText(L["BTN_CANCEL"])

  local save = UI.Button(f, L["CAL_SAVE"], 150, function()
    kept = true
    f:FadeHide()
  end)
  save:SetKind("main")
  save:SetPoint("RIGHT", f.closeBtn, "LEFT", -8, 0)
  UI.Tooltip(save, L["CAL_SAVE"], L["CAL_SAVE_TIP"])

  local intro = UI.Label(f, L["CAL_INTRO"])
  intro:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -50)
  intro:SetTextColor(0.7, 0.7, 0.7)

  strip(f, -82, L["CAL_BLACK"], L["CAL_BLACK_TIP"],
    10, 0, function(i) return (i - 1) * 2 / 255 end, true)
  strip(f, -180, L["CAL_WHITE"], L["CAL_WHITE_TIP"],
    10, 1, function(i) return (237 + (i - 1) * 2) / 255 end, true)
  strip(f, -278, L["CAL_GREY"], L["CAL_GREY_TIP"],
    21, -1, function(i) return (i - 1) / 20 end, false)

  -- The sliders, one under the other
  sliders = {}
  for i, k in ipairs(KEYS) do
    local ch = C.byKey[k]
    local g = UI.CHANNEL_GRADIENT[k]
    local sl = UI.LightSlider(f, 724, { label = ch.label, labelW = 90, valueW = 70, min = ch.min, max = ch.max,
      step = STEP[k], mid = GAME_DEFAULT[k], from = g.from, to = g.to,
      fmt = function(v) return C.Format(k, v) end, zero = function() return C.Format(k, GAME_DEFAULT[k]) end,
      tip = L["CAL_RIGHT_CLICK"],
      get = function() return ns.db.baseline and ns.db.baseline[k] or GAME_DEFAULT[k] end,
      set = function(v)
        if not ns.db.baseline then return end
        ns.db.baseline[k] = tonumber(C.Format(k, C.Clamp(k, v)))
        writeBaseline()
      end })
    sl:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -374 - (i - 1) * 38)
    sliders[k] = sl
  end

  f:HookScript("OnShow", function()
    kept = false
    saved = {}
    for k, v in pairs(ns.db.baseline or {}) do saved[k] = v end
    D.Calibrate(true)
    writeBaseline()
    for _, sl in pairs(sliders) do sl:Refresh() end
  end)
  f:HookScript("OnHide", function()
    if not kept and ns.db.baseline then
      for k, v in pairs(saved or {}) do ns.db.baseline[k] = v end
    end
    D.Calibrate(false)
    -- Every setting is a change from the baseline: work the screen out again from the new one
    D.ClearHolds()
    D.state.target = nil
    D.Evaluate("edit")
    W.UpdateStatus()
  end)
  frame = f
end

function CB.Open()
  if not W.frame then return end
  if not frame then build() end
  frame:Show()
end
