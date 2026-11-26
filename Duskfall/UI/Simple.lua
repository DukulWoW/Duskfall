-- Duskfall UI/Simple.lua: the Places tab in simple mode, the default (Kim, 2026-11-26: "What would
-- Apple do?"). One question: how should it look here? Advanced mode (the switch left of the
-- window's close button) shows the full place list and the Look editor instead.
--   left:  where you are and what is in effect; Place / Time / Inside pickers choose which setting
--          the sliders show; four light sliders (0 = no change); Reset.
--   right: Your places: every Look of the active Style in plain words. Click a simple one to
--          adjust it on the left; an Advanced one opens in Advanced mode.
-- A setting is an ordinary Look: Global, offsets, Where = one place or none (everywhere), When =
-- at most one part of the day and indoors or outdoors. Moving a slider off 0 makes the Look; a
-- Look with no values left is removed. Edits show at once where the Look is in effect, otherwise
-- as a 10 second preview.
-- Public: ns.SimplePlaces.Create(parent, hooks) -> frame; hooks = { openAdvanced = fn(look) }
local ADDON, ns = ...
local UI, C, S, D, R = ns.UI, ns.Channels, ns.Situations, ns.Detect, ns.Resolver
local SP = {}
ns.SimplePlaces = SP

local LEFT_W = 440
local LABEL_W = 62
local LIST_ROW_H = 40
local ROW_GAP = 40       -- Place / Time / Inside rows
local SLIDER_GAP = 44    -- the sliders (the mini panel keeps 36)
local PREVIEW_SECONDS = 10
local EVERYWHERE = "*"
local GREY = "|cff9d9d9d"
local GREEN = "|cff40ff40"

local SLIDERS = {
  { key = "gamma", min = -1, max = 1, step = 0.05,
    tip = "How light the dark parts of the picture are. The strongest of the four." },
  { key = "brightness", min = -50, max = 50, step = 1,
    tip = "The whole picture lighter or darker." },
  { key = "contrast", min = -50, max = 50, step = 1,
    tip = "Flat and soft, or deep and punchy." },
  { key = "bloom", min = -1, max = 1, step = 0.05,
    tip = "The glow around bright light (the game's Bloom Intensity)." },
}

local PERIODS = { "dawn", "day", "dusk", "night" }
local PLACE_KIND = { sub = "Part of a zone", zone = "Zone", instance = "Instance", itype = "Every instance of a kind" }
local PERIOD_NAME = { dawn = "Dawn", day = "Day", dusk = "Dusk", night = "Night" }
local PERIOD_PHRASE = { dawn = " at dawn", day = " by day", dusk = " at dusk", night = " at night" }
local ITYPE_NAME = { party = "All dungeons", raid = "All raids", pvp = "All battlegrounds", arena = "All arenas",
                     scenario = "All scenarios" }

-- What a Look is in simple terms -------------------------------------------------------------------
-- { key = place key or nil (everywhere), time = period or nil, io = "indoors" / "outdoors" / nil },
-- or nil when it needs Advanced mode.
local function shapeOf(look)
  if look.on == false or look.absolute then return nil end
  if not UI.ScopeIsGlobal(look.scope) then return nil end
  local where = look.where or {}
  if #where > 1 then return nil end
  local key = where[1]
  if key and key:find("^[~!]") then return nil end
  local time, io
  for _, s in ipairs(look.when or {}) do
    local t = s:match("^time:(%a+)$")
    if t and PERIOD_NAME[t] and not time then time = t
    elseif (s == "indoors" or s == "outdoors") and not io then io = s
    else return nil end
  end
  return { key = key, time = time, io = io }
end

local function sameShape(a, b) return a.key == b.key and a.time == b.time and a.io == b.io end

local function findLook(sh)
  for _, look in ipairs(R.ActiveStyle().looks) do
    local s = shapeOf(look)
    if s and sameShape(s, sh) then return look end
  end
  return nil
end

local function kindOf(key) return key and ns.PlaceUI.kindOf(key) end
local function noIndoors(key) local k = kindOf(key) return k == "instance" or k == "itype" end

-- "Canals, Undercity" (lists) or "Canals" (the Look's name).
local function placeLabel(key, long)
  if not key then return "Everywhere" end
  local P = ns.PlaceUI
  if long and P.kindOf(key) == "sub" then return P.placeName(key) .. ", " .. P.zoneName(P.zoneKeyOf(key)) end
  return P.placeName(key)
end

local function describe(sh, long)
  local s = placeLabel(sh.key, long)
  if sh.io then s = s .. " " .. sh.io end
  if sh.time then s = s .. PERIOD_PHRASE[sh.time] end
  return s
end

local function lookLabel(look)
  local sh = shapeOf(look)
  if sh then return describe(sh, true) end
  return look.name or "?"
end

local function valuesLine(look)
  local out = {}
  for _, ch in ipairs(C.list) do
    local v = look.values and tonumber(look.values[ch.key])
    if v ~= nil then
      local s = C.Format(ch.key, v)
      if not look.absolute and v > 0 then s = "+" .. s end
      out[#out + 1] = ch.label .. " " .. s
    end
  end
  if #out == 0 then return "nothing set" end
  return table.concat(out, ", ")
end

local function whyAdvanced(look)
  if look.on == false then return "It is switched off." end
  if look.absolute then return "It uses fixed values, not changes." end
  if not UI.ScopeIsGlobal(look.scope) then return "It is only for some characters." end
  if #(look.where or {}) > 1 then return "It is for several places." end
  return "It uses conditions simple mode doesn't show."
end

local function newLook(sh)
  local when = {}
  if sh.time then when[#when + 1] = "time:" .. sh.time end
  if sh.io then when[#when + 1] = sh.io end
  local look = { id = ns.NewID("l"), name = describe(sh), on = true, scope = { global = true }, absolute = false,
                 where = sh.key and { sh.key } or {}, when = when, values = {} }
  table.insert(R.ActiveStyle().looks, look)
  return look
end

local function removeLook(look)
  local looks = R.ActiveStyle().looks
  for i, l in ipairs(looks) do
    if l == look then table.remove(looks, i) return end
  end
end

-- Does the Look set every one of its values where the player is now?
local function wins(look, env)
  if S.LookWhere(look, env) == nil or S.LookWhen(look, env) == nil then return false, false end
  local _, source = R.Resolve(env)
  for k in pairs(look.values or {}) do
    if source[k] ~= look then return false, true end
  end
  return true, true
end

-- The setting to show when the page opens: the one in effect here (when simple), else the zone.
local function defaultShape(env)
  local count, best, n = {}, nil, 0
  for _, ch in ipairs(C.list) do
    local look = D.state.source and D.state.source[ch.key]
    if look then
      count[look] = (count[look] or 0) + 1
      if count[look] > n then best, n = look, count[look] end
    end
  end
  local sh = best and shapeOf(best)
  if sh then return sh end
  if env.instance then return { key = "instance:" .. env.instance } end
  return { key = S.PlaceKey("zone", env) }
end

local function placeID(env)
  return tostring(env.instance) .. "|" .. tostring(env.zone) .. "|" .. tostring(env.sub)
end

-- The page -----------------------------------------------------------------------------------------
function SP.Create(parent, hooks)
  hooks = hooks or {}
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()
  f:Hide()

  local sel = {}             -- the setting the sliders show
  local picked = false       -- sel was clicked in Your places, so it stays when you walk somewhere
                             -- else; a pick in the Place / Time / Inside rows follows you (Kim)
  local lastPlace
  local previewEnd
  local refresh

  local function current() return findLook(sel) end
  f.CurrentLook = current   -- UI/Places.lua: Advanced opens the setting being adjusted

  -- Showing edits ------------------------------------------------------------------------------
  local function evaluate()
    D.ClearHolds()
    D.state.target = nil
    D.Evaluate("edit")
  end

  local function stopPreview()
    if not previewEnd then return end
    previewEnd = nil
    if D.state.preview then D.Preview(nil) end
  end

  local pending = false
  local function show()
    if pending then return end
    pending = true
    C_Timer.After(0.04, function()
      pending = false
      local look = current()
      local env = S.Snapshot()
      if look and not wins(look, env) then
        local target = R.Resolve(env)
        local base = ns.db.baseline or {}
        for k, v in pairs(look.values) do target[k] = C.Clamp(k, (base[k] or 0) + v) end
        previewEnd = GetTime() + PREVIEW_SECONDS
        D.Preview(target, PREVIEW_SECONDS)
        C_Timer.After(PREVIEW_SECONDS + 0.1, function() if refresh then refresh() end end)
      else
        -- In effect here (or removed): straight to the screen, no transition
        previewEnd = nil
        D.state.preview = nil
        evaluate()
      end
    end)
  end

  local function setValue(k, v)
    v = tonumber(C.Format(k, v)) or 0
    local look = current()
    if math.abs(v) < 1e-6 then
      if not look then return end
      look.values[k] = nil
      if next(look.values) == nil then removeLook(look) end
    else
      look = look or newLook(sel)
      look.values = look.values or {}
      look.values[k] = v
    end
    show()
  end

  -- how: "list" (Your places: stays when you walk on) or "row" (the pickers: follows you)
  local function pick(sh, how)
    if noIndoors(sh.key) then sh.io = nil end
    sel = sh
    picked = how == "list"
    stopPreview()
    refresh(true)
  end

  -- Left: where you are --------------------------------------------------------------------------
  local left = CreateFrame("Frame", nil, f)
  left:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  left:SetWidth(LEFT_W + 24)

  local card = CreateFrame("Frame", nil, left)
  card:SetPoint("TOPLEFT", left, "TOPLEFT", 12, -10)
  card:SetPoint("TOPRIGHT", left, "TOPRIGHT", -12, -10)
  card:SetHeight(82)
  UI.RoundBox(card, { radius = 10, bottom = { 0, 0, 0, 0.5 }, top = { 0.22, 0.17, 0.1, 0.4 },
    border = { 1, 0.82, 0, 0.25 } })
  local placeText = UI.Label(card, "", "GameFontNormalHuge")
  placeText:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12)
  placeText:SetPoint("RIGHT", card, "RIGHT", -14, 0)
  placeText:SetWordWrap(false)
  local subText = UI.Label(card, "", "GameFontHighlight")
  subText:SetPoint("TOPLEFT", placeText, "BOTTOMLEFT", 0, -7)
  subText:SetPoint("RIGHT", card, "RIGHT", -14, 0)
  subText:SetWordWrap(false)
  local nowText = UI.Label(card, "", "GameFontHighlightSmall")
  nowText:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -7)
  nowText:SetPoint("RIGHT", card, "RIGHT", -14, 0)
  nowText:SetWordWrap(false)

  -- Left: which setting ------------------------------------------------------------------------
  local y = -112
  local SEG_W = LEFT_W - LABEL_W
  local function row(label, seg)
    local l = UI.Label(left, label, "GameFontNormal")
    l:SetPoint("TOPLEFT", left, "TOPLEFT", 12, y - 5)
    seg:SetPoint("TOPLEFT", left, "TOPLEFT", 12 + LABEL_W, y)
    y = y - ROW_GAP
    return l
  end

  local placeSeg = UI.Segmented(left, SEG_W, {
    items = function()
      local env = D.state.env or S.Snapshot()
      local out = {}
      if env.instance then
        out[#out + 1] = { "instance:" .. env.instance, env.instanceName or "This instance", nil, "Only this instance." }
        if ITYPE_NAME[env.itype] then
          out[#out + 1] = { "itype:" .. env.itype, ITYPE_NAME[env.itype], nil, "Every instance of this kind." }
        end
      else
        local sk = S.PlaceKey("sub", env)
        if sk then out[#out + 1] = { sk, env.sub, nil, "Only this part of " .. (env.zoneName or "the zone") .. "." } end
        local zk = S.PlaceKey("zone", env)
        if zk then out[#out + 1] = { zk, env.zoneName or "This zone", nil, "The whole zone, all of its parts." } end
      end
      out[#out + 1] = { EVERYWHERE, "Everywhere", nil, "Everywhere you go. A place's own setting wins over this one." }
      -- A setting picked in Your places for somewhere else comes first
      local mine = sel.key or EVERYWHERE
      local found = false
      for _, it in ipairs(out) do if it[1] == mine then found = true end end
      if not found then
        -- Two places can share a name (Ruins of Lordaeron in Undercity and in Tirisfal): add the zone
        local label = placeLabel(sel.key)
        for _, it in ipairs(out) do if it[2] == label then label = placeLabel(sel.key, true) end end
        table.insert(out, 1, { mine, label, nil, "The place you picked in Your places." })
      end
      return out
    end,
    get = function() return sel.key or EVERYWHERE end,
    set = function(v)
      local key = v
      if key == EVERYWHERE then key = nil end
      -- A place where you are follows you; only the Your places pick (first button) stays put
      pick({ key = key, time = sel.time, io = sel.io }, (picked and key == sel.key) and "list" or "row")
    end })
  local function tip(label, topic, title, text)
    local q = UI.HelpIcon(left, topic, title, text)
    q:SetPoint("LEFT", label, "RIGHT", 3, 0)
  end
  tip(row("Place", placeSeg), "wins", "Place", "Where the setting counts: this part of the zone, the whole zone, or " ..
    "everywhere. The most specific one wins.")

  local timeSeg = UI.Segmented(left, SEG_W, {
    items = function()
      local out = { { "any", "Any time", nil, "Day and night." } }
      for _, p in ipairs(PERIODS) do
        out[#out + 1] = { p, PERIOD_NAME[p], UI.ART .. "ui-" .. p, "Only " .. PERIOD_PHRASE[p]:sub(2) ..
          ". The hours are on Settings > Time of day." }
      end
      return out
    end,
    get = function() return sel.time or "any" end,
    set = function(v)
      if v == "any" then v = nil end
      pick({ key = sel.key, time = v, io = sel.io }, picked and "list" or "row")
    end })
  tip(row("Time", timeSeg), "time", "Time", "Only at one part of the day, or any time.")

  local ioSeg = UI.Segmented(left, SEG_W, {
    items = function()
      return { { "any", "Inside and out", nil, "Indoors and outdoors." },
               { "indoors", "Only indoors", nil, "Inside buildings and caves the game counts as indoors." },
               { "outdoors", "Only outdoors", nil, "Under the open sky." } }
    end,
    get = function() return sel.io or "any" end,
    set = function(v)
      if v == "any" then v = nil end
      pick({ key = sel.key, time = sel.time, io = v }, picked and "list" or "row")
    end })
  tip(row("Inside", ioSeg), "wins", "Inside", "Only indoors, only outdoors, or both. The game decides what " ..
    "counts as indoors; inside dungeons it never does.")

  -- Left: the sliders --------------------------------------------------------------------------
  y = y - 18
  local sliders = {}
  local function sliderOpts(def, lineH)
    local ch = C.byKey[def.key]
    return { label = ch.label, min = def.min, max = def.max, step = def.step,
      from = UI.CHANNEL_GRADIENT[def.key].from, to = UI.CHANNEL_GRADIENT[def.key].to, tip = def.tip,
      -- What you get, as the game's own slider shows it, and the change from your baseline (Kim)
      fmt = function(v)
        local base = ns.db.baseline and ns.db.baseline[def.key] or 0
        local t = C.Format(def.key, v)
        if v > 0 then t = "+" .. t end
        return C.Format(def.key, C.Clamp(def.key, base + v)) .. "  " .. GREY .. "(" .. t .. ")|r"
      end,
      zero = function()
        local base = ns.db.baseline and ns.db.baseline[def.key] or 0
        return GREY .. C.Format(def.key, base) .. "|r"
      end,
      lineH = lineH or SLIDER_GAP,
      get = function()
        local look = current()
        return look and look.values and tonumber(look.values[def.key]) or 0
      end,
      set = function(v) setValue(def.key, v) end }
  end
  for _, def in ipairs(SLIDERS) do
    local s = UI.LightSlider(left, LEFT_W, sliderOpts(def))
    s:SetPoint("TOPLEFT", left, "TOPLEFT", 12, y)
    y = y - SLIDER_GAP
    sliders[#sliders + 1] = s
  end

  -- Values clipboard, shared with the Look editor and the Your places menu (ns.valueClip)
  local function copyValues(look)
    ns.valueClip = { absolute = look.absolute and true or false, values = UI.DeepCopy(look.values or {}) }
  end
  -- The copied values, made fit for a Look that is (not) absolute. nil when none apply.
  local function clipFor(absolute)
    local clip = ns.valueClip
    if not clip then return nil end
    local base, out = ns.db.baseline or {}, {}
    for k, x in pairs(clip.values) do
      x = tonumber(x)
      if x ~= nil and C.byKey[k] and base[k] then
        if clip.absolute == (absolute and true or false) then out[k] = x
        elseif absolute then out[k] = tonumber(C.Format(k, C.Clamp(k, base[k] + x)))
        else out[k] = tonumber(C.Format(k, x - base[k])) end
      end
    end
    return next(out) and out or nil
  end
  -- Paste into a Look, or (look nil) into the setting the pickers show, made if it is missing:
  -- set it up for Any time by mistake, Copy, pick Night, Paste (Kim)
  local function pasteValues(look)
    local vals = clipFor(look and look.absolute)
    if not vals then return end
    look = look or newLook(sel)
    look.values = vals
    stopPreview()
    show()
    refresh(true)
  end

  -- Reset, Mini panel, Copy and Paste in a rounded box at the bottom, the hint just above (Kim)
  local actions = CreateFrame("Frame", nil, left)
  actions:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 12, 8)
  actions:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -12, 8)
  actions:SetHeight(46)
  UI.RoundBox(actions, { radius = 10, bottom = { 0, 0, 0, 0.5 }, top = { 0.22, 0.17, 0.1, 0.4 },
    border = { 1, 0.82, 0, 0.25 } })
  local reset = UI.Button(actions, "Reset", 76, function()
    local look = current()
    if not look then return end
    UI.Confirm("Remove the setting \"" .. lookLabel(look) .. "\"?", function()
      removeLook(look)
      stopPreview()
      evaluate()
      refresh(true)
    end)
  end)
  reset:SetPoint("LEFT", actions, "LEFT", 10, 0)
  UI.Tooltip(reset, "Reset", "Remove this setting: the screen goes back to normal for it.")
  -- Mini panel (Kim): the window steps aside for a small panel with only the sliders, so the
  -- whole screen shows the change. Back (or closing it) brings the window back.
  local mini, miniSliders, miniTitle, miniHint = nil, {}, nil, nil
  local keepSel = false
  local function refreshMini()
    if not (mini and mini:IsShown()) then return end
    miniTitle:SetText(describe(sel, true))
    for _, sl in ipairs(miniSliders) do sl:Refresh() end
    local look = current()
    local env = S.Snapshot()
    if not look then miniHint:SetText(GREY .. "Nothing set yet.|r")
    elseif wins(look, env) then miniHint:SetText(GREEN .. "In effect here now.|r")
    else miniHint:SetText(GREY .. "Not in effect here: a preview shows while you drag.|r") end
  end
  local function buildMini()
    local m = CreateFrame("Frame", "DuskfallMiniPanel", UIParent)
    m:SetSize(470, 232)
    m:SetFrameStrata("HIGH")
    m:SetClampedToScreen(true)
    m:SetMovable(true)
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")
    m:SetScript("OnDragStart", m.StartMoving)
    m:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local point, _, rel, x, yy = self:GetPoint(1)
      ns.cfg.miniPos = { point = point, rel = rel, x = x, y = yy }
    end)
    local pos = ns.cfg.miniPos
    if type(pos) == "table" and pos.point then m:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x or 0, pos.y or 0)
    else m:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 140) end
    UI.RoundBox(m, { radius = 12, bottom = { 0.03, 0.02, 0.01, 0.72 }, top = { 0.14, 0.11, 0.07, 0.72 },
      border = { 1, 0.82, 0, 0.45 } })
    -- The round icon half out of the top-left corner, as on the main window (Kim)
    local badge = CreateFrame("Frame", nil, m)
    badge:SetSize(52, 52)
    badge:SetPoint("TOPLEFT", m, "TOPLEFT", -16, 16)
    badge:SetFrameLevel(m:GetFrameLevel() + 10)
    local icon = badge:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(UI.ART .. "icon")
    miniTitle = UI.Label(m, "", "GameFontNormalLarge")
    miniTitle:SetPoint("TOPLEFT", m, "TOPLEFT", 46, -16)
    miniTitle:SetPoint("RIGHT", m, "RIGHT", -96, 0)
    miniTitle:SetWordWrap(false)
    local back = UI.Button(m, "Back", 76, function()
      keepSel = true
      m:Hide()
      ns.OpenWindow("places", true)
    end, 22)
    back:SetPoint("TOPRIGHT", m, "TOPRIGHT", -12, -12)
    UI.Tooltip(back, "Back", "Back to the Duskfall window.")
    local yy = -48
    for _, def in ipairs(SLIDERS) do
      local sl = UI.LightSlider(m, 446, sliderOpts(def, 36))
      sl:SetPoint("TOPLEFT", m, "TOPLEFT", 12, yy)
      yy = yy - 36
      miniSliders[#miniSliders + 1] = sl
    end
    miniHint = UI.Label(m, "")
    miniHint:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", 14, 12)
    tinsert(UISpecialFrames, "DuskfallMiniPanel")
    m:Hide()
    mini = m
  end
  local miniBtn = UI.Button(actions, "Mini panel", 104, function()
    if not mini then buildMini() end
    if ns.Window.frame then ns.Window.frame:Hide() end
    mini:Show()
    refreshMini()
  end)
  miniBtn:SetPoint("LEFT", reset, "RIGHT", 8, 0)
  UI.Tooltip(miniBtn, "Mini panel", "Swap this window for a small panel with only the sliders, so you see the " ..
    "whole screen while you adjust. Back brings the window back.")
  ns.Listen("EVALUATED", function() refreshMini() end)

  local pasteBtn
  local copyBtn = UI.Button(actions, "Copy", 76, function()
    local look = current()
    if not look then return end
    copyValues(look)
    if pasteBtn then pasteBtn:SetEnabled(true) end
  end)
  copyBtn:SetPoint("LEFT", miniBtn, "RIGHT", 8, 0)
  UI.Tooltip(copyBtn, "Copy values", "Remember these values, to paste them into another setting.")
  pasteBtn = UI.Button(actions, "Paste", 76, function() pasteValues(current()) end)
  pasteBtn:SetPoint("LEFT", copyBtn, "RIGHT", 8, 0)
  UI.Tooltip(pasteBtn, "Paste values", "Put the copied values here: this place, time and inside / outside. " ..
    "Replaces what is set here.")

  local hint = UI.Label(left, "")
  hint:SetPoint("BOTTOMLEFT", actions, "TOPLEFT", 4, 6)
  hint:SetPoint("RIGHT", actions, "RIGHT", -4, 0)
  hint:SetWordWrap(false)

  -- Right: Your places -------------------------------------------------------------------------
  local right = CreateFrame("Frame", nil, f)
  right:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT_W + 36, 0)
  right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 0)
  local head = UI.Header(right, "Your places")
  head:SetFontObject("GameFontNormalLarge")
  head:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -14)
  local headSub = UI.Label(right, "Click one to adjust it.")
  headSub:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
  headSub:SetTextColor(0.7, 0.7, 0.7)

  local import = UI.Button(right, "Import", 90, function()
    ns.Share.ImportDialog(function() evaluate() refresh(true) end)
  end)
  import:SetPoint("TOPRIGHT", right, "TOPRIGHT", -16, -16)
  UI.Tooltip(import, "Import", "Paste a setting or a Style someone exported (right-click a place > Export).")
  local headHelp = UI.HelpIcon(right, "start", "Your places", "Everything you have set. Click one to adjust it; " ..
    "right-click to copy, paste, export or remove it. Search finds every place you have been.")
  headHelp:SetPoint("LEFT", head, "RIGHT", 6, 0)

  -- Search: empty = your places; typed = your places and every place you have been that match
  local query = ""
  -- 32 high: its bottom lines up with the Here card's on the left (Kim)
  local search = UI.SearchBox(right, 300, { placeholder = "Search all places", height = 32,
    onChange = function(t)
      query = (t or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
      if refresh then refresh(false) end
    end })
  search:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -60)   -- own box: level with the list below
  search:SetPoint("RIGHT", right, "RIGHT", -16, 0)

  local area = CreateFrame("Frame", nil, right)
  area:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -100)
  area:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -16, 8)
  UI.RoundBox(area, { radius = 8, bottom = { 0, 0, 0, 0.32 }, top = { 0, 0, 0, 0.22 } })
  local box = CreateFrame("Frame", nil, area, "WowScrollBoxList")
  box:SetAllPoints()
  local scroll = CreateFrame("EventFrame", nil, right, "MinimalScrollBar")
  scroll:SetPoint("TOPLEFT", area, "TOPRIGHT", 4, 0)
  scroll:SetPoint("BOTTOMLEFT", area, "BOTTOMRIGHT", 4, 0)
  local empty = UI.Label(area, "Nothing set yet.\n\nMove a slider on the left and the place shows up here.")
  empty:SetPoint("CENTER")
  empty:SetWidth(220)
  empty:SetJustifyH("CENTER")
  empty:SetTextColor(0.7, 0.7, 0.7)

  local function removeMenu(owner, look)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
      root:CreateTitle(lookLabel(look))
      -- The same clipboard as the Look editor's Copy / Paste values (ns.valueClip)
      root:CreateButton("Copy values", function() copyValues(look) end)
      local paste = root:CreateButton("Paste values", function() pasteValues(look) end)
      if not ns.valueClip and paste and paste.SetEnabled then pcall(paste.SetEnabled, paste, false) end
      root:CreateButton("Export", function()
        UI.Copy(lookLabel(look), ns.Share.ExportLook(look), owner)
      end)
      root:CreateDivider()
      root:CreateButton("Remove", function()
        UI.Confirm("Remove the setting \"" .. lookLabel(look) .. "\"?", function()
          removeLook(look)
          stopPreview()
          evaluate()
          refresh(true)
        end)
      end)
    end)
  end

  local view = CreateScrollBoxListLinearView()
  view:SetElementExtent(LIST_ROW_H)
  view:SetElementInitializer("Button", function(r, e)
    if not r.name then
      r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      r.sel = r:CreateTexture(nil, "BACKGROUND", nil, 2)
      r.sel:SetAllPoints()
      UI.Gradient(r.sel, "HORIZONTAL", { 1, 0.82, 0, 0.28 }, { 1, 0.82, 0, 0.04 })
      local hl = r:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 1, 1, 0.07)
      r.dot = r:CreateTexture(nil, "ARTWORK")
      r.dot:SetSize(9, 9)
      r.dot:SetPoint("TOPLEFT", r, "TOPLEFT", 7, -9)
      UI.Gradient(r.dot, "VERTICAL", { 0.05, 0.55, 0.1 }, { 0.55, 1, 0.5 }, UI.ART .. "dot")
      r.tag = UI.Label(r, "", "GameFontHighlightSmall")
      r.tag:SetPoint("TOPRIGHT", r, "TOPRIGHT", -8, -6)
      r.tag:SetTextColor(0.62, 0.71, 1)
      r.name = UI.Label(r, "", "GameFontHighlight")
      r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 22, -6)
      r.name:SetPoint("RIGHT", r.tag, "LEFT", -6, 0)
      r.name:SetWordWrap(false)
      r.vals = UI.Label(r, "", "GameFontHighlightSmall")
      r.vals:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
      r.vals:SetPoint("RIGHT", r, "RIGHT", -8, 0)
      r.vals:SetWordWrap(false)
      r.vals:SetTextColor(0.72, 0.72, 0.72)
      r:SetScript("OnEnter", function(self)
        local d = self.data
        if not d then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if d.place then
          GameTooltip:AddLine(d.label, 1, 1, 1)
          GameTooltip:AddLine(d.kind, 0.8, 0.8, 0.8)
          GameTooltip:AddLine("Click to adjust it.", 0.62, 0.71, 1)
          GameTooltip:Show()
          return
        end
        GameTooltip:AddLine(lookLabel(d.look), 1, 1, 1)
        GameTooltip:AddLine(valuesLine(d.look), 0.8, 0.8, 0.8, true)
        if d.live then GameTooltip:AddLine("In effect where you are now.", 0.25, 1, 0.25) end
        if not d.shape then
          GameTooltip:AddLine(" ")
          GameTooltip:AddLine("Set up in Advanced mode. " .. whyAdvanced(d.look), 0.62, 0.71, 1, true)
          GameTooltip:AddLine("Click to open it there.", 0.62, 0.71, 1)
        end
        GameTooltip:AddLine("Right-click: copy, paste, export or remove", 0.6, 0.6, 0.6)
        GameTooltip:Show()
      end)
      r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    r.data = e
    if e.place then
      -- A place from the search, with nothing set for it yet
      r.name:SetText(e.label)
      r.vals:SetText(e.kind)
      r.tag:SetText("")
      r.dot:Hide()
      r.sel:SetShown(sel.key == e.place and not sel.time and not sel.io)
      r.name:SetTextColor(0.85, 0.85, 0.85)
      r:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then pick({ key = e.place }, "list") end
      end)
      return
    end
    r.name:SetText(lookLabel(e.look))
    r.vals:SetText(valuesLine(e.look))
    r.tag:SetText(e.shape and "" or "Advanced")
    r.dot:SetShown(e.live)
    r.sel:SetShown(e.shape ~= nil and sameShape(e.shape, sel))
    if e.look.on == false then r.name:SetTextColor(0.6, 0.6, 0.6) else r.name:SetTextColor(1, 1, 1) end
    r:SetScript("OnClick", function(self, button)
      if button == "RightButton" then
        removeMenu(self, e.look)
      elseif e.shape then
        pick({ key = e.shape.key, time = e.shape.time, io = e.shape.io }, "list")
      elseif hooks.openAdvanced then
        ns.Safe(hooks.openAdvanced, "open advanced", e.look)
      end
    end)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(box, scroll, view)
  UI.AutoHideScroll(box, scroll)

  local function refreshList()
    local live = {}
    for _, look in pairs(D.state.source or {}) do live[look] = true end
    local rows = {}
    local function hit(label) return query == "" or label:find(query, 1, true) ~= nil end
    for _, look in ipairs(R.ActiveStyle().looks) do
      local label = lookLabel(look):lower()
      if hit(label) then
        rows[#rows + 1] = { look = look, shape = shapeOf(look), live = live[look] or false, label = label }
      end
    end
    table.sort(rows, function(a, b)
      if a.label ~= b.label then return a.label < b.label end
      return tostring(a.look.id) < tostring(b.look.id)
    end)
    -- Searching: every place you have been (and the instance types), after your own settings
    if query ~= "" then
      local places = {}
      local function addPlace(key)
        local label = placeLabel(key, true)
        if hit(label:lower()) then
          local k = kindOf(key)
          local kind = PLACE_KIND[k] or ""
          places[#places + 1] = { place = key, label = label, kind = kind, sort = label:lower() }
        end
      end
      for key in pairs(ns.db.places) do addPlace(key) end
      for it in pairs(ITYPE_NAME) do addPlace("itype:" .. it) end
      table.sort(places, function(a, b) return a.sort < b.sort end)
      for _, e in ipairs(places) do rows[#rows + 1] = e end
    end
    local ok = pcall(box.SetDataProvider, box, CreateDataProvider(rows), ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
    if not ok then box:SetDataProvider(CreateDataProvider(rows)) end
    empty:SetShown(#rows == 0)
    if query ~= "" then empty:SetText("Nothing found.")
    else empty:SetText("Nothing set yet.\n\nMove a slider on the left and the place shows up here.") end
  end

  -- Refresh ------------------------------------------------------------------------------------
  local function refreshCard(env)
    placeText:SetText((env.instance and env.instanceName) or env.zoneName or "?")
    local parts = {}
    if not env.instance then
      if env.sub then parts[#parts + 1] = env.sub end
      parts[#parts + 1] = env.indoors and "Indoors" or "Outdoors"
    end
    parts[#parts + 1] = "|T" .. UI.ART .. "ui-" .. env.period .. ":16|t " .. PERIOD_NAME[env.period] ..
      " " .. ns.FormatHour(env.hour, env.min)
    subText:SetText(table.concat(parts, GREY .. "   /   |r"))
    if not ns.cfg.enabled then
      nowText:SetText("|cffff4040Duskfall is switched off.|r")
      return
    end
    local names, seen = {}, {}
    for _, ch in ipairs(C.list) do
      local look = D.state.source and D.state.source[ch.key]
      if look and not seen[look] then
        seen[look] = true
        names[#names + 1] = lookLabel(look)
      end
    end
    if #names == 0 then nowText:SetText("In effect: " .. GREY .. "your normal settings|r")
    else nowText:SetText("In effect: " .. GREEN .. table.concat(names, ", ") .. "|r") end
  end

  local function refreshHint(env)
    local look = current()
    if not look then
      hint:SetText(GREY .. "Nothing set for this yet. Move a slider to change it.|r")
      return
    end
    local won, matches = wins(look, env)
    local pv = previewEnd and D.state.preview and GetTime() < previewEnd
    if won then
      hint:SetText(GREEN .. "In effect here now.|r Changes show at once.")
    elseif matches then
      hint:SetText("|cffffb040Something more specific wins here.|r" .. (pv and " Showing a preview." or ""))
    else
      hint:SetText(GREY .. "Not in effect where you are now." .. (pv and "|r Showing a preview." or "|r"))
    end
  end

  -- full: also the pickers and the sliders (not while a slider is being dragged)
  refresh = function(full)
    if not f:IsVisible() then return end
    local env = D.state.env or S.Snapshot()
    refreshCard(env)
    if full then
      placeSeg:Refresh()
      timeSeg:Refresh()
      ioSeg:SetEnabled(not noIndoors(sel.key))
      for _, s in ipairs(sliders) do s:Refresh() end
    end
    reset:SetEnabled(current() ~= nil)
    copyBtn:SetEnabled(current() ~= nil)
    pasteBtn:SetEnabled(ns.valueClip ~= nil)
    refreshHint(env)
    refreshList()
  end

  f:SetScript("OnShow", function()
    local env = D.state.env or S.Snapshot()
    lastPlace = placeID(env)
    -- Back from the mini panel: keep the setting that was being adjusted
    if keepSel then
      keepSel = false
    else
      picked = false
      sel = defaultShape(env)
    end
    refresh(true)
  end)

  ns.Listen("EVALUATED", function(why)
    if not f:IsVisible() then return end
    if why == "edit" then refresh(false) return end
    local env = D.state.env or S.Snapshot()
    local id = placeID(env)
    if id ~= lastPlace then
      lastPlace = id
      if not picked then sel = defaultShape(env) end
    end
    refresh(true)
  end)
  ns.Listen("MODE", function() if f:IsVisible() then refresh(true) end end)

  return f
end
