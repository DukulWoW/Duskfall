-- Duskfall UI/CursorLight.lua: a soft warm light that follows the mouse over Duskfall's own windows
-- (the main window, the mini panel, the welcome; Kim, 2026-11-26). Idea from Hoverlight, written
-- from scratch (Hoverlight is GPL; nothing of its code or art is used). Two additive layers of
-- Assets/cursor-light (our own radial falloff): a wide faint glow and a small brighter core, kept
-- inside the window (a clipping frame), breathing a little. Fades in when the mouse comes over the
-- window and out when it leaves. Its OnUpdate runs only while the window is shown.
-- settings.cursorLight = false switches it off, settings.cursorLightStrength scales it (Settings > Display).
-- Public: ns.CursorLight.Attach(window)
local ADDON, ns = ...
local UI = ns.UI
local CL = {}
ns.CursorLight = CL

local WIDE, CORE = 300, 110          -- sizes of the two layers
local WIDE_A, CORE_A = 0.17, 0.14    -- their strength at full light
local FADE = 0.25                    -- seconds to fade in or out
local BREATH = 1.6                   -- radians a second (about 4 s a breath)
local LEVEL_UP = 400                 -- above everything in the window, the border included

local function on() return not ns.cfg or ns.cfg.cursorLight ~= false end

function CL.Attach(win)
  if not win or win.duskLight then return end
  local clip = CreateFrame("Frame", nil, win)
  clip:SetAllPoints(win)
  pcall(clip.SetClipsChildren, clip, true)
  clip:EnableMouse(false)
  clip:SetFrameLevel(math.min(9000, win:GetFrameLevel() + LEVEL_UP))
  win.duskLight = clip

  local function layer(size, r, g, b)
    local t = clip:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetTexture(UI.ART .. "cursor-light")
    t:SetBlendMode("ADD")
    t:SetSize(size, size)
    t:SetVertexColor(r, g, b)
    t:Hide()
    return t
  end
  local wide = layer(WIDE, 1, 0.82, 0.5)
  local core = layer(CORE, 1, 0.93, 0.78)

  local level, clock = 0, 0
  clip:SetScript("OnUpdate", function(_, dt)
    clock = clock + dt
    local want = (on() and win:IsMouseOver()) and 1 or 0
    if level < want then level = math.min(1, level + dt / FADE)
    elseif level > want then level = math.max(0, level - dt / FADE) end
    if level <= 0 then
      if wide:IsShown() then wide:Hide() core:Hide() end
      return
    end
    local scale = win:GetEffectiveScale()
    local x, y = GetCursorPosition()
    local left, bottom = win:GetLeft(), win:GetBottom()
    if not (scale and x and left and bottom) then return end
    x, y = x / scale - left, y / scale - bottom
    wide:ClearAllPoints()
    wide:SetPoint("CENTER", win, "BOTTOMLEFT", x, y)
    core:ClearAllPoints()
    core:SetPoint("CENTER", win, "BOTTOMLEFT", x, y)
    local breath = 0.92 + 0.08 * math.sin(clock * BREATH)
    local k = level * breath * (tonumber(ns.cfg and ns.cfg.cursorLightStrength) or 1)
    wide:SetAlpha(math.min(1, WIDE_A * k))
    core:SetAlpha(math.min(1, CORE_A * k))
    if not wide:IsShown() then wide:Show() core:Show() end
  end)
end
