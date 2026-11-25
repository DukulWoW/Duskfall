-- Duskfall Channels.lua: the values Duskfall can change, and every read and write of them.
-- Ranges verified in game (Forever 1.60.x, 2026-11-25). A later channel (tint, sound, camera)
-- is a new row here. overshoot = Adapt may go past the target on this channel (true = both
-- directions, "light" = only towards brighter). decimals = how values are written and shown.
-- bloomUserMult = Graphics "Bloom Intensity" (slider 0-1, step 0.2; A14c). ffxGlow and bloomEnable
-- also exist on Forever but do nothing visible (A14b), so they are left alone.
-- Public: C.list, C.byKey, C.Read(key), C.ReadAll(), C.Clamp(key, v), C.Same(key, a, b),
--         C.SameAll(a, b), C.Write(key, v), C.WriteAll(values), C.IsOurs(cvar, value), C.Format(key, v)
local ADDON, ns = ...
local C = {}
ns.Channels = C

C.list = {
  { key = "gamma",      cvar = "Gamma",         label = "Gamma",      short = "G",  min = 0.3, max = 2.8, eps = 0.011, decimals = 2, fade = true, overshoot = true },
  { key = "brightness", cvar = "Brightness",    label = "Brightness", short = "B",  min = 0,   max = 100, eps = 0.6,   decimals = 0, fade = true, overshoot = true },
  { key = "contrast",   cvar = "Contrast",      label = "Contrast",   short = "C",  min = 0,   max = 100, eps = 0.6,   decimals = 0, fade = true },
  { key = "bloom",      cvar = "bloomUserMult", label = "Bloom",      short = "Bl", min = 0,   max = 1,   eps = 0.011, decimals = 2, fade = true, overshoot = "light" },
}
C.byKey, C.byCVar = {}, {}
for _, ch in ipairs(C.list) do
  C.byKey[ch.key] = ch
  C.byCVar[ch.cvar:lower()] = ch
end

local writing = false   -- true while our own SetCVar runs (CVAR_UPDATE fires for our writes too)
local written = {}      -- key -> the value we last wrote
local recent = {}       -- key -> the last RECENT values we wrote (a late CVAR_UPDATE during a fade)
local RECENT = 8

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

function C.Write(key, v)
  v = C.Clamp(key, v)
  if v == nil then return false end
  local cur = C.Read(key)
  if C.Same(key, cur, v) then
    written[key] = cur
    return true
  end
  writing = true
  local ok = pcall(SetCVar, C.byKey[key].cvar, C.Format(key, v))
  writing = false
  remember(key, tonumber(C.Format(key, v)))
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
