-- Duskfall Transition.lua: moves the channels to a target. B-01 has Instant only; Fade (B-02)
-- and Adapt (B-03) plug in here and fall back to Instant until then.
-- Public: T.Apply(target, held, why), T.Cancel()
local ADDON, ns = ...
local T = {}
ns.Transition = T
local C = ns.Channels

-- held: key -> true for channels the player moved by hand; those are left alone.
function T.Apply(target, held, why)
  local style = ns.Resolver.ActiveStyle()
  local mode = style.transition and style.transition.mode or "instant"
  if mode ~= "instant" then ns.Debug("%s not built yet, instant (%s)", mode, tostring(why)) end
  for _, ch in ipairs(C.list) do
    if not (held and held[ch.key]) and target[ch.key] ~= nil then C.Write(ch.key, target[ch.key]) end
  end
end

function T.Cancel() end
