-- Duskfall Transition.lua: moves the channels to a target.
--   instant  writes the target at once
--   fade     smooth ease over style.transition.fade.duration
--   adapt    eye adaptation. Towards darker: dips past the target (darker still), then slowly
--            rises to it. Towards brighter: overshoots brighter (glare), then settles quickly.
--            Only channels with `overshoot` go past the target (overshoot = "light": only when
--            the change is towards brighter, e.g. a bloom flare); the rest fade. Strength is the
--            overshoot as a share of the change. Two overshoots never come closer than
--            settings.adaptGap seconds (a ride along a zone border dips once).
-- A change caused only by the clock always fades over settings.timeFade seconds. why "edit"
-- (Look editor, Preview) is always instant.
-- A new target mid-transition starts again from the values on screen, so nothing jumps.
-- The driver frame runs only while a transition is active, writing about RATE times a second.
-- Public: T.Apply(target, held, why, timeOnly), T.Cancel(), T.Drop(key), T.IsRunning()
local ADDON, ns = ...
local T = {}
ns.Transition = T
local C = ns.Channels

local RATE = 25
local PEAK = { toDark = 0.25, toLight = 0.15 }   -- share of the time spent reaching the overshoot

local driver = CreateFrame("Frame")
driver:Hide()
local run = nil         -- { from, to, keys, t0, dur, strength, peak, dir, last }
local lastOvershoot = -1000

local function smooth(p) return p * p * (3 - 2 * p) end

-- How bright a set of values looks, 0..1 (gamma weighs more than brightness).
local function score(v)
  local g = ((v.gamma or 1) - 0.3) / 2.5
  local b = (v.brightness or 50) / 100
  return g * 0.6 + b * 0.4
end

-- Progress 0..1 -> share of the change, going up to 1 + s and back to 1 when s > 0.
local function shape(p, s, peak)
  if s <= 0 then return smooth(p) end
  if p < peak then return (1 + s) * smooth(p / peak) end
  return (1 + s) - s * smooth((p - peak) / (1 - peak))
end

local function step()
  local r = run
  if not r then driver:Hide() return end
  local now = GetTime()
  local p = (now - r.t0) / r.dur
  if p >= 1 then p = 1 end
  if p < 1 and now - r.last < 1 / RATE then return end
  r.last = now
  for k in pairs(r.keys) do
    local s = 0
    local o = C.byKey[k].overshoot
    if o == true or (o == "light" and r.dir == "toLight") then s = r.strength end
    C.Write(k, r.from[k] + (r.to[k] - r.from[k]) * shape(p, s, r.peak))
  end
  if p >= 1 then
    run = nil
    driver:Hide()
  end
end

driver:SetScript("OnUpdate", function() ns.Safe(step, "transition") end)

function T.Cancel()
  run = nil
  driver:Hide()
end

-- The player took a channel over by hand: leave it alone from now on.
function T.Drop(key)
  if run then run.keys[key] = nil end
end

function T.IsRunning() return run ~= nil end

-- held: key -> value for channels the player moved by hand; those are left alone.
function T.Apply(target, held, why, timeOnly)
  local cur = C.ReadAll()
  if not cur then return end
  local keys, n = {}, 0
  for _, ch in ipairs(C.list) do
    local k = ch.key
    if not (held and held[k] ~= nil) and target[k] ~= nil and not C.Same(k, cur[k], target[k]) then
      keys[k] = true
      n = n + 1
    end
  end
  if n == 0 then T.Cancel() return end
  -- The Look editor writes as you drag (and Preview): at once, never a transition per step.
  if why == "edit" then
    T.Cancel()
    for k in pairs(keys) do C.Write(k, target[k]) end
    return
  end

  local style = ns.Resolver.ActiveStyle()
  local tr = style.transition or {}
  local mode = tr.mode or "adapt"
  local dur, strength, peak, dir = 0, 0, 0.5, nil
  if timeOnly then
    dur = tonumber(ns.cfg.timeFade) or 45
  elseif mode == "fade" then
    dur = tonumber(tr.fade and tr.fade.duration) or 1.5
  elseif mode == "adapt" then
    dir = "toLight"
    if score(target) < score(cur) then dir = "toDark" end
    local a = (tr.adapt and tr.adapt[dir]) or {}
    dur = tonumber(a.duration) or 1.5
    strength = tonumber(a.strength) or 0
    peak = PEAK[dir]
    local now = GetTime()
    if now - lastOvershoot < (tonumber(ns.cfg.adaptGap) or 2) then
      strength = 0
    elseif strength > 0 then
      lastOvershoot = now
    end
  end

  if dur <= 0.05 then
    T.Cancel()
    for k in pairs(keys) do C.Write(k, target[k]) end
    return
  end
  run = { from = cur, to = {}, keys = keys, t0 = GetTime(), dur = dur, strength = strength, peak = peak, dir = dir, last = -1 }
  for k in pairs(keys) do run.to[k] = target[k] end
  ns.Debug("%s %.1fs strength %.2f (%s)", timeOnly and "time fade" or mode, dur, strength, tostring(why))
  driver:Show()
end
