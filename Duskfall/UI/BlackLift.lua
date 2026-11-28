-- Duskfall UI/BlackLift.lua (1.3.0, Kim): for screens where the game's Gamma does nothing (some
-- window modes and drivers). With settings.blackLift on (Settings > Baseline, the Gamma card), the
-- Gamma change from the baseline is also drawn as a soft tint over the 3D world: a texture on
-- WorldFrame, so the interface stays untinted and nameplates stay on top (probe A11).
--   lighter: white blended over the world (lifts the dark parts most, white stays white)
--   darker:  black blended over it
-- It follows every Gamma write (Channels C.OnGamma), so fades and Adapt move it too. Off, at the
-- baseline, while comparing and after logout the change is 0 and the tint is hidden.
-- Public: ns.BlackLift.Update()
local ADDON, ns = ...
local C = ns.Channels
local BL = {}
ns.BlackLift = BL

local LIFT_A = 0.25   -- tint alpha per +1.0 Gamma (+0.35, the Light slider's top: 0.09)
local DARK_A = 0.4    -- per -1.0 Gamma
local MAX_A = 0.35
local tex
local shown = -1      -- the alpha drawn now (signed: < 0 = black), -1 = not set yet

local function apply(gamma)
  if not ns.cfg or not ns.db then return end
  local base = ns.db.baseline and ns.db.baseline.gamma
  local d = 0
  if ns.cfg.blackLift and base and gamma then d = gamma - base end
  local a = 0
  if d > 0 then a = math.min(MAX_A, d * LIFT_A) elseif d < 0 then a = -math.min(MAX_A, -d * DARK_A) end
  if math.abs(a) < 0.003 then a = 0 end
  if math.abs(a - shown) < 0.001 then return end
  shown = a
  if a == 0 then
    if tex then tex:Hide() end
    return
  end
  if not tex then
    -- As the A11 probe: a texture on WorldFrame itself (a child frame could cover the nameplates)
    tex = WorldFrame:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(WorldFrame)
  end
  if a > 0 then tex:SetColorTexture(1, 1, 1, a) else tex:SetColorTexture(0, 0, 0, -a) end
  tex:Show()
end

C.OnGamma = apply

-- The switch or the baseline changed: draw it again from the Gamma on screen now.
function BL.Update()
  shown = -1
  apply(C.Read("gamma"))
end

ns.Listen("READY", function() BL.Update() end)
ns.Listen("EVALUATED", function() BL.Update() end)
