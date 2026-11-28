-- Duskfall Situations.lua: what the player's surroundings are right now (the env snapshot),
-- whether a situation string matches it, and place discovery.
--
-- Where (any one must match; no active Where = everywhere):
--   "zone:<mapID>"            zone-level map, or the best map itself
--   "sub:<mapID>:<name>"      that zone + GetSubZoneText() (client language)
--   "instance:<instanceID>"   select(8, GetInstanceInfo())
--   "itype:<party|raid|pvp|arena|scenario>"
-- When (all must match):
--   indoors, outdoors, resting, combat, mounted, swimming, underwater, ghost,
--   "time:<dawn|day|dusk|night>", "time:HH:MM-HH:MM" (may wrap past midnight)
-- "~" in front = switched off (kept, never matched). "!" in front of a When = negated.
--
-- Inside a dungeon C_Map.GetBestMapForUnit returns nil and the subzone is "" (A7, 2026-11-25):
-- instances match by instance / itype only.
--
-- Public: S.Snapshot(), S.LookWhere(look, env), S.LookWhen(look, env), S.Period(hour),
--         S.Discover(env), S.PlaceKey(kind, env), S.PlaceName(kind, env), S.FLAGS, S.WHERE_SCORE
local ADDON, ns = ...
local S = {}
ns.Situations = S

S.WHERE_SCORE = { sub = 4, zone = 3, instance = 2, itype = 1 }

local ZONE_TYPE = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3

-- Walk a map up to its zone (dungeon, micro and orphan maps sit below it).
local function zoneOf(mapID)
  local id, guard = mapID, 0
  while id and guard < 10 do
    local info = C_Map.GetMapInfo(id)
    if not info then return mapID end
    if info.mapType <= ZONE_TYPE or not info.parentMapID or info.parentMapID == 0 then return id end
    id = info.parentMapID
    guard = guard + 1
  end
  return mapID
end

local function mapName(id)
  local info = id and C_Map.GetMapInfo(id)
  return info and info.name or nil
end

local function clock()
  if ns.cfg and ns.cfg.clock == "local" then
    local t = date("*t")
    return t.hour, t.min
  end
  local h, m = GetGameTime()
  return h or 12, m or 0
end

function S.Period(hour)
  local b = (ns.cfg and ns.cfg.buckets) or ns.DEFAULTS.buckets
  if hour >= b.night or hour < b.dawn then return "night" end
  if hour < b.day then return "dawn" end
  if hour < b.dusk then return "day" end
  return "dusk"
end

-- Places the game calls outdoors though they are underground: they count as indoors (Kim, 1.3.0).
-- Undercity (map 1458) is flagged outdoors, which is why you can mount there (probe: IsIndoors()
-- false, IsOutdoors() true in the Trade Quarter). The Ruins of Lordaeron above are Tirisfal's.
-- Ironforge (map 1455) too: under the mountain, but the game says outdoors (Kim, 2026-11-28).
local UNDERGROUND = { [1458] = true, [1455] = true }

-- A subzone named like its zone is no part of it: the game gives unnamed spots the city's own name
-- (Ironforge, 2026-11-28: GetSubZoneText() "Ironforge" in the Commons, "Vault of Ironforge" in the
-- bank). Such a spot counts as the zone alone. Core.lua's v4 migration moves old settings for it.
local function sameName(a, b)
  if not a or not b then return false end
  return a:lower():gsub("^%s+", ""):gsub("%s+$", "") == b:lower():gsub("^%s+", ""):gsub("%s+$", "")
end
S.SameName = sameName

function S.Snapshot()
  local env = {}
  local iname, itype, _, _, _, _, _, instID = GetInstanceInfo()
  if itype and itype ~= "none" then
    env.instance, env.itype, env.instanceName = instID, itype, iname
  end
  local best = C_Map.GetBestMapForUnit("player")
  env.map = best
  env.zone = best and zoneOf(best) or nil
  env.zoneName = mapName(env.zone) or GetRealZoneText()
  local sub = GetSubZoneText()
  if sub and sub ~= "" and not sameName(sub, env.zoneName) and not sameName(sub, GetZoneText()) then env.sub = sub end
  env.indoors = (IsIndoors() or UNDERGROUND[best or 0] or UNDERGROUND[env.zone or 0]) and true or false
  env.resting = IsResting() and true or false
  env.combat = ns.inCombat and true or false
  env.mounted = IsMounted() and true or false
  env.swimming = IsSwimming() and true or false
  env.underwater = (IsSubmerged and IsSubmerged()) and true or false
  env.ghost = UnitIsGhost("player") and true or false
  env.hour, env.min = clock()
  env.period = S.Period(env.hour)
  return env
end

-- Where -----------------------------------------------------------------------------------------
local function whereScore(str, env)
  local kind, rest = str:match("^(%a+):(.+)$")
  if kind == "zone" then
    local id = tonumber(rest)
    if id and (id == env.zone or id == env.map) then return S.WHERE_SCORE.zone end
  elseif kind == "sub" then
    local id, name = rest:match("^(%d+):(.+)$")
    if id and env.sub and tonumber(id) == env.zone and name == env.sub then return S.WHERE_SCORE.sub end
  elseif kind == "instance" then
    if env.instance and tonumber(rest) == env.instance then return S.WHERE_SCORE.instance end
  elseif kind == "itype" then
    if env.itype and rest == env.itype then return S.WHERE_SCORE.itype end
  end
  return nil
end

-- The best score of the Look's Where list, 0 when it has no active Where (everywhere), nil = no match.
function S.LookWhere(look, env)
  local any, best = false, nil
  for _, s in ipairs(look.where or {}) do
    if s:sub(1, 1) ~= "~" then
      any = true
      local sc = whereScore(s, env)
      if sc and (not best or sc > best) then best = sc end
    end
  end
  if not any then return 0 end
  return best
end

-- When ------------------------------------------------------------------------------------------
S.FLAGS = {
  indoors    = function(env) return env.indoors end,
  outdoors   = function(env) return not env.indoors end,
  resting    = function(env) return env.resting end,
  combat     = function(env) return env.combat end,
  mounted    = function(env) return env.mounted end,
  swimming   = function(env) return env.swimming end,
  underwater = function(env) return env.underwater end,
  ghost      = function(env) return env.ghost end,
}

local function matchTime(rest, env)
  local h1, m1, h2, m2 = rest:match("^(%d+):(%d+)%-(%d+):(%d+)$")
  if h1 then
    local now = env.hour * 60 + env.min
    local a = tonumber(h1) * 60 + tonumber(m1)
    local b = tonumber(h2) * 60 + tonumber(m2)
    if a <= b then return now >= a and now < b end
    return now >= a or now < b
  end
  return env.period == rest
end

-- true / false, or nil for a kind this build does not know (never matches, negated or not).
local function whenMatch(str, env)
  local neg = false
  if str:sub(1, 1) == "!" then
    neg = true
    str = str:sub(2)
  end
  local r
  local kind, rest = str:match("^(%a+):(.+)$")
  if kind == "time" then
    r = matchTime(rest, env)
  elseif S.FLAGS[str] then
    r = S.FLAGS[str](env) and true or false
  else
    return nil
  end
  if neg then return not r end
  return r
end

-- The number of active When conditions when all match, nil when one does not.
function S.LookWhen(look, env)
  local n = 0
  for _, s in ipairs(look.when or {}) do
    if s:sub(1, 1) ~= "~" then
      n = n + 1
      if not whenMatch(s, env) then return nil end
    end
  end
  return n
end

function S.UsesTime(look)
  for _, s in ipairs(look.when or {}) do
    if s:find("time:", 1, true) then return true end
  end
  return false
end

-- Places ----------------------------------------------------------------------------------------
-- kind: "sub" | "zone" | "instance". nil when the player is not in such a place.
function S.PlaceKey(kind, env)
  if kind == "instance" then return env.instance and ("instance:" .. env.instance) or nil end
  if kind == "zone" then return env.zone and ("zone:" .. env.zone) or nil end
  if kind == "sub" then return (env.zone and env.sub) and ("sub:" .. env.zone .. ":" .. env.sub) or nil end
  return nil
end

function S.PlaceName(kind, env)
  if kind == "instance" then return env.instanceName end
  if kind == "zone" then return env.zoneName end
  if kind == "sub" then return env.sub end
  return nil
end

-- Every place the player has been, for the place list (B-04). Off until a Look uses it.
function S.Discover(env)
  local places, now = ns.db.places, time()
  S.foundNew = false
  for _, kind in ipairs({ "instance", "zone", "sub" }) do
    local key = S.PlaceKey(kind, env)
    if key then
      local p = places[key]
      if not p then
        p = { first = now }
        places[key] = p
        S.foundNew = true   -- Core/Sound.lua: a new place was found by this Discover
        ns.Debug("new place %s", key)
      end
      p.name = S.PlaceName(kind, env) or p.name
      if kind == "sub" then p.zoneName = env.zoneName end
      p.last = now
    end
  end
end
