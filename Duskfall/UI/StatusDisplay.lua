-- Duskfall UI/StatusDisplay.lua (B-06): a small floating display of what Duskfall shows now:
-- the Look in effect (or Baseline / Off) and the live values. Settings > Display:
--   "off"      never
--   "change"   shows itself when the Look in effect changes (or Duskfall is switched on / off),
--              stays while the transition runs, then fades out after settings.statusSeconds
--   "always"   always shown
-- Clicks (Kim, 2026-11-27): left opens the settings for where you are, right closes it. It is
-- dragged only when always shown or after "Move" on the Display page. Position: settings.statusPos.
-- Quick Light slider (Kim, 1.3.0): a row under it (settings.quickLight "status") with one slider that
-- makes here lighter or darker at once: Gamma and Brightness together (Contrast follows with the
-- Style's Clarity). It saves the same setting simple mode makes, for this place (settings.quickLightFor:
-- "place", "io" with indoors / outdoors, "iotime" with the time of day too). While the mouse is on the
-- display it does not fade.
-- Public: ns.StatusDisplay.Refresh(), .Unlock(seconds), .ResetPosition(), .Test(), .Place(f)
local ADDON, ns = ...
local L = ns.L
local UI, D = ns.UI, ns.Detect
local SD = {}
ns.StatusDisplay = SD

local W, H = 280, 46
local LIGHT_H = 30                           -- the Light slider's row
local LIGHT = { gamma = 0.35, brightness = 12 }   -- at full right (left: the same down)
local FADE = 0.6       -- the slow fade out after a change (the windows use UI.FADE_OUT)
local frame
local hideAt          -- GetTime() at which "change" mode starts fading out
local unlockedUntil   -- GetTime() until which it is shown and draggable
local lastKey         -- which Looks were in effect last time (to see a change)
local testing         -- SD.Test: shown as on a change, whatever the mode

local function mode() return (ns.cfg and ns.cfg.statusDisplay) or "change" end

local function place(f)
  f:ClearAllPoints()
  local pos = ns.cfg.statusPos
  if type(pos) == "table" and pos.point then
    f:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x or 0, pos.y or 0)
  elseif Minimap and Minimap.GetLeft and Minimap:GetLeft() then
    -- Default (Kim): just outside the minimap's bottom-left, level with its bottom edge
    f:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMLEFT", -12, 0)
  else
    f:SetPoint("TOP", UIParent, "TOP", 0, -150)
  end
end

-- The setting the Light slider changes: simple mode's shape for where you are
local function lightShape()
  local env = D.state.env or ns.Situations.Snapshot()
  local S = ns.Situations
  local key
  if env.instance then key = "instance:" .. env.instance
  else key = S.PlaceKey("sub", env) or S.PlaceKey("zone", env) end
  local sh = { key = key }
  local how = ns.cfg.quickLightFor or "place"
  if how ~= "place" then
    if env.underwater then sh.io = "underwater"
    elseif not env.instance then sh.io = env.indoors and "indoors" or "outdoors" end
    if how == "iotime" then sh.time = env.period end
  end
  return sh
end

local function lightGet()
  local SP = ns.SimplePlaces
  local look = SP and SP.FindLook(lightShape())
  local v = look and look.values or {}
  if v.gamma then return math.max(-1, math.min(1, v.gamma / LIGHT.gamma)) end
  if v.brightness then return math.max(-1, math.min(1, v.brightness / LIGHT.brightness)) end
  return 0
end

local function lightSet(x)
  local SP = ns.SimplePlaces
  if not SP then return end
  local sh = lightShape()
  local look = SP.FindLook(sh)
  if math.abs(x) < 0.001 then
    if not look then return end
    look.values.gamma, look.values.brightness = nil, nil
    if next(look.values) == nil then SP.RemoveLook(look) end
  else
    look = look or SP.NewLook(sh)
    look.values = look.values or {}
    look.values.gamma = tonumber(string.format("%.2f", LIGHT.gamma * x))
    look.values.brightness = math.floor(LIGHT.brightness * x + (x > 0 and 0.5 or -0.5))
  end
  D.ClearHolds()
  D.state.target = nil
  D.Evaluate("edit")
end

local function lightWanted()
  return ns.cfg.quickLight ~= "off" and ns.cfg.enabled and D.state.comparing ~= "before"
end

local function fill()
  local state = ns.StateText()
  local color = "|cffffd100"
  if state == L["WIN_OFF"] then color = "|cffff4040"
  elseif state == L["BR_BASELINE"] or D.state.comparing == "before" then color = "|cffffffff" end
  frame.look:SetText(color .. state .. "|r")
  frame.values:SetText(ns.ValuesText())
  local want = lightWanted()
  if frame.light:IsShown() ~= want then
    frame.light:SetShown(want)
    frame:SetHeight(want and H + LIGHT_H or H)
  end
  if want and not frame.light:IsMouseOver() then frame.light:Refresh() end   -- not under the user's hand
end

local function build()
  local f = CreateFrame("Button", "DuskfallStatusDisplay", UIParent)
  frame = f
  f:SetSize(W, H)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local function canMove() return mode() == "always" or (unlockedUntil and GetTime() < unlockedUntil) end
  f:SetScript("OnDragStart", function(self)
    if canMove() then self.moving = true self:StartMoving() end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint(1)
    ns.cfg.statusPos = { point = point, rel = rel, x = x, y = y }
    C_Timer.After(0, function() self.moving = nil end)
  end)
  f:SetScript("OnClick", function(self, mb)
    if self.moving then return end
    if mb == "RightButton" then
      if mode() == "always" and not testing then return end   -- always shown: nothing to close
      hideAt, testing = nil, nil
      self:FadeHide()
    elseif ns.OpenWindow then
      ns.OpenWindow("places", true)
    end
  end)
  -- Rounded with a gold edge, as the mini panel (Kim)
  UI.RoundBox(f, { radius = 10, bottom = { 0.02, 0.02, 0.01, 0.72 }, top = { 0.14, 0.11, 0.07, 0.72 },
    border = { 1, 0.82, 0, 0.85 }, sweep = true })   -- gold to blue, as the window frame (Kim)
  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetSize(34, 34)
  icon:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
  icon:SetTexture(UI.ART .. "icon")
  f.look = UI.Label(f, "", "GameFontNormal")
  f.look:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
  f.look:SetPoint("RIGHT", f, "RIGHT", -8, 0)
  f.look:SetWordWrap(false)
  f.values = UI.Label(f, "", "GameFontHighlightSmall")
  f.values:SetPoint("TOPLEFT", f.look, "BOTTOMLEFT", 0, -4)
  f.values:SetPoint("RIGHT", f, "RIGHT", -8, 0)
  f.values:SetWordWrap(false)
  -- Progress (Kim, 2026-11-27): a thin bar along the bottom fills while a fade or Adapt runs
  -- Duskfall blue on the left to gold on the right (Kim), the whole gradient laid out once and shown
  -- through a clip as wide as the change has come. Softer (Kim: the 2 px line was harsh): a faint
  -- track, a 1 px core with a low halo, and it starts under the text, clear of the icon.
  local BAR_X, BAR_R = 48, 12
  local track = f:CreateTexture(nil, "ARTWORK")
  track:SetPoint("TOPLEFT", f, "TOPLEFT", BAR_X, -(H - 9))   -- from the top: the Light row may hang below
  track:SetSize(W - BAR_X - BAR_R, 3)
  track:SetColorTexture(1, 1, 1, 0.06)
  track:Hide()
  local bar = CreateFrame("Frame", nil, f)
  bar:SetPoint("TOPLEFT", f, "TOPLEFT", BAR_X, -(H - 9))
  bar:SetSize(1, 3)
  pcall(bar.SetClipsChildren, bar, true)
  local B, G = UI.RING_BLUE, { 1, 0.82, 0 }
  local halo = bar:CreateTexture(nil, "OVERLAY")
  halo:SetPoint("LEFT", bar, "LEFT", 0, 0)
  halo:SetSize(W - BAR_X - BAR_R, 3)
  UI.Gradient(halo, "HORIZONTAL", { B[1], B[2], B[3], 0.22 }, { G[1], G[2], G[3], 0.22 })
  local core = bar:CreateTexture(nil, "OVERLAY", nil, 1)
  core:SetPoint("LEFT", bar, "LEFT", 0, 0)
  core:SetSize(W - BAR_X - BAR_R, 1)
  UI.Gradient(core, "HORIZONTAL", { B[1], B[2], B[3], 0.7 }, { G[1], G[2], G[3], 0.7 })
  bar:Hide()
  bar.track = track
  f.bar = bar
  -- The Light slider row (hidden while settings.quickLight is "off")
  f.light = UI.LightSlider(f, W - 16, { label = L["QL_LIGHT"], labelW = 52, valueW = 64, min = -1, max = 1,
    step = 0.05, mid = 0, lineH = 12, from = { 0.08, 0.08, 0.12 }, to = { 1, 0.93, 0.66 },
    tip = L["QL_TIP"],
    fmt = function(v)
      local p = math.floor(math.abs(v) * 100 + 0.5)
      return (v > 0 and "+" or "-") .. p .. "%"   --noloc
    end,
    get = lightGet,
    set = function(v) ns.Safe(lightSet, "light slider", v) end })
  f.light:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(H - 4))
  f.light:Hide()
  f.hint = UI.Label(f, L["SD_DRAG"], "GameFontDisableSmall")
  f.hint:SetPoint("TOP", f, "BOTTOM", 0, -2)
  f.hint:Hide()
  place(f)
  UI.Fader(f, { alpha = 1 })
  f:Hide()

  local acc = 0
  local BAR_W = W - 48 - 12
  f:SetScript("OnUpdate", function(self, el)
    local p = ns.Transition.Progress()
    if p then
      bar:SetWidth(math.max(1, BAR_W * p))
      bar:Show()
      bar.track:Show()
    else
      bar:Hide()
      bar.track:Hide()
    end
    acc = acc + el
    if acc < 0.2 then return end
    acc = 0
    fill()
    local now = GetTime()
    local unlocked = unlockedUntil and now < unlockedUntil
    if unlockedUntil and not unlocked then
      unlockedUntil = nil
      SD.Refresh()
      return
    end
    if (mode() == "change" or testing) and not unlocked and hideAt then
      if self:IsMouseOver() then
        hideAt = math.max(hideAt, now + 1.5)   -- the Light slider is being used: stay
      elseif ns.Transition.IsRunning() then
        -- "As long as the change" goes as soon as it is done; else statusSeconds after it
        local after = ns.cfg.statusStay == "change" and 0.2 or (tonumber(ns.cfg.statusSeconds) or 4)
        hideAt = math.max(hideAt, now + after)
      elseif now >= hideAt then
        -- UI.Fader runs the fade every frame (here it stepped with the 0.2 s tick: it stuttered)
        hideAt = nil
        testing = nil
        self:FadeHide(FADE)
      end
    end
  end)
end

-- Seconds it stays after a change shows up: "as long as the change" keeps it 1.5 s at least (an
-- instant change has no length), and the running change keeps it up (OnUpdate).
function SD.Stay()
  if ns.cfg.statusStay == "change" then return 1.5 end
  return tonumber(ns.cfg.statusSeconds) or 4
end

-- Shown / hidden / mouse per the mode; pop = the Look changed ("change" mode shows it).
function SD.Refresh(pop)
  if not ns.cfg then return end
  if not frame then build() end
  local m = mode()
  local unlocked = unlockedUntil and GetTime() < unlockedUntil
  frame:EnableMouse(true)
  frame.hint:SetShown(unlocked and true or false)
  if unlocked or m == "always" then
    hideAt = nil
    fill()
    frame:Show()
  elseif m == "change" then
    if pop then
      hideAt = GetTime() + SD.Stay()
      fill()
      frame:Show()
    end
  else
    hideAt = nil
    frame:Hide()
  end
end

-- Test button (Kim): show it as it shows on a change (stays, then fades), in any mode but "always"
-- (there it is shown anyway).
function SD.Test()
  if not ns.cfg then return end
  if not frame then build() end
  if mode() == "always" then SD.Refresh() return end
  testing = true
  hideAt = GetTime() + SD.Stay()
  fill()
  frame:Show()
end

-- Show it for `seconds` so it can be dragged into place.
function SD.Unlock(seconds)
  unlockedUntil = GetTime() + (seconds or 20)
  SD.Refresh()
end

-- Put f where the status display goes (the update toast); above the display when it shows.
function SD.Place(f)
  if not ns.cfg then return end
  if frame and frame:IsShown() then
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", frame, "TOP", 0, 8)
  else
    place(f)
  end
end

function SD.ResetPosition()
  ns.cfg.statusPos = nil
  if frame then place(frame) end
end

local function lookKey()
  if not ns.cfg.enabled then return "off" end
  local ids = {}
  for _, look in ipairs(ns.ActiveLooks()) do ids[#ids + 1] = tostring(look.id or look.name) end
  return table.concat(ids, ",")
end

ns.Listen("EVALUATED", function(why)
  local key = lookKey()
  local changed = lastKey ~= nil and key ~= lastKey
  lastKey = key
  -- Not while editing or trying a transition: the editor shows it already
  if why == "edit" or why == "demo" or why == "preview end" then changed = false end   --noloc
  SD.Refresh(changed)
end)
ns.Listen("COMPARE", function() SD.Refresh(true) end)
ns.Listen("ONOFF", function()
  lastKey = lookKey()
  SD.Refresh(true)
end)
