-- Duskfall UI/Winter.lua: snow on Duskfall's windows from 1 December to 31 January (Kim, 2026-11-28).
-- The game's own Winter Veil art, found by Kim in the game files and shown on Forever (probe
-- 2026-11-28), used by file number (nothing shipped): the snowman ledge on the main window's top
-- edge, a corner heap in its bottom-left corner (the snowflake switch has the right), the small
-- snowman on the mini panel, a heap on the status display, and turning snowflakes falling (and
-- swaying) behind the About page. Not on the bottom tabs: the tab code tints every texture on a
-- tab (Kim's screenshot). The computer's date decides the season; settings.winter (default on)
-- switches it off: the snowflake at the bottom right of the Settings overview, shown only in
-- season. /dusk winter on|off|auto forces the season for testing (db.debugWinter, not in help).
-- The art never takes the mouse and is never tinted.
-- Public: WI.InSeason(), WI.On(), WI.Piece(host, art, place, o) -> texture, WI.AddFalling(host),
--         WI.Switch(parent) -> button, WI.Refresh()
local ADDON, ns = ...
local UI = ns.UI
local L = ns.L
local WI = {}
ns.Winter = WI

local ART = UI.ART .. "Winter\\"
-- interface/store/tradingpostwinterveil.blp, 1024 x 512 (copy for measuring: _work/Graphics).
-- Each piece: its rectangle on the sheet (left, top, right, bottom, glow included) and seat = the
-- row its snow rests on (under it only icicles), from the rectangle's top
local SHEET, SHEET_W, SHEET_H = 5351163, 1024, 512
local PIECE = {
  snowman = { 0, 0, 422, 270, seat = 195 },     -- long ledge, top-hat snowman on its right end
  heap    = { 430, 24, 834, 206, seat = 114 },  -- heap with two icicles
  scarf   = { 438, 218, 758, 400, seat = 133 }, -- small ledge, snowman in a scarf
  corner  = { 780, 218, 964, 318, seat = 99 },  -- heap cut straight on its right (against a side)
}
-- models/unktextures/snowflake_flipping_01.blp, 512 x 64: eight 64 x 64 frames of a flake turning
-- over; the flake sits round (20.5, 13.5) of each frame and is about 16 px across at its widest
local FLIP, FLIP_FRAMES, FLIP_CX, FLIP_CY, FLIP_W = 5796769, 8, 20.5 / 64, 13.5 / 64, 16 / 64

function WI.InSeason()
  local dev = ns.db and ns.db.debugWinter
  if dev == "on" then return true elseif dev == "off" then return false end
  local t = date("*t")
  return t.month == 12 or t.month == 1
end

function WI.On()
  return WI.InSeason() and not (ns.cfg and ns.cfg.winter == false)
end

-- Pieces ----------------------------------------------------------------------------------------
-- A piece is a texture on a host frame; place(tex, seat) anchors it (sized and cleared before;
-- seat = px from the texture's top to the row its snow rests on, at this scale).
-- o = { scale (1 = the sheet's pixels), mirror, cond = fn() -> shown, layer, sub }
local pieces = {}

local function apply(t)
  if not WI.On() or (t.duskCond and not t.duskCond()) then t:Hide() return end
  local p, s = PIECE[t.duskArt], t.duskScale or 1
  t:SetTexture(SHEET)
  t:SetSize((p[3] - p[1]) * s, (p[4] - p[2]) * s)
  local l, r = p[1] / SHEET_W, p[3] / SHEET_W
  if t.duskMirror then l, r = r, l end
  t:SetTexCoord(l, r, p[2] / SHEET_H, p[4] / SHEET_H)
  t:ClearAllPoints()
  t.duskPlace(t, p.seat * s)
  t:Show()
end

function WI.Piece(host, art, place, o)
  o = o or {}
  local t = host:CreateTexture(nil, o.layer or "OVERLAY", nil, o.sub or 7)
  t.duskArt, t.duskPlace, t.duskScale, t.duskMirror, t.duskCond = art, place, o.scale, o.mirror, o.cond
  t:Hide()
  pieces[#pieces + 1] = t
  host:HookScript("OnShow", function() apply(t) end)
  apply(t)
  return t
end

-- Falling snow (BigNoteBox's ALL-585, about 40 flakes) --------------------------------------------
-- Three depth layers (far = small, faint, slow). Each flake falls from the top edge to the bottom
-- edge, fading in and out, so nothing needs clipping; the first fall starts part way down so the
-- area is full at once. Only AnimationGroups, no OnUpdate, and only while the host is shown in
-- season. Spots and speeds come from a fixed seed. Off below 60 frames a second, back above 70
-- (as the cursor light), looked at once a second while shown.
-- Sway (Kim: more): each flake swings from side to side as it falls, sway px either way, one swing
-- (there and back) every p1..p2 seconds; the swings add to the straight fall (same group).
-- flip = the game's turning snowflake (FlipBook, one turn every f1..f2 seconds; Kim, 2026-11-28),
-- s1..s2 its size across; the far layer stays soft dots (BNB's snow-flake): far flakes read as dots
local LAYERS = {   -- far to near
  { n = 20, s1 = 3, s2 = 4,   a = 0.30, t1 = 14, t2 = 18, drift = 10, sub = 2, sway = 8,  p1 = 5, p2 = 7 },
  { n = 12, s1 = 8, s2 = 10,  a = 0.60, t1 = 9,  t2 = 12, drift = 18, sub = 3, sway = 14, p1 = 4, p2 = 6,
    flip = true, f1 = 1.2, f2 = 1.6 },
  { n = 7,  s1 = 12, s2 = 14, a = 0.85, t1 = 6,  t2 = 8,  drift = 26, sub = 4, sway = 20, p1 = 3, p2 = 5,
    flip = true, f1 = 0.8, f2 = 1.2 },
}
local EDGE, REF_H, FADE = 6, 360, 0.12
local FPS_MIN, FPS_BACK = 60, 70

local function rand(r)   -- Park-Miller, 0..1, exact in doubles
  r.v = (r.v * 16807) % 2147483647
  return r.v / 2147483647
end

local function makeFlake(host, Ly, r)
  local fl = { a = Ly.a, ox = 0, oy = 0 }
  fl.tex = host:CreateTexture(nil, "BACKGROUND", nil, Ly.sub)
  local sz = Ly.s1 + (Ly.s2 - Ly.s1) * rand(r)
  if Ly.flip then
    -- One whole frame drawn so its flake is sz across; the texture's centre is moved so the
    -- flake (not the frame's middle) lands on the flake's spot
    local cell = sz / FLIP_W
    fl.tex:SetTexture(FLIP)
    fl.tex:SetSize(cell, cell)
    fl.ox, fl.oy = (0.5 - FLIP_CX) * cell, (FLIP_CY - 0.5) * cell
    local turn = Ly.f1 + (Ly.f2 - Ly.f1) * rand(r)
    local ok = pcall(function()
      fl.flip = fl.tex:CreateAnimationGroup()
      fl.flip:SetLooping("REPEAT")
      local fb = fl.flip:CreateAnimation("FlipBook")
      fb:SetFlipBookRows(1)
      fb:SetFlipBookColumns(FLIP_FRAMES)
      fb:SetFlipBookFrames(FLIP_FRAMES)
      fb:SetDuration(turn)
    end)
    if not ok then
      -- No FlipBook: a still frame, the flake seen face on (frame 4)
      fl.flip = nil
      fl.tex:SetTexCoord(3 / FLIP_FRAMES, 4 / FLIP_FRAMES, 0, 1)
    end
  else
    fl.tex:SetTexture(ART .. "snow-flake")
    fl.tex:SetSize(sz, sz)
  end
  fl.tex:Hide()
  fl.xf, fl.phase = rand(r), rand(r)
  fl.dur = Ly.t1 + (Ly.t2 - Ly.t1) * rand(r)
  fl.drift = (rand(r) * 2 - 1) * Ly.drift
  -- The endless fall, top to bottom
  fl.loop = fl.tex:CreateAnimationGroup()
  fl.loop:SetLooping("REPEAT")
  fl.loopMove = fl.loop:CreateAnimation("Translation")
  fl.loopMove:SetOrder(1)
  fl.fin = fl.loop:CreateAnimation("Alpha")
  fl.fin:SetFromAlpha(0)
  fl.fin:SetToAlpha(fl.a)
  fl.fin:SetOrder(1)
  fl.fout = fl.loop:CreateAnimation("Alpha")
  fl.fout:SetFromAlpha(fl.a)
  fl.fout:SetToAlpha(0)
  fl.fout:SetOrder(1)
  -- The sway: an even number of half swings over one fall, out and back to the middle, so the
  -- loop joins up: +A, -2A, +2A, ..., -A (eased: fastest through the middle)
  fl.sway = (0.6 + 0.4 * rand(r)) * Ly.sway * (rand(r) < 0.5 and -1 or 1)
  local period = Ly.p1 + (Ly.p2 - Ly.p1) * rand(r)
  local n = 2 * math.max(1, math.floor(fl.dur / period + 0.5))
  fl.swings = {}
  for i = 1, n do
    local sw = fl.loop:CreateAnimation("Translation")
    sw:SetOrder(1)
    local k = (i == 1 or i == n) and 1 or 2
    local sign = (i % 2 == 1) and 1 or -1
    sw.dx = k * sign * fl.sway
    sw:SetOffset(sw.dx, 0)
    sw:SetSmoothing(i == 1 and "OUT" or (i == n and "IN" or "IN_OUT"))
    fl.swings[i] = sw
  end
  -- The first fall, from part way down
  fl.intro = fl.tex:CreateAnimationGroup()
  fl.introMove = fl.intro:CreateAnimation("Translation")
  fl.introMove:SetOrder(1)
  fl.introFade = fl.intro:CreateAnimation("Alpha")
  fl.introFade:SetFromAlpha(fl.a)
  fl.introFade:SetToAlpha(0)
  fl.introFade:SetOrder(1)
  fl.intro:SetScript("OnFinished", function()
    fl.tex:ClearAllPoints()
    fl.tex:SetPoint("CENTER", host, "TOPLEFT", fl.x + fl.ox, -EDGE + fl.oy)
    fl.loop:Play()
  end)
  return fl
end

local snows = {}

local function stopSnow(sn)
  sn.running = false
  for _, fl in ipairs(sn.flakes) do
    fl.intro:Stop()
    fl.loop:Stop()
    if fl.flip then fl.flip:Stop() end
    fl.tex:Hide()
  end
end

local function runSnow(sn)
  stopSnow(sn)
  local host = sn.host
  local w, h = host:GetWidth() or 0, host:GetHeight() or 0
  if not (host:IsVisible() and WI.On()) or sn.slow or w < 60 or h < 60 then return end
  sn.running = true
  local fallH = h - EDGE * 2
  local speed = math.max(0.5, fallH / REF_H)
  for _, fl in ipairs(sn.flakes) do
    local room = math.abs(fl.drift) + math.abs(fl.sway)
    local lo = EDGE + room
    local hi = w - EDGE - room
    fl.x = lo + (hi - lo) * fl.xf
    local d = fl.dur * speed
    fl.loopMove:SetOffset(fl.drift, -fallH)
    fl.loopMove:SetDuration(d)
    local seg = d / #fl.swings
    for i, sw in ipairs(fl.swings) do
      sw:SetDuration(seg)
      sw:SetStartDelay((i - 1) * seg)
    end
    fl.fin:SetDuration(d * FADE)
    fl.fout:SetDuration(d * FADE)
    fl.fout:SetStartDelay(d * (1 - FADE))
    local rest = 1 - fl.phase
    fl.introMove:SetOffset(fl.drift * rest, -fallH * rest)
    fl.introMove:SetDuration(math.max(0.1, d * rest))
    fl.introFade:SetDuration(math.max(0.05, d * math.min(rest, FADE)))
    fl.introFade:SetStartDelay(math.max(0, d * (rest - FADE)))
    fl.tex:ClearAllPoints()
    fl.tex:SetPoint("CENTER", host, "TOPLEFT", fl.x + fl.ox, -EDGE - fallH * fl.phase + fl.oy)
    fl.tex:SetAlpha(fl.a)   -- the fades run from it; held between them either way
    fl.tex:Show()
    fl.intro:Play()
    if fl.flip then fl.flip:Play() end
  end
end

-- The frame rate guard: stops the snow when slow, starts it again when fast enough
local function checkFps(sn)
  local fps = GetFramerate and GetFramerate() or 999
  if not sn.slow and fps < FPS_MIN then
    sn.slow = true
    stopSnow(sn)
  elseif sn.slow and fps > FPS_BACK then
    sn.slow = false
    runSnow(sn)
  end
end

-- host: a frame the size of the area, behind the content (its textures are BACKGROUND)
function WI.AddFalling(host)
  if not host or host.duskSnow then return end
  local sn = { host = host, flakes = {} }
  host.duskSnow = sn
  local r = { v = 584 }
  for _, Ly in ipairs(LAYERS) do
    for _ = 1, Ly.n do sn.flakes[#sn.flakes + 1] = makeFlake(host, Ly, r) end
  end
  snows[#snows + 1] = sn
  local function start()
    sn.slow = false
    checkFps(sn)
    runSnow(sn)
    if sn.ticker then sn.ticker:Cancel() end
    sn.ticker = WI.On() and C_Timer.NewTicker(1, function() checkFps(sn) end) or nil
  end
  host:HookScript("OnShow", start)
  host:HookScript("OnHide", function()
    if sn.ticker then sn.ticker:Cancel() sn.ticker = nil end
    stopSnow(sn)
  end)
  sn.start = start
  if host:IsVisible() then start() end
end

-- The switch (Settings overview) -----------------------------------------------------------------
-- A small snowflake: gold = on, grey = off; shown only in season.
local switches = {}

local function paintSwitch(b)
  b:SetShown(WI.InSeason())
  local on = WI.On()
  if on then b.tex:SetVertexColor(1, 0.82, 0) else b.tex:SetVertexColor(0.45, 0.45, 0.45) end
end

function WI.Switch(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(16, 16)
  b.tex = b:CreateTexture(nil, "ARTWORK")
  b.tex:SetAllPoints()
  b.tex:SetTexture(ART .. "snowflake")
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetTexture(ART .. "snowflake")
  hl:SetBlendMode("ADD")
  hl:SetAlpha(0.4)
  UI.Tooltip(b, L["WI_TIP"])
  b:SetScript("OnClick", function()
    ns.cfg.winter = not WI.On()
    WI.Refresh()
  end)
  b:HookScript("OnShow", paintSwitch)
  switches[#switches + 1] = b
  paintSwitch(b)
  return b
end

function WI.Refresh()
  for _, t in ipairs(pieces) do apply(t) end
  for _, sn in ipairs(snows) do
    if sn.host:IsVisible() then sn.start() end
  end
  for _, b in ipairs(switches) do paintSwitch(b) end
end
