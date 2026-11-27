-- Duskfall Channels.lua: the values Duskfall can change, and every read and write of them.
-- Ranges verified in game (Forever 1.60.x, 2026-11-25). A later channel (tint, sound, camera)
-- is a new row here. overshoot = Adapt may go past the target on this channel (true = both
-- directions, "light" = only towards brighter). decimals = how values are written and shown.
-- bloomUserMult = Graphics "Bloom Intensity" (slider 0-1, step 0.2; A14c). ffxGlow and bloomEnable
-- also exist on Forever but do nothing visible (A14b), so they are left alone.
-- Public: C.list, C.byKey, C.Read(key), C.ReadAll(), C.Clamp(key, v), C.Same(key, a, b),
--         C.SameAll(a, b), C.Write(key, v, fine), C.WriteAll(values), C.IsOurs(cvar, value), C.Format(key, v)
-- fine = a transition step: written with `fine` decimals and no eps skip. The game keeps fractions
-- (Brightness 48.5, Gamma 1.1234 read back, Kim 2026-11-26), and whole steps showed in fades.
local ADDON, ns = ...
local L = ns.L
local C = {}
ns.Channels = C

C.list = {
  { key = "gamma",      cvar = "Gamma",         label = L["CH_GAMMA"],      short = L["CH_GAMMA_SHORT"],  min = 0.3, max = 2.8, eps = 0.011, decimals = 2, fine = 3, fade = true, overshoot = true },   --noloc
  { key = "brightness", cvar = "Brightness",    label = L["CH_BRIGHTNESS"], short = L["CH_BRIGHTNESS_SHORT"],  min = 0,   max = 100, eps = 0.6,   decimals = 0, fine = 2, fade = true, overshoot = true },   --noloc
  { key = "contrast",   cvar = "Contrast",      label = L["CH_CONTRAST"],   short = L["CH_CONTRAST_SHORT"],  min = 0,   max = 100, eps = 0.6,   decimals = 0, fine = 2, fade = true },   --noloc
  { key = "bloom",      cvar = "bloomUserMult", label = L["CH_BLOOM"],      short = L["CH_BLOOM_SHORT"], min = 0,   max = 1,   eps = 0.011, decimals = 2, fine = 3, fade = true, overshoot = "light" },   --noloc
}
C.byKey, C.byCVar = {}, {}
for _, ch in ipairs(C.list) do
  C.byKey[ch.key] = ch
  C.byCVar[ch.cvar:lower()] = ch
end

local writing = false   -- true while our own SetCVar runs (CVAR_UPDATE fires for our writes too)
local written = {}      -- key -> the value we last wrote
local recent = {}       -- key -> the last RECENT values we wrote (a late CVAR_UPDATE during a fade)
local RECENT = 16

local function remember(key, v)
  written[key] = v
  local list = recent[key]
  if not list then
    list = {}
    recent[key] = list
  end
  list[#list + 1] = v
  if #list > RECENT then table.remove(list, 1) end
end

function C.Clamp(key, v)
  local ch = C.byKey[key]
  v = tonumber(v)
  if not ch or not v then return v end
  if v < ch.min then return ch.min end
  if v > ch.max then return ch.max end
  return v
end

-- Gamma and bloom to two decimals, the percentages as whole numbers (the game's own steps).
function C.Format(key, v)
  local ch = C.byKey[key]
  if ch and ch.decimals and ch.decimals > 0 then return string.format("%." .. ch.decimals .. "f", v) end
  return tostring(math.floor(v + 0.5))
end

-- Values read back as float strings ("1.1000000238419"): never compare with ==.
function C.Same(key, a, b)
  if a == nil or b == nil then return false end
  return math.abs(a - b) <= C.byKey[key].eps
end

function C.SameAll(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for _, ch in ipairs(C.list) do
    if not C.Same(ch.key, a[ch.key], b[ch.key]) then return false end
  end
  return true
end

function C.Read(key)
  local ch = C.byKey[key]
  local ok, v = pcall(GetCVar, ch.cvar)
  if not ok then return nil end
  return tonumber(v)
end

-- All values, or nil when any is missing.
function C.ReadAll()
  local out = {}
  for _, ch in ipairs(C.list) do
    local v = C.Read(ch.key)
    if v == nil then return nil end
    out[ch.key] = v
  end
  return out
end

function C.Write(key, v, fine)
  v = C.Clamp(key, v)
  if v == nil then return false end
  local ch = C.byKey[key]
  local text
  local cur = C.Read(key)
  if fine and ch.fine then
    text = string.format("%." .. ch.fine .. "f", v)
    if cur and math.abs(cur - tonumber(text)) < 0.5 * 10 ^ -ch.fine then
      written[key] = cur
      return true
    end
  else
    if C.Same(key, cur, v) then
      written[key] = cur
      return true
    end
    text = C.Format(key, v)
  end
  writing = true
  local ok = pcall(SetCVar, ch.cvar, text)
  writing = false
  remember(key, tonumber(text))
  if ns.db then ns.db.lastApplied[key] = written[key] end
  if not ok then ns.Debug("SetCVar %s failed", key) end
  return ok
end

function C.WriteAll(values)
  for _, ch in ipairs(C.list) do
    if values[ch.key] ~= nil then C.Write(ch.key, values[ch.key]) end
  end
end

-- Was this CVAR_UPDATE caused by us? Guard flag, or the value is one we wrote recently
-- (covers the event arriving after the guard dropped). Not one of ours at all: treated as ours.
function C.IsOurs(cvar, value)
  if writing then return true end
  local ch = type(cvar) == "string" and C.byCVar[cvar:lower()]
  if not ch then return true end
  local v = tonumber(value) or C.Read(ch.key)
  if C.Same(ch.key, written[ch.key], v) then return true end
  for _, w in ipairs(recent[ch.key] or {}) do
    if C.Same(ch.key, w, v) then return true end
  end
  return false
end
