-- Duskfall UI/CursorLight.lua: light that follows the mouse over Duskfall's own windows (the main
-- window, the mini panel, the welcome; Kim, 2026-11-26). Idea from Hoverlight, written from scratch
-- (Hoverlight is GPL; nothing of its code or art is used).
--
-- An addon has no shaders, so the light is made from what there is (probe T1: one mask texture
-- reaches textures in any frame):
--   * twins: every piece of art Duskfall draws (rounded boxes, the slider diamond, icons, the wood,
--     the window border, the logo) gets an additive copy of itself, shown only through one soft
--     round mask per window that sits at the mouse. So things brighten in their own colour: gold
--     gets more golden, blue bluer, dark stays dark. Edges (borders, rings) get a stronger copy,
--     so they catch a glint. Text can't be masked and stays as it is.
--   * haze: a faint flat warm glow under the twins (Assets/cursor-light, additive, clipped to the
--     window), so a dark screen still lifts.
-- The light grows from nothing when the mouse comes over a window and shrinks away when it leaves
-- (FADE seconds), breathing a little. Its OnUpdate runs only while the window is shown.
-- Cost (Kim, 2026-11-27: 115-120 fps down to 110-112): every twin is a full extra draw (the wood
-- twin covers the whole window), masked or not. So the twins of a window are hidden whenever its
-- light is out (the mouse is not over it); they only draw while the light shows.
-- settings.cursorLight = false switches it off, settings.cursorLightStrength scales it.
--
-- Twins are made where the art is made (CL.NewTwin, CL.Copy) and wait, hidden, until the window
-- they live in has its light (CL.Attach); twins outside a lit window (the status display) are dropped.
-- Public: CL.Attach(window), CL.NewTwin(frame, layer, sub, kind) -> texture, CL.Copy(texture, kind,
--         owner) -> texture, CL.Want(twin, shown), CL.Refresh()
local ADDON, ns = ...
local UI = ns.UI
local CL = {}
ns.CursorLight = CL

local MASK = 240                     -- the light's size at full
local HAZE, HAZE_A = 300, 0.06       -- the flat haze: a third of the old flat light
local FADE = 0.25                    -- seconds to grow or shrink
local BREATH = 1.6                   -- radians a second (about 4 s a breath)
local LEVEL_UP = 400                 -- the haze frame: above everything in the window
local KIND = { fill = 0.55, edge = 1, art = 0.6 }   -- twin strength by kind
local FPS_MIN, FPS_BACK = 60, 70     -- off below 60 frames a second, back above 70 (no flicker between)

local pending, masked = {}, {}

-- Frame rate guard (Kim, 2026-11-27): looked at twice a second, so one slow frame does not switch it
local slow, fpsAt = false, 0
local function fpsOk()
  local now = GetTime()
  if now - fpsAt > 0.5 then
    fpsAt = now
    local fps = GetFramerate and GetFramerate() or 999
    if slow and fps > FPS_BACK then slow = false elseif not slow and fps < FPS_MIN then slow = true end
  end
  return not slow
end
local function on() return (not ns.cfg or ns.cfg.cursorLight ~= false) and fpsOk() end
local function strength() return tonumber(ns.cfg and ns.cfg.cursorLightStrength) or 1 end

local function alphaOf(t) return math.min(1, (KIND[t.duskKind] or 0.6) * strength()) end

-- A new twin: hidden until its window's light masks it.
function CL.NewTwin(frame, layer, sub, kind)
  local t = frame:CreateTexture(nil, layer or "ARTWORK", nil, math.max(-8, math.min(7, sub or 0)))
  t:SetBlendMode("ADD")
  t:Hide()
  t.duskKind = kind or "fill"
  t.duskWant = true
  pending[#pending + 1] = t
  return t
end

-- Shown or hidden with its original (it only shows once masked).
function CL.Want(t, shown)
  if not t then return end
  t.duskWant = shown and true or false
  if t.duskMasked then t:SetShown(t.duskWant and t.duskWin and t.duskWin.duskLit or false) end
end

-- All twins of a window shown (as wanted) or hidden, as its light comes and goes
local function lightTwins(win, lit)
  win.duskLit = lit
  for _, t in ipairs(masked) do
    if t.duskWin == win then t:SetShown(lit and t.duskWant) end
  end
end

-- A twin of an existing texture: same picture, texture coordinates, tiling, colour and rotation,
-- on top of it (owner: the frame to draw it on, default the texture's own). Follows its Show / Hide.
function CL.Copy(tex, kind, owner)
  if not tex then return nil end
  local layer, sub = tex:GetDrawLayer()
  local t = CL.NewTwin(owner or tex:GetParent(), layer, (sub or 0) + 1, kind)
  t:SetAllPoints(tex)
  local atlas = tex.GetAtlas and tex:GetAtlas()
  if atlas and atlas ~= "" then
    t:SetAtlas(atlas)
  else
    local file = tex:GetTexture()
    if not file then return nil end
    t:SetTexture(file, tex.GetWrapModeHorizontal and tex:GetWrapModeHorizontal() or nil,
      tex.GetWrapModeVertical and tex:GetWrapModeVertical() or nil)
    t:SetTexCoord(tex:GetTexCoord())
  end
  if tex.GetHorizTile then t:SetHorizTile(tex:GetHorizTile()) t:SetVertTile(tex:GetVertTile()) end
  t:SetVertexColor(tex:GetVertexColor())
  if tex.GetRotation and t.SetRotation then pcall(t.SetRotation, t, tex:GetRotation()) end
  t.duskWant = tex:IsShown()
  hooksecurefunc(tex, "Show", function() CL.Want(t, true) end)
  hooksecurefunc(tex, "Hide", function() CL.Want(t, false) end)
  hooksecurefunc(tex, "SetShown", function(_, v) CL.Want(t, v) end)
  return t
end

-- Give waiting twins the mask of the lit window they live in; drop the ones in no lit window.
local function flush()
  local keep = {}
  for _, t in ipairs(pending) do
    local f = t:GetParent()
    while f and not f.duskMask do f = f.GetParent and f:GetParent() or nil end
    if f then
      if pcall(t.AddMaskTexture, t, f.duskMask) then
        t.duskMasked = true
        t.duskWin = f
        t:SetAlpha(alphaOf(t))
        t:SetShown(t.duskWant and f.duskLit or false)
        masked[#masked + 1] = t
      end
    elseif t:GetParent() and t:GetParent():GetParent() == nil then
      keep[#keep + 1] = t   -- not parented yet: try again
    end
  end
  pending = keep
end

-- The strength slider changed
function CL.Refresh()
  for _, t in ipairs(masked) do t:SetAlpha(alphaOf(t)) end
end

function CL.Attach(win)
  if not win or win.duskMask then return end
  local mask = win:CreateMaskTexture()
  mask:SetTexture(UI.ART .. "Backgrounds\\cursor-light", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetSize(1, 1)
  mask:SetPoint("CENTER", UIParent, "BOTTOMLEFT", -1000, -1000)
  win.duskMask = mask

  -- The haze, clipped to the window, above everything in it
  local clip = CreateFrame("Frame", nil, win)
  clip:SetAllPoints(win)
  pcall(clip.SetClipsChildren, clip, true)
  clip:EnableMouse(false)
  clip:SetFrameLevel(math.min(9000, win:GetFrameLevel() + LEVEL_UP))
  local haze = clip:CreateTexture(nil, "OVERLAY", nil, 7)
  haze:SetTexture(UI.ART .. "Backgrounds\\cursor-light")
  haze:SetBlendMode("ADD")
  haze:SetSize(HAZE, HAZE)
  haze:SetVertexColor(1, 0.85, 0.55)
  haze:Hide()

  local level, clock, parked = 0, 0, true
  clip:SetScript("OnUpdate", function(_, dt)
    if pending[1] then flush() end
    clock = clock + dt
    local want = (on() and win:IsMouseOver()) and 1 or 0
    if level < want then level = math.min(1, level + dt / FADE)
    elseif level > want then level = math.max(0, level - dt / FADE) end
    if level <= 0 then
      if not parked then
        mask:ClearAllPoints()
        mask:SetPoint("CENTER", UIParent, "BOTTOMLEFT", -1000, -1000)
        mask:SetSize(1, 1)
        haze:Hide()
        lightTwins(win, false)
        parked = true
      end
      return
    end
    if parked then lightTwins(win, true) end
    parked = false
    local scale = win:GetEffectiveScale()
    local x, y = GetCursorPosition()
    local left, bottom = win:GetLeft(), win:GetBottom()
    if not (scale and x and left and bottom) then return end
    x, y = x / scale - left, y / scale - bottom
    local breath = 0.94 + 0.06 * math.sin(clock * BREATH)
    local e = level * level * (3 - 2 * level)
    local size = math.max(1, MASK * e * breath)
    mask:ClearAllPoints()
    mask:SetPoint("CENTER", win, "BOTTOMLEFT", x, y)
    mask:SetSize(size, size)
    haze:ClearAllPoints()
    haze:SetPoint("CENTER", win, "BOTTOMLEFT", x, y)
    haze:SetAlpha(math.min(1, HAZE_A * e * breath * strength()))
    haze:Show()
  end)
  flush()
end
