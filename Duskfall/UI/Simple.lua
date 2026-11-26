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
local PREVIEW_SECONDS = 10
local EVERYWHERE = "*"
local GREY = "|cff9d9d9d"
local GREEN = "|cff40ff40"

local SLIDERS = {
  { key = "gamma", min = -1, max = 1, step = 0.05, from = { 0.05, 0.05, 0.09 }, to = { 0.96, 0.93, 0.82 },
    tip = "How light the dark parts of the picture are. The strongest of the four." },
  { key = "brightness", min = -50, max = 50, step = 1, from = { 0.13, 0.1, 0.07 }, to = { 1, 0.93, 0.66 },
    tip = "The whole picture lighter or darker." },
  { key = "contrast", min = -50, max = 50, step = 1, from = { 0.4, 0.4, 0.43 }, to = { 0.96, 0.56, 0.16 },
    tip = "Flat and soft, or deep and punchy." },
  { key = "bloom", min = -1, max = 1, step = 0.05, from = { 0.2, 0.18, 0.26 }, to = { 1, 0.87, 0.56 },
    tip = "The glow around bright light (the game's Bloom Intensity)." },
}

local PERIODS = { "dawn", "day", "dusk", "night" }
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
  local picked = false       -- sel was clicked, so it stays when you walk somewhere else
  local lastPlace
  local previewEnd
  local refresh

  local function current() return findLook(sel) end

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

  local function pick(sh, byClick)
    if noIndoors(sh.key) then sh.io = nil end
    sel = sh
    if byClick then picked = true end
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
  local y = -110
  local SEG_W = LEFT_W - LABEL_W
  local function row(label, seg)
    local l = UI.Label(left, label, "GameFontNormal")
    l:SetPoint("TOPLEFT", left, "TOPLEFT", 12, y - 5)
    seg:SetPoint("TOPLEFT", left, "TOPLEFT", 12 + LABEL_W, y)
    y = y - 34
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
      if not found then table.insert(out, 1, { mine, placeLabel(sel.key), nil, "The place you picked in Your places." }) end
      return out
    end,
    get = function() return sel.key or EVERYWHERE end,
    set = function(v)
      local key = v
      if key == EVERYWHERE then key = nil end
      pick({ key = key, time = sel.time, io = sel.io }, true)
    end })
  row("Place", placeSeg)

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
      pick({ key = sel.key, time = v, io = sel.io }, true)
    end })
  row("Time", timeSeg)

  local ioSeg = UI.Segmented(left, SEG_W, {
    items = function()
      return { { "any", "Inside and out", nil, "Indoors and outdoors." },
               { "indoors", "Only indoors", nil, "Inside buildings and caves the game counts as indoors." },
               { "outdoors", "Only outdoors", nil, "Under the open sky." } }
    end,
    get = function() return sel.io or "any" end,
    set = function(v)
      if v == "any" then v = nil end
      pick({ key = sel.key, time = sel.time, io = v }, true)
    end })
  row("Inside", ioSeg)

  -- Left: the sliders --------------------------------------------------------------------------
  y = y - 10
  local sliders = {}
  for _, def in ipairs(SLIDERS) do
    local ch = C.byKey[def.key]
    local s = UI.LightSlider(left, LEFT_W, { label = ch.label, min = def.min, max = def.max, step = def.step,
      from = def.from, to = def.to, tip = def.tip,
      fmt = function(v)
        local t = C.Format(def.key, v)
        if v > 0 then t = "+" .. t end
        return t
      end,
      get = function()
        local look = current()
        return look and look.values and tonumber(look.values[def.key]) or 0
      end,
      set = function(v) setValue(def.key, v) end })
    s:SetPoint("TOPLEFT", left, "TOPLEFT", 12, y)
    y = y - 36
    sliders[#sliders + 1] = s
  end

  local reset = UI.Button(left, "Reset", 90, function()
    local look = current()
    if not look then return end
    UI.Confirm("Remove the setting \"" .. lookLabel(look) .. "\"?", function()
      removeLook(look)
      stopPreview()
      evaluate()
      refresh(true)
    end)
  end)
  reset:SetPoint("TOPLEFT", left, "TOPLEFT", 12, y - 8)
  UI.Tooltip(reset, "Reset", "Remove this setting: the screen goes back to normal for it.")
  local hint = UI.Label(left, "")
  hint:SetPoint("LEFT", reset, "RIGHT", 12, 0)
  hint:SetPoint("RIGHT", left, "RIGHT", -12, 0)
  hint:SetWordWrap(true)
  hint:SetJustifyV("MIDDLE")
  hint:SetHeight(30)

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

  local area = CreateFrame("Frame", nil, right)
  area:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -58)
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
      root:CreateButton("Copy values", function()
        ns.valueClip = { absolute = look.absolute and true or false, values = UI.DeepCopy(look.values or {}) }
      end)
      local paste = root:CreateButton("Paste values", function()
        local clip = ns.valueClip
        if not clip then return end
        local base, out = ns.db.baseline or {}, {}
        for k, x in pairs(clip.values) do
          x = tonumber(x)
          if x ~= nil and C.byKey[k] and base[k] then
            local same = clip.absolute == (look.absolute and true or false)
            if same then out[k] = x
            elseif look.absolute then out[k] = tonumber(C.Format(k, C.Clamp(k, base[k] + x)))
            else out[k] = tonumber(C.Format(k, x - base[k])) end
          end
        end
        if next(out) == nil then return end
        look.values = out
        stopPreview()
        evaluate()
        refresh(true)
      end)
      if not ns.valueClip and paste and paste.SetEnabled then pcall(paste.SetEnabled, paste, false) end
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
        GameTooltip:AddLine(lookLabel(d.look), 1, 1, 1)
        GameTooltip:AddLine(valuesLine(d.look), 0.8, 0.8, 0.8, true)
        if d.live then GameTooltip:AddLine("In effect where you are now.", 0.25, 1, 0.25) end
        if not d.shape then
          GameTooltip:AddLine(" ")
          GameTooltip:AddLine("Set up in Advanced mode. " .. whyAdvanced(d.look), 0.62, 0.71, 1, true)
          GameTooltip:AddLine("Click to open it there.", 0.62, 0.71, 1)
        end
        GameTooltip:AddLine("Right-click: copy, paste or remove", 0.6, 0.6, 0.6)
        GameTooltip:Show()
      end)
      r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    r.data = e
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
        pick({ key = e.shape.key, time = e.shape.time, io = e.shape.io }, true)
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
    for _, look in ipairs(R.ActiveStyle().looks) do
      rows[#rows + 1] = { look = look, shape = shapeOf(look), live = live[look] or false, label = lookLabel(look):lower() }
    end
    table.sort(rows, function(a, b)
      if a.label ~= b.label then return a.label < b.label end
      return tostring(a.look.id) < tostring(b.look.id)
    end)
    local ok = pcall(box.SetDataProvider, box, CreateDataProvider(rows), ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
    if not ok then box:SetDataProvider(CreateDataProvider(rows)) end
    empty:SetShown(#rows == 0)
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
    refreshHint(env)
    refreshList()
  end

  f:SetScript("OnShow", function()
    local env = D.state.env or S.Snapshot()
    lastPlace = placeID(env)
    picked = false
    sel = defaultShape(env)
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
