-- Duskfall Detect.lua: notices where the player is and what state they are in, waits out doorway
-- flicker, works out the target and applies it. Also the baseline safety (capture, crash check,
-- restore at logout) and manual slider changes (held, never learned).
-- Public: D.Evaluate(why), D.Now(why), D.SetEnabled(on), D.SaveBaseline(), D.ClearHolds(), D.state
local ADDON, ns = ...
local D = {}
ns.Detect = D
local C, S, R, T = ns.Channels, ns.Situations, ns.Resolver, ns.Transition

local TICK = 0.5          -- seconds between looks at indoors / mounted / swimming / clock
local ZONE_SETTLE = 0.2   -- zone events: the subzone text can lag a moment behind

local state = {
  env = nil, target = nil, source = nil, style = nil, cands = nil,
  sig = nil,              -- signature of the last applied state
  pendingSig = nil, pendingAt = 0,
  held = {},              -- key -> value the player set by hand while here
  hinted = false,         -- the hold hint was printed for the current hold
  started = false,
}
D.state = state

-- The parts of the snapshot that decide which Looks match. Clock only when a Look uses time.
local function usesTime(style)
  for _, look in ipairs(style.looks) do
    if look.on ~= false and S.UsesTime(look) then return true end
  end
  return false
end

local function signature(env)
  local b = function(x) if x then return "1" end return "0" end
  local parts = {
    tostring(env.instance), tostring(env.itype), tostring(env.zone), tostring(env.map), tostring(env.sub),
    b(env.indoors), b(env.resting), b(env.combat), b(env.mounted), b(env.swimming), b(env.underwater), b(env.ghost),
  }
  if usesTime(R.ActiveStyle()) then parts[#parts + 1] = env.hour .. ":" .. env.min end
  return table.concat(parts, "|")
end

function D.ClearHolds()
  wipe(state.held)
  state.hinted = false
end

function D.Evaluate(why)
  if not ns.db or not ns.db.baseline or not state.started then return end
  local env = S.Snapshot()
  state.env = env
  state.sig = signature(env)
  state.pendingSig = nil
  S.Discover(env)
  local target, source, style, cands = R.Resolve(env)
  if state.target and not C.SameAll(state.target, target) then D.ClearHolds() end
  state.target, state.source, state.style, state.cands = target, source, style, cands
  if ns.cfg.enabled then T.Apply(target, state.held, why) end
  ns.Debug("evaluate (%s): g %.2f b %d c %d", tostring(why), target.gamma, target.brightness, target.contrast)
  ns.Fire("EVALUATED", why)
end

-- Apply at once, skipping the debounce (zone change, combat).
function D.Now(why)
  D.Evaluate(why)
end

local function tick()
  if not state.started then return end
  local sig = signature(S.Snapshot())
  if sig == state.sig then
    state.pendingSig = nil
    return
  end
  local now = GetTime()
  if sig ~= state.pendingSig then
    state.pendingSig, state.pendingAt = sig, now
    return
  end
  if now - state.pendingAt >= (tonumber(ns.cfg.debounce) or 0.5) then D.Evaluate("change") end
end

function D.SetEnabled(on)
  ns.cfg.enabled = on and true or false
  D.ClearHolds()
  T.Cancel()
  if ns.cfg.enabled then
    D.Evaluate("on")
  elseif ns.db.baseline then
    C.WriteAll(ns.db.baseline)
  end
end

function D.SaveBaseline()
  local cur = C.ReadAll()
  if not cur then return nil end
  ns.db.baseline = cur
  D.ClearHolds()
  state.target = nil
  D.Evaluate("baseline")
  return cur
end

-- Manual changes ---------------------------------------------------------------------------------
ns.On("CVAR_UPDATE", function(name, value)
  if type(name) ~= "string" or not ns.db then return end
  local ch = C.byCVar[name:lower()]
  if not ch or C.IsOurs(name, value) then return end
  local v = tonumber(value) or C.Read(ch.key)
  if v == nil then return end
  if not ns.cfg.enabled then
    -- Off: the values on screen are the player's own, so they are the baseline.
    if ns.db.baseline then ns.db.baseline[ch.key] = v end
    ns.db.lastApplied[ch.key] = v
    return
  end
  state.held[ch.key] = v
  ns.db.lastApplied[ch.key] = v
  ns.Debug("held %s = %s", ch.key, tostring(v))
  if not state.hinted then
    state.hinted = true
    ns.Print("kept your %s change while you are here. |cffffd100/dusk save|r (sub, zone or instance) keeps it for this place, |cffffd100/dusk baseline|r makes it your default.", ch.label)
  end
end)

-- Entering the world -----------------------------------------------------------------------------
local ticker
ns.On("PLAYER_ENTERING_WORLD", function(isInitialLogin, isReloadingUi)
  ns.inCombat = UnitAffectingCombat("player") and true or false
  local cur = C.ReadAll()
  if not cur then
    ns.Print("can't read Gamma, Brightness or Contrast on this client, so Duskfall stays idle.")
    return
  end
  local db = ns.db
  if not db.baseline then
    db.baseline = cur
    ns.Print("your current settings (gamma %.2f, brightness %d, contrast %d) are now your baseline. Type |cffffd100/dusk|r for status.",
      cur.gamma, cur.brightness, cur.contrast)
  elseif isInitialLogin and not C.SameAll(cur, db.baseline) then
    if C.SameAll(cur, db.lastApplied) then
      ns.Print("the last session did not log out cleanly; your baseline is kept.")
    else
      db.baseline = cur
      ns.Print("your settings changed while Duskfall was away; they are your new baseline.")
    end
  end
  state.started = true
  if not ticker then ticker = C_Timer.NewTicker(TICK, function() ns.Safe(tick, "tick") end) end
  local why = "enter"
  if isReloadingUi then why = "reload" end
  C_Timer.After(ZONE_SETTLE, function() ns.Safe(D.Now, "enter", why) end)
end)

local function zoneEvent()
  C_Timer.After(ZONE_SETTLE, function() ns.Safe(D.Now, "zone", "zone") end)
end
ns.On("ZONE_CHANGED", zoneEvent)
ns.On("ZONE_CHANGED_INDOORS", zoneEvent)
ns.On("ZONE_CHANGED_NEW_AREA", zoneEvent)

-- InCombatLockdown can still be false inside PLAYER_REGEN_DISABLED, so combat is tracked here.
ns.On("PLAYER_REGEN_DISABLED", function()
  ns.inCombat = true
  D.Now("combat")
end)
ns.On("PLAYER_REGEN_ENABLED", function()
  ns.inCombat = false
  D.Now("combat ended")
end)

-- Leaving: the game's own settings go back to the player's baseline.
ns.On("PLAYER_LOGOUT", function()
  T.Cancel()
  local db = ns.db
  if not db then return end
  if db.settings.enabled and db.baseline then
    C.WriteAll(db.baseline)
    db.lastApplied = {}
    for k, v in pairs(db.baseline) do db.lastApplied[k] = v end
  else
    db.lastApplied = C.ReadAll() or db.lastApplied
  end
end)
