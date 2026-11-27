-- Duskfall Core/Sound.lua: small sounds when walking into a place (Kim, 2026-11-27). Two, each on
-- or off with its own sound (Settings > General):
--   new place       the first time you walk into a place Duskfall has not seen (settings.soundNew, on)
--   setting starts  walking in makes one of your settings take effect (settings.soundActive, off)
-- Only a change of place counts (not indoors, mounted, combat or the clock). Buffer: the sound
-- waits SETTLE seconds after the last change of place, so passing quickly through several areas
-- plays once at most; "setting starts" only when the settings in effect then differ from the last
-- time; never two sounds within GAP seconds. If both apply, "setting starts" plays.
-- Sounds come from LibSharedMedia-3.0 (other addons' sounds too); ours are registered there.
-- Public: ns.Sound.Play(name), ns.Sound.List(), ns.Sound.Label(name), ns.Sound.CHANNELS
local ADDON, ns = ...
local L = ns.L
local SND = {}
ns.Sound = SND

local DIR = "Interface\\AddOns\\Duskfall\\Assets\\Sounds\\"
local OWN = {   -- name -> file, in the order the dropdown lists them
  { "Duskfall: New place", DIR .. "new-zone.ogg" },   -- names are saved keys --noloc
  { "Duskfall: Setting starts", DIR .. "active-zone.ogg" },   --noloc
}
local SETTLE = 1.5
local GAP = 5

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)   --noloc
local ownFile = {}
for _, s in ipairs(OWN) do
  ownFile[s[1]] = s[2]
  if LSM then LSM:Register("sound", s[1], s[2]) end
end

-- { value, label } in the order the dropdown shows them
SND.CHANNELS = {
  { "SFX", L["SND_CH_SFX"] }, { "Master", L["SND_CH_MASTER"] }, { "Ambience", L["SND_CH_AMBIENCE"] },   --noloc
  { "Music", L["SND_CH_MUSIC"] }, { "Dialog", L["SND_CH_DIALOG"] },   --noloc
}

-- Every sound name: ours first, then LibSharedMedia's (without its "None"), sorted.
function SND.List()
  local out = {}
  for _, s in ipairs(OWN) do out[#out + 1] = s[1] end
  if LSM then
    for _, name in ipairs(LSM:List("sound")) do
      if not ownFile[name] and name ~= "None" then out[#out + 1] = name end   --noloc
    end
  end
  return out
end

-- The name a dropdown shows: ours translated (their saved names stay English), others as they are
local OWN_LABEL = { ["Duskfall: New place"] = L["SND_OWN_NEW"], ["Duskfall: Setting starts"] = L["SND_OWN_ACTIVE"] }   --noloc
function SND.Label(name) return OWN_LABEL[name] or name end

local function fileOf(name)
  if ownFile[name] then return ownFile[name] end
  return (LSM and name and LSM:Fetch("sound", name, true)) or OWN[1][2]
end

function SND.Play(name)
  pcall(PlaySoundFile, fileOf(name), ns.cfg.soundChannel or "SFX")
end

-- Watching -----------------------------------------------------------------------------------------
local lastPlace, lastKey, lastPlayedAt, token, pendingNew = nil, nil, -1000, 0, false

local function placeKey(env)
  if not env then return nil end
  return table.concat({ tostring(env.instance), tostring(env.zone), tostring(env.map), tostring(env.sub) }, "|")
end

local function looksKey()
  local ids = {}
  for _, look in ipairs(ns.ActiveLooks and ns.ActiveLooks() or {}) do ids[#ids + 1] = tostring(look.id or look.name) end
  return table.concat(ids, ",")
end

local function wanted() return ns.cfg.enabled and (ns.cfg.soundNew or ns.cfg.soundActive) end

ns.Listen("EVALUATED", function()
  local place = placeKey(ns.Detect.state.env)
  if place == lastPlace then return end
  local first = lastPlace == nil
  lastPlace = place
  if first then lastKey = looksKey() return end   -- logging in is not walking in
  if ns.Situations.foundNew then pendingNew = true end
  if not wanted() then return end
  token = token + 1
  local mine = token
  C_Timer.After(SETTLE, function()
    if mine ~= token then return end
    local isNew = pendingNew
    pendingNew = false
    local key = looksKey()
    local started = key ~= "" and key ~= lastKey
    lastKey = key
    if not wanted() or ns.Detect.state.comparing or ns.Detect.state.preview then return end
    local name
    if started and ns.cfg.soundActive then name = ns.cfg.soundActiveName
    elseif isNew and ns.cfg.soundNew then name = ns.cfg.soundNewName end
    if not name or GetTime() - lastPlayedAt < GAP then return end
    lastPlayedAt = GetTime()
    SND.Play(name)
  end)
end)
