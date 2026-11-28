-- Duskfall UI/Places.lua: the Places tab (B-04b). This file is Advanced mode; simple mode (the
-- default) is UI/Simple.lua, and the switch is W.SetAdvanced (title bar).
--   left:  search, L["PL_ACTIVE"] filter, L["PL_HERE"] jump, and the place list: Instances (the five instance
--          types first, then every instance visited) and Zones with their subzones. The number is
--          how many Looks of the active Style use the place (green = one of them is in effect now),
--          grey = no Looks (off). A blue bar marks where you are. Right-click: Forget place.
--          Pinned on top (1.3.0): a Here group with the places you are in (green dot = a Look for it
--          is in effect), then a divider. A double chevron on the Here line opens / closes all.
--   right: the selected place, its Looks (on/off, Delete, "active" / "matches" tags) and the
--          quick-add buttons. Clicking a Look (or adding one) opens the Look editor over the tab.
-- Opening the window selects the place of the Look in effect now, and that Look (Kim).
-- A flat list with open / closed zones, not Blizzard's tree view (untested on Forever).
local ADDON, ns = ...
local UI, W, C, S, D, R = ns.UI, ns.Window, ns.Channels, ns.Situations, ns.Detect, ns.Resolver
local L = ns.L

local LEFT_W = 270
local ROW_H = 20
local LOOK_H = 34
local GREY = "|cff9d9d9d"

local ITYPES = {
  { key = "itype:party", name = L["ITYPE_PARTY"] },
  { key = "itype:raid", name = L["ITYPE_RAID"] },
  { key = "itype:pvp", name = L["ITYPE_PVP"] },
  { key = "itype:arena", name = L["ITYPE_ARENA"] },
  { key = "itype:scenario", name = L["ITYPE_SCENARIO"] },
}
local ITYPE_NAME = {}
for _, it in ipairs(ITYPES) do ITYPE_NAME[it.key] = it.name end

local KIND_TEXT = { sub = L["KIND_SUB"], zone = L["KIND_ZONE"], instance = L["KIND_INSTANCE"], itype = L["KIND_ITYPE"] }

local WHEN_TEXT = {
  indoors = L["WHEN_INDOORS"], outdoors = L["WHEN_OUTDOORS"], resting = L["WHEN_RESTING"], combat = L["WHEN_COMBAT"],
  mounted = L["WHEN_MOUNTED"], swimming = L["WHEN_SWIMMING"], underwater = L["WHEN_UNDERWATER"], ghost = L["WHEN_GHOST"],
  ["time:dawn"] = L["WHEN_DAWN"], ["time:day"] = L["WHEN_DAY"], ["time:dusk"] = L["WHEN_DUSK"], ["time:night"] = L["WHEN_NIGHT"],
}

-- Helpers ----------------------------------------------------------------------------------------
local function kindOf(key) return key and key:match("^(%a+):") end

local function stripOff(s)
  if s:sub(1, 1) == "~" then return s:sub(2), true end
  return s, false
end

local function subParts(key)
  local id, name = key:match("^sub:(%d+):(.+)$")
  return id, name
end

-- The zone a subzone key belongs to ("zone:<id>"), nil for other kinds.
local function zoneKeyOf(key)
  local id = subParts(key)
  if id then return "zone:" .. id end
  return nil
end

local function groupOf(key)
  local k = kindOf(key)
  if k == "instance" or k == "itype" then return "g:inst" end
  return "g:zones"
end

local function placeName(key)
  if ITYPE_NAME[key] then return ITYPE_NAME[key] end
  local p = ns.db.places[key]
  if p and p.name then return p.name end
  local _, sub = subParts(key)
  if sub then return sub end
  -- A zone not visited yet (the starter Style, an import): the game's map name
  if key:match("^zone:%d+$") then
    local info = C_Map.GetMapInfo(tonumber(key:match("%d+")))
    if info and info.name then return info.name end
  end
  return key
end

local function zoneName(zkey)
  local p = ns.db.places[zkey]
  if p and p.name then return p.name end
  local id = zkey:match("^zone:(%d+)$")
  local info = id and C_Map.GetMapInfo(tonumber(id))
  return (info and info.name) or zkey
end

local function usesPlace(look, key)
  for _, s in ipairs(look.where or {}) do
    local k, off = stripOff(s)
    if k == key then return true, off end
  end
  return false
end

-- place key -> number of Looks using it, in the given Styles.
local function countIn(styles)
  local n = {}
  for _, st in ipairs(styles) do
    for _, look in ipairs(st.looks) do
      local seen = {}
      for _, s in ipairs(look.where or {}) do
        local k = stripOff(s)
        if not seen[k] then
          seen[k] = true
          n[k] = (n[k] or 0) + 1
        end
      end
    end
  end
  return n
end

-- Does this single place match where the player is?
local function isHere(key, env)
  return env ~= nil and S.LookWhere({ where = { key } }, env) ~= nil
end

-- The most specific place the player is in.
local function currentKey(env)
  if not env then return nil end
  return S.PlaceKey("instance", env) or S.PlaceKey("sub", env) or S.PlaceKey("zone", env)
end

-- Looks that set a channel right now, and Looks that match but are outranked.
local function liveSets()
  local st = D.state
  local active, matching = {}, {}
  for _, look in pairs(st.source or {}) do active[look] = true end
  for _, c in ipairs(st.cands or {}) do matching[c.look] = true end
  return active, matching
end

-- The best-ranked Look in effect that names a place, and the place of it that matches here.
local function winnerPlace(env)
  local active = liveSets()
  for _, c in ipairs(D.state.cands or {}) do
    if active[c.look] then
      local bestK, bestS
      for _, s in ipairs(c.look.where or {}) do
        if s:sub(1, 1) ~= "~" then
          local sc = S.LookWhere({ where = { s } }, env)
          if sc and (not bestS or sc > bestS) then bestK, bestS = s, sc end
        end
      end
      if bestK then return bestK, c.look end
    end
  end
  return nil
end

local function whenText(s)
  local neg = s:sub(1, 1) == "!"
  if neg then s = s:sub(2) end
  local t
  local tm = s:match("^time:(.+)$")
  if WHEN_TEXT[s] then t = WHEN_TEXT[s] elseif tm then t = tm else t = s end
  if neg then t = L["WHEN_NOT"]:format(t) end
  return t
end

local function valuesText(look)
  local out = {}
  for _, ch in ipairs(C.list) do
    local v = look.values and tonumber(look.values[ch.key])
    if v ~= nil then
      local s = C.Format(ch.key, v)
      if not look.absolute and v >= 0 then s = "+" .. s end
      out[#out + 1] = ch.short .. " " .. s
    end
  end
  if #out == 0 then return GREY .. L["PL_NO_VALUES"] .. "|r" end
  return "|cffffffff" .. table.concat(out, "  ") .. "|r"
end

local function detailText(look, key)
  local parts = { valuesText(look) }
  local when = {}
  for _, s in ipairs(look.when or {}) do
    if s:sub(1, 1) ~= "~" then when[#when + 1] = whenText(s) end
  end
  if #when > 0 then parts[#parts + 1] = table.concat(when, ", ") end
  local others = 0
  for _, s in ipairs(look.where or {}) do
    if stripOff(s) ~= key then others = others + 1 end
  end
  if others > 0 then parts[#parts + 1] = others == 1 and L["PL_OTHER_ONE"] or L["PL_OTHER_MANY"]:format(others) end
  local scope = look.scope
  if type(scope) == "table" and not scope.global and type(scope.chars) == "table" and next(scope.chars) then
    local names = {}
    for guid in pairs(scope.chars) do names[#names + 1] = ns.CharName(guid) end
    table.sort(names)
    local s = L["PL_FOR"]:format(table.concat(names, ", "))
    if not ns.ScopeOf(scope, ns.charKey) then s = GREY .. s .. "|r" end
    parts[#parts + 1] = s
  end
  return table.concat(parts, GREY .. "  /  |r")
end

-- Shared with the Look editor
ns.PlaceUI = { kindOf = kindOf, placeName = placeName, zoneName = zoneName, zoneKeyOf = zoneKeyOf, liveSets = liveSets }

local function changed(why)
  D.ClearHolds()
  D.state.target = nil
  D.Evaluate(why)
end

-- A list's background: a rounded dark well, as Your places in simple mode (Kim)
local function shade(parent)
  return UI.RoundBox(parent, { radius = 8, bottom = { 0, 0, 0, 0.32 }, top = { 0, 0, 0, 0.22 } })
end

-- The tab --------------------------------------------------------------------------------------
-- The tab holds two pages: simple mode (UI/Simple.lua, the default) and this one, Advanced mode.
W.AddTab("places", L["TAB_PLACES"], function(tab)
  UI.Glow(tab, nil, 0.8)
  local page = CreateFrame("Frame", nil, tab)
  page:SetAllPoints()
  page:Hide()

  local selKey, selLook          -- selected place key, selected Look (table)
  local expanded, collapsed = {}, {}   -- zones open, groups closed (this session only)
  local activeOnly = false
  local wantJump = true          -- select the live Look on the next show of this page
  local refreshAll, selectPlace, openEditor

  -- Left ---------------------------------------------------------------------------------------
  local left = CreateFrame("Frame", nil, page)
  left:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
  left:SetWidth(LEFT_W)

  -- The same search box as simple mode (own rounded box, round clear X; Kim)
  local search = UI.SearchBox(left, 160, { placeholder = L["PL_SEARCH"], height = 24,
    onChange = function() if refreshAll then refreshAll() end end })
  search:SetPoint("TOPLEFT", left, "TOPLEFT", 10, -8)

  local active = UI.Check(left, { label = L["PL_ACTIVE"],
    tip = L["PL_ACTIVE_TIP"],
    get = function() return activeOnly end,
    set = function(v) activeOnly = v refreshAll() end })
  active:SetPoint("LEFT", search, "RIGHT", 10, 0)

  -- Open / close every zone (1.3.0, Kim): a double chevron at the end of the Here line. Down = it
  -- opens all (and the groups), up = it closes every zone.
  local canOpen = true       -- set by buildRows: something in the list is closed
  local zonesWithSubs = {}   -- set by buildRows
  local allBtn = CreateFrame("Button", nil, left)
  allBtn:SetSize(20, ROW_H)
  allBtn:SetPoint("TOPRIGHT", left, "TOPRIGHT", -16, -36)
  allBtn.tex = {}
  for i, dy in ipairs({ 3, -3 }) do
    local t = allBtn:CreateTexture(nil, "ARTWORK")
    t:SetSize(13, 13)
    t:SetPoint("CENTER", allBtn, "CENTER", 0, dy)
    t:SetTexture(UI.ART .. "Buttons\\chevron")
    t:SetVertexColor(1, 0.82, 0)
    allBtn.tex[i] = t
  end
  local function allLook(over)
    local turn = canOpen and -math.pi / 2 or math.pi / 2
    for _, t in ipairs(allBtn.tex) do
      t:SetRotation(turn)
      if over then t:SetVertexColor(1, 0.94, 0.62) else t:SetVertexColor(1, 0.82, 0) end
    end
  end
  allBtn:SetScript("OnEnter", function(self)
    allLook(true)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(canOpen and L["PL_OPEN_ALL"] or L["PL_CLOSE_ALL"], 1, 1, 1)
    GameTooltip:Show()
  end)
  allBtn:SetScript("OnLeave", function()
    allLook(false)
    GameTooltip:Hide()
  end)
  allBtn:SetScript("OnClick", function(self)
    if canOpen then
      collapsed = {}
      for _, z in ipairs(zonesWithSubs) do expanded[z] = true end
    else
      expanded = {}
    end
    refreshAll()
    if self:IsMouseOver() then self:GetScript("OnEnter")(self) end
  end)

  local here = CreateFrame("Button", nil, left)
  here:SetPoint("TOPLEFT", left, "TOPLEFT", 8, -36)
  here:SetPoint("RIGHT", allBtn, "LEFT", -2, 0)
  here:SetHeight(ROW_H)
  local hereHL = here:CreateTexture(nil, "HIGHLIGHT")
  hereHL:SetAllPoints()
  hereHL:SetColorTexture(1, 1, 1, 0.08)
  here.text = UI.Label(here, "", "GameFontHighlightSmall")
  here.text:SetPoint("LEFT", here, "LEFT", 4, 0)
  here.text:SetPoint("RIGHT", here, "RIGHT", -4, 0)
  here.text:SetWordWrap(false)
  UI.Tooltip(here, L["PL_HERE"], L["PL_HERE_TIP"])

  local treeBox = CreateFrame("Frame", nil, left)
  treeBox:SetPoint("TOPLEFT", left, "TOPLEFT", 8, -60)
  treeBox:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -18, 6)
  shade(treeBox)
  local box = CreateFrame("Frame", nil, treeBox, "WowScrollBoxList")
  box:SetAllPoints()
  local scroll = CreateFrame("EventFrame", nil, left, "MinimalScrollBar")
  scroll:SetPoint("TOPLEFT", treeBox, "TOPRIGHT", 4, 0)
  scroll:SetPoint("BOTTOMLEFT", treeBox, "BOTTOMRIGHT", 4, 0)

  local function forgetMenu(owner, e)
    if not (MenuUtil and MenuUtil.CreateContextMenu) or e.fixed then return end
    local all = countIn(ns.db.styles)
    local used = all[e.key] or 0
    if kindOf(e.key) == "zone" then
      local id = e.key:match("^zone:(%d+)$")
      for k, n in pairs(all) do
        if subParts(k) == id then used = used + n end
      end
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
      root:CreateTitle(e.name)
      local label = L["PL_FORGET"]
      if used == 1 then label = L["PL_FORGET_USED_ONE"] elseif used > 1 then label = L["PL_FORGET_USED_MANY"]:format(used) end
      local b = root:CreateButton(label, function()
        local places = ns.db.places
        places[e.key] = nil
        if kindOf(e.key) == "zone" then
          local id = e.key:match("^zone:(%d+)$")
          for k in pairs(places) do
            if subParts(k) == id then places[k] = nil end
          end
        end
        if selKey == e.key or (selKey and zoneKeyOf(selKey) == e.key) then selKey, selLook = nil, nil end
        refreshAll()
      end)
      if used > 0 and b and b.SetEnabled then pcall(b.SetEnabled, b, false) end
    end)
  end

  local view = CreateScrollBoxListLinearView()
  -- The divider under the pinned Here group is a short row of its own (as in simple mode)
  local DIVIDER_H = 12
  if view.SetElementExtentCalculator then
    view:SetElementExtentCalculator(function(_, e) return e.row == "divider" and DIVIDER_H or ROW_H end)
  else
    view:SetElementExtent(ROW_H)
  end
  view:SetElementInitializer("Button", function(row, e)
    if not row.div then
      -- Blue at both ends, gold in the middle (as on About and in simple mode)
      row.div = CreateFrame("Frame", nil, row)
      row.div:SetHeight(1)
      row.div:SetPoint("LEFT", row, "LEFT", 10, 0)
      row.div:SetPoint("RIGHT", row, "RIGHT", -10, 0)
      local B = { UI.RING_BLUE[1], UI.RING_BLUE[2], UI.RING_BLUE[3], 0.7 }
      local G = { UI.RING_GOLD[1], UI.RING_GOLD[2], UI.RING_GOLD[3], 0.7 }
      local l = row.div:CreateTexture(nil, "ARTWORK")
      l:SetPoint("TOPLEFT")
      l:SetPoint("BOTTOMRIGHT", row.div, "BOTTOM")
      UI.Gradient(l, "HORIZONTAL", B, G)
      local rr = row.div:CreateTexture(nil, "ARTWORK")
      rr:SetPoint("TOPLEFT", row.div, "TOP")
      rr:SetPoint("BOTTOMRIGHT")
      UI.Gradient(rr, "HORIZONTAL", G, B)
    end
    local isDiv = e.row == "divider"
    row.div:SetShown(isDiv)
    row:EnableMouse(not isDiv)
    if row.name then
      for _, part in ipairs({ row.name, row.count, row.arrow, row.sel, row.bar, row.dot }) do part:SetShown(not isDiv) end
    end
    if isDiv then
      row.data = nil
      return
    end
    if not row.name then
      row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      row.sel = row:CreateTexture(nil, "BACKGROUND", nil, 2)
      row.sel:SetAllPoints()
      row.sel:SetColorTexture(1, 0.82, 0, 0.2)
      local hl = row:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 1, 1, 0.08)
      row.bar = row:CreateTexture(nil, "ARTWORK")
      row.bar:SetSize(3, ROW_H - 4)
      row.bar:SetColorTexture(0.62, 0.71, 1, 1)
      row.bar:SetPoint("LEFT", row, "LEFT", 1, 0)
      -- The green dot of simple mode: in the Here group, a setting for this place is in effect
      row.dot = row:CreateTexture(nil, "ARTWORK")
      row.dot:SetSize(9, 9)
      UI.Gradient(row.dot, "VERTICAL", { 0.05, 0.55, 0.1 }, { 0.55, 1, 0.5 }, UI.ART .. "Shapes\\dot")
      row.arrow = CreateFrame("Button", nil, row)
      row.arrow:SetSize(14, 14)
      -- Our own gold disclosure chevron (Assets/chevron): right = closed, down = open (Kim)
      row.arrowTex = row.arrow:CreateTexture(nil, "ARTWORK")
      row.arrowTex:SetAllPoints()
      row.arrowTex:SetTexture(UI.ART .. "Buttons\\chevron")
      row.arrowTex:SetVertexColor(1, 0.82, 0)
      local arrowHL = row.arrow:CreateTexture(nil, "HIGHLIGHT")
      arrowHL:SetAllPoints()
      arrowHL:SetTexture(UI.ART .. "Buttons\\chevron")
      arrowHL:SetBlendMode("ADD")
      arrowHL:SetVertexColor(1, 0.9, 0.5, 0.6)
      row.arrowHL = arrowHL
      row.count = UI.Label(row, "", "GameFontHighlightSmall")
      row.count:SetPoint("RIGHT", row, "RIGHT", -6, 0)
      row.count:SetJustifyH("RIGHT")
      row.name = UI.Label(row, "", "GameFontHighlightSmall")
      row.name:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
      row.name:SetWordWrap(false)
      row:SetScript("OnEnter", function(self)
        local d = self.data
        if not d or d.row ~= "place" then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(d.name, 1, 1, 1)
        GameTooltip:AddLine(KIND_TEXT[kindOf(d.key)] or "", 0.8, 0.8, 0.8)
        if not d.fixed then GameTooltip:AddLine(L["PL_FORGET_TIP"], 0.6, 0.6, 0.6) end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    row.data = e
    local x = 4 + (e.depth or 0) * 14
    row.arrow:ClearAllPoints()
    row.arrow:SetPoint("LEFT", row, "LEFT", x, 0)
    row.arrow:SetShown(e.open ~= nil)
    if e.open ~= nil then
      local turn = e.open and -math.pi / 2 or 0
      row.arrowTex:SetRotation(turn)
      row.arrowHL:SetRotation(turn)
    end
    row.arrow:SetScript("OnClick", function()
      if e.row == "group" then collapsed[e.key] = (not collapsed[e.key]) or nil
      else expanded[e.key] = (not expanded[e.key]) or nil end
      refreshAll()
    end)
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row, "LEFT", x + 18, 0)
    row.name:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
    row.dot:ClearAllPoints()
    row.dot:SetPoint("LEFT", row, "LEFT", x + 3, 0)
    row.dot:SetShown(e.pinned and e.live or false)
    if e.row == "group" then
      row.name:SetFontObject("GameFontNormal")
      row.name:SetText(e.name)
      row.count:SetText("")
      row.sel:Hide()
      row.bar:Hide()
    else
      row.name:SetFontObject("GameFontHighlightSmall")
      if e.n > 0 then row.name:SetText(e.name) else row.name:SetText(GREY .. e.name .. "|r") end
      if e.n > 0 then
        if e.live then row.count:SetText("|cff40ff40(" .. e.n .. ")|r")
        else row.count:SetText("(" .. e.n .. ")") end
      else
        row.count:SetText("")
      end
      row.sel:SetShown(e.key == selKey)
      row.bar:SetShown(e.here and not e.pinned)   -- in the Here group everything is here
    end
    row:SetScript("OnClick", function(self, button)
      if e.row == "group" then
        collapsed[e.key] = (not collapsed[e.key]) or nil
        refreshAll()
      elseif button == "RightButton" then
        forgetMenu(self, e)
      else
        if e.open ~= nil and selKey == e.key then expanded[e.key] = (not expanded[e.key]) or nil
        elseif e.open == false then expanded[e.key] = true end
        selectPlace(e.key)
      end
    end)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(box, scroll, view)
  UI.AutoHideScroll(box, scroll)

  -- The rows of the list, filtered and sorted.
  local function buildRows()
    local style = R.ActiveStyle()
    local n = countIn({ style })
    local live = {}
    local activeL = liveSets()
    for look in pairs(activeL) do
      for _, s in ipairs(look.where or {}) do
        if s:sub(1, 1) ~= "~" then live[s] = true end
      end
    end
    local env = D.state.env
    local q = (search:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local function passes(key, name, ignoreQuery)
      if activeOnly and (n[key] or 0) <= 0 then return false end
      if not ignoreQuery and q ~= "" and not name:lower():find(q, 1, true) then return false end
      return true
    end
    local function entry(key, name, depth)
      return { row = "place", key = key, name = name, depth = depth, n = n[key] or 0,
               live = live[key] and isHere(key, env), here = isHere(key, env) }
    end
    local rows = {}

    -- Here, pinned at the top (1.3.0, Kim): the instance (and its type), or the zone and the part
    -- of it you are in. Search and Active leave it alone.
    local pinned = {}
    local function pin(key, name, depth, fixed)
      local e = entry(key, name, depth)
      e.pinned, e.here, e.fixed = true, true, fixed
      e.live = live[key] or false
      pinned[#pinned + 1] = e
    end
    if env and env.instance then
      local ik = S.PlaceKey("instance", env)
      local p = ns.db.places[ik]
      pin(ik, (p and p.name) or env.instanceName or ik, 1)
      local tk = env.itype and ("itype:" .. env.itype)
      if tk and ITYPE_NAME[tk] then pin(tk, ITYPE_NAME[tk], 1, true) end
    elseif env then
      local zk, sk = S.PlaceKey("zone", env), S.PlaceKey("sub", env)
      if zk then pin(zk, zoneName(zk), 1) end
      if sk then pin(sk, placeName(sk), zk and 2 or 1) end
    end
    if #pinned > 0 then
      rows[#rows + 1] = { row = "group", key = "g:here", name = L["PL_HERE"], depth = 0, open = not collapsed["g:here"] }
      if not collapsed["g:here"] then for _, e in ipairs(pinned) do rows[#rows + 1] = e end end
      rows[#rows + 1] = { row = "divider", key = "g:div" }
    end

    -- Instances
    local inst = {}
    for _, it in ipairs(ITYPES) do
      if passes(it.key, it.name) then
        local e = entry(it.key, it.name, 1)
        e.fixed = true
        inst[#inst + 1] = e
      end
    end
    local named = {}
    for key, p in pairs(ns.db.places) do
      if kindOf(key) == "instance" then
        local name = p.name or key
        if passes(key, name) then named[#named + 1] = entry(key, name, 1) end
      end
    end
    table.sort(named, function(a, b) return a.name < b.name end)
    for _, e in ipairs(named) do inst[#inst + 1] = e end

    -- Zones and their subzones
    local zones = {}
    local function zone(zkey)
      if not zones[zkey] then zones[zkey] = { key = zkey, name = zoneName(zkey), subs = {} } end
      return zones[zkey]
    end
    for key, p in pairs(ns.db.places) do
      local k = kindOf(key)
      if k == "zone" then zone(key)
      elseif k == "sub" then
        local z = zone(zoneKeyOf(key))
        z.subs[#z.subs + 1] = { key = key, name = p.name or select(2, subParts(key)) or key }
      end
    end
    local zlist = {}
    for _, z in pairs(zones) do zlist[#zlist + 1] = z end
    table.sort(zlist, function(a, b) return a.name < b.name end)
    local zrows = {}
    zonesWithSubs = {}
    local anyClosed = collapsed["g:inst"] or collapsed["g:zones"] or collapsed["g:here"] or false
    for _, z in ipairs(zlist) do
      if #z.subs > 0 then zonesWithSubs[#zonesWithSubs + 1] = z.key end
      local zoneHit = passes(z.key, z.name)
      table.sort(z.subs, function(a, b) return a.name < b.name end)
      local subs = {}
      for _, s in ipairs(z.subs) do
        if passes(s.key, s.name, zoneHit) then subs[#subs + 1] = s end
      end
      -- A zone with active subzones stays in the Active list, greyed if it has no Look itself
      if zoneHit or #subs > 0 then
        local e = entry(z.key, z.name, 1)
        if #subs > 0 then
          local open = expanded[z.key] or (q ~= "" and not zoneHit)
          e.open = open and true or false
          if not open then anyClosed = true end
          zrows[#zrows + 1] = e
          if open then
            for _, s in ipairs(subs) do zrows[#zrows + 1] = entry(s.key, s.name, 2) end
          end
        else
          zrows[#zrows + 1] = e
        end
      end
    end

    local filtering = activeOnly or q ~= ""
    if #inst > 0 or not filtering then
      rows[#rows + 1] = { row = "group", key = "g:inst", name = L["PL_INSTANCES"], depth = 0, open = not collapsed["g:inst"] }
      if not collapsed["g:inst"] then for _, e in ipairs(inst) do rows[#rows + 1] = e end end
    end
    if #zrows > 0 or not filtering then
      rows[#rows + 1] = { row = "group", key = "g:zones", name = L["PL_ZONES"], depth = 0, open = not collapsed["g:zones"] }
      if not collapsed["g:zones"] then for _, e in ipairs(zrows) do rows[#rows + 1] = e end end
    end
    canOpen = anyClosed and true or false
    allLook(allBtn:IsMouseOver())
    return rows
  end

  local function refreshTree()
    local rows = buildRows()
    local ok = pcall(box.SetDataProvider, box, CreateDataProvider(rows), ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
    if not ok then box:SetDataProvider(CreateDataProvider(rows)) end
    return rows
  end

  local function scrollTo(key)
    if not (box.ScrollToElementDataByPredicate and ScrollBoxConstants) then return end
    pcall(box.ScrollToElementDataByPredicate, box, function(e) return e.key == key end,
      ScrollBoxConstants.AlignCenter, ScrollBoxConstants.NoScrollInterpolation)
  end

  local function refreshHere()
    local env = D.state.env
    local text = "?"
    if env then
      if env.instance then text = env.instanceName or "?"
      elseif env.sub then text = (env.zoneName or "?") .. " > " .. env.sub
      elseif env.zoneName then text = env.zoneName end
    end
    here.text:SetText("|cff9fb4ff" .. L["PL_HERE_LABEL"] .. "|r " .. text)
  end

  -- Right --------------------------------------------------------------------------------------
  local right = CreateFrame("Frame", nil, page)
  right:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT_W + 14, 0)
  right:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 0)

  local empty = UI.Label(right, L["PL_PICK"], "GameFontHighlight")
  empty:SetPoint("CENTER")

  local detail = CreateFrame("Frame", nil, right)
  detail:SetAllPoints()

  local title = UI.Header(detail, "")
  title:SetFontObject("GameFontNormalLarge")
  title:SetPoint("TOPLEFT", detail, "TOPLEFT", 4, -12)
  title:SetPoint("RIGHT", detail, "RIGHT", -4, 0)
  title:SetWordWrap(false)
  local kindLine = UI.Label(detail, "")
  kindLine:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  kindLine:SetTextColor(0.7, 0.7, 0.7)

  local listHead = UI.Header(detail, L["PL_LOOKS_HEAD"])
  listHead:SetPoint("TOPLEFT", detail, "TOPLEFT", 4, -60)

  local lookArea = CreateFrame("Frame", nil, detail)
  lookArea:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -78)
  lookArea:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -16, 42)
  shade(lookArea)
  local lookBox = CreateFrame("Frame", nil, lookArea, "WowScrollBoxList")
  lookBox:SetAllPoints()
  local lookScroll = CreateFrame("EventFrame", nil, detail, "MinimalScrollBar")
  lookScroll:SetPoint("TOPLEFT", lookArea, "TOPRIGHT", 4, 0)
  lookScroll:SetPoint("BOTTOMLEFT", lookArea, "BOTTOMRIGHT", 4, 0)
  local noLooks = UI.Label(lookArea, L["PL_NO_LOOKS"])
  noLooks:SetPoint("CENTER")
  noLooks:SetTextColor(0.7, 0.7, 0.7)

  local refreshRight
  local lookView = CreateScrollBoxListLinearView()
  lookView:SetElementExtent(LOOK_H)
  lookView:SetElementInitializer("Button", function(row, e)
    if not row.name then
      row.sel = row:CreateTexture(nil, "BACKGROUND", nil, 2)
      row.sel:SetAllPoints()
      row.sel:SetColorTexture(1, 0.82, 0, 0.2)
      local hl = row:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 1, 1, 0.08)
      row.on = UI.Switch(row, {})
      row.on:SetPoint("LEFT", row, "LEFT", 6, 0)
      UI.Tooltip(row.on, L["ON_OFF"], L["LOOK_OFF_TIP"])
      row.del = UI.Button(row, L["BTN_DELETE"], 64, nil, 20)
      row.del:SetKind("danger")
      row.del:SetPoint("RIGHT", row, "RIGHT", -6, 0)
      row.tag = UI.Label(row, "", "GameFontHighlightSmall")
      row.tag:SetPoint("TOPRIGHT", row, "TOPRIGHT", -78, -4)
      row.tag:SetJustifyH("RIGHT")
      row.name = UI.Label(row, "", "GameFontHighlight")
      row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 48, -3)
      row.name:SetPoint("RIGHT", row.tag, "LEFT", -6, 0)
      row.name:SetWordWrap(false)
      row.info = UI.Label(row, "", "GameFontHighlightSmall")
      row.info:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
      row.info:SetPoint("RIGHT", row.del, "LEFT", -8, 0)
      row.info:SetWordWrap(false)
      row.info:SetTextColor(0.75, 0.75, 0.75)
    end
    local look = e.look
    local name = look.name or "?"
    if e.placeOff then name = name .. GREY .. "  " .. L["PL_PLACE_OFF"] .. "|r" end
    row.name:SetText(name)
    if look.on == false then row.name:SetTextColor(0.6, 0.6, 0.6) else row.name:SetTextColor(1, 1, 1) end
    row.info:SetText(detailText(look, selKey))
    local tag = ""
    if look.on == false then tag = GREY .. L["PL_TAG_OFF"] .. "|r"
    elseif e.active then tag = "|cff40ff40" .. L["PL_TAG_ACTIVE"] .. "|r"
    elseif e.matching then tag = GREY .. L["PL_TAG_MATCHES"] .. "|r" end
    row.tag:SetText(tag)
    row.sel:SetShown(look == selLook)
    row.on:SetChecked(look.on ~= false, true)
    row.on.onToggle = function(self)
      look.on = self:GetChecked() and true or false
      changed("places")
    end
    row.del:SetScript("OnClick", function()
      UI.Confirm(L["LOOK_DELETE_CONFIRM"]:format(look.name or "?"), function()
        local style = R.ActiveStyle()
        for i, l in ipairs(style.looks) do
          if l == look then table.remove(style.looks, i) break end
        end
        if selLook == look then selLook = nil end
        changed("places")
      end)
    end)
    row:SetScript("OnClick", function() openEditor(look) end)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(lookBox, lookScroll, lookView)
  UI.AutoHideScroll(lookBox, lookScroll)

  -- Quick-add: values = what is on screen where it differs from what Duskfall shows (as /dusk save).
  local function quickAdd(when, nameKey)
    if not selKey then return end
    local style = R.ActiveStyle()
    local existing = ns.FindLook(style, selKey, when)
    if existing then
      ns.Print(L["PL_EXISTS"], existing.name or "?")
      openEditor(existing)
      return
    end
    local values, n = {}, 0
    local cur, base = C.ReadAll(), ns.db.baseline
    if cur and base then
      local target = D.state.target or base
      for _, ch in ipairs(C.list) do
        local k = ch.key
        if not C.Same(k, cur[k], target[k]) then
          values[k] = tonumber(C.Format(k, cur[k] - base[k]))
          n = n + 1
        end
      end
    end
    local name = nameKey and L[nameKey]:format(placeName(selKey)) or placeName(selKey)
    local look = { id = ns.NewID("l"), name = name, on = true, scope = { global = true }, absolute = false,
                   where = { selKey }, when = when, values = values }
    table.insert(style.looks, look)
    if n > 0 then ns.Print(L["PL_ADDED"], name) end
    changed("places")
    openEditor(look)
  end

  local addAny = UI.Button(detail, L["PL_ADD_ANY"], 120, function() quickAdd({}, nil) end)
  addAny:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 0, 10)
  UI.Tooltip(addAny, L["PL_ADD_ANY"], L["PL_ADD_ANY_TIP"])
  local addIn = UI.Button(detail, L["PL_ADD_IN"], 120, function() quickAdd({ "indoors" }, "PL_NAME_INDOORS") end)
  addIn:SetPoint("LEFT", addAny, "RIGHT", 8, 0)
  UI.Tooltip(addIn, L["PL_ADD_IN"], L["PL_ADD_IN_TIP"])
  local addNight = UI.Button(detail, L["PL_ADD_NIGHT"], 120, function() quickAdd({ "time:night" }, "PL_NAME_NIGHT") end)
  addNight:SetPoint("LEFT", addIn, "RIGHT", 8, 0)
  UI.Tooltip(addNight, L["PL_ADD_NIGHT"], L["PL_ADD_NIGHT_TIP"])

  local clickTip = UI.Label(detail, L["PL_CLICK_TIP"])
  clickTip:SetPoint("LEFT", listHead, "RIGHT", 10, 0)
  clickTip:SetTextColor(0.65, 0.65, 0.65)

  refreshRight = function()
    if not selKey then
      detail:Hide()
      empty:Show()
      return
    end
    empty:Hide()
    detail:Show()
    title:SetText(placeName(selKey))
    local k = kindOf(selKey)
    local kind = KIND_TEXT[k] or ""
    if k == "sub" then kind = L["PL_SUB_OF"]:format(kind, zoneName(zoneKeyOf(selKey))) end
    local style = R.ActiveStyle()
    kindLine:SetText(kind .. "     " .. L["PL_STYLE"]:format("|cffffffff" .. (style.name or "?") .. "|r"))

    local activeL, matching = liveSets()
    local rows = {}
    local stillThere = false
    for _, look in ipairs(style.looks) do
      local uses, off = usesPlace(look, selKey)
      if uses then
        rows[#rows + 1] = { look = look, placeOff = off, active = activeL[look], matching = matching[look] }
        if look == selLook then stillThere = true end
      end
    end
    if selLook and not stillThere then selLook = nil end
    local ok = pcall(lookBox.SetDataProvider, lookBox, CreateDataProvider(rows), ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
    if not ok then lookBox:SetDataProvider(CreateDataProvider(rows)) end
    noLooks:SetShown(#rows == 0)
    -- Indoors never counts in instances (IsIndoors is false there, A7)
    addIn:SetEnabled(k == "sub" or k == "zone")
  end

  -- The editor covers the whole tab; Back (or ESC) comes back to the list.
  local editor = ns.LookEditor.Create(page, { onClose = function()
    left:Show()
    right:Show()
    refreshAll()
  end })
  openEditor = function(look)
    selLook = look
    left:Hide()
    right:Hide()
    editor:Open(look, selKey)
  end
  page.Back = function()
    if editor:IsShown() then
      editor:Close()
      return true
    end
    return false
  end

  selectPlace = function(key)
    if selKey ~= key then selLook = nil end
    selKey = key
    refreshAll()
  end

  refreshAll = function()
    if not page:IsVisible() then return end
    if editor:IsShown() then
      editor:RefreshNow()
      return
    end
    refreshHere()
    refreshTree()
    refreshRight()
  end

  -- Select a place, open what hides it, clear the filters if they hide it, and scroll to it.
  local function reveal(key, look)
    selKey, selLook = key, look
    collapsed[groupOf(key)] = nil
    local z = zoneKeyOf(key)
    if z then expanded[z] = true end
    local rows = refreshTree()
    local found = false
    for _, e in ipairs(rows) do if e.key == key then found = true break end end
    if not found then
      activeOnly = false
      active:Refresh()
      search:SetText("")
    end
    refreshAll()
    scrollTo(key)
  end

  local function jump(useWinner)
    local env = D.state.env or S.Snapshot()
    local key, look
    if useWinner then key, look = winnerPlace(env) end
    if not key then key = currentKey(env) end
    if not key then refreshAll() return end
    reveal(key, look)
  end

  here:SetScript("OnClick", function() jump(false) end)

  page:SetScript("OnShow", function()
    if wantJump then
      wantJump = false
      -- An open editor stays open (close the window to look at the world, open it again)
      if editor:IsShown() then refreshAll() else jump(true) end
    else
      refreshAll()
    end
  end)
  W.frame:HookScript("OnHide", function() wantJump = true end)
  ns.Listen("EVALUATED", function() refreshAll() end)
  refreshRight()

  -- Simple mode, and the switch between the two -------------------------------------------------
  -- A Look simple mode can't show opens here, in the editor.
  local function openLook(look)
    W.SetAdvanced(true)
    local key
    for _, s in ipairs(look.where or {}) do
      if s:sub(1, 1) ~= "~" then key = s break end
    end
    if key then reveal(key, look) end
    openEditor(look)
  end
  local simple = ns.SimplePlaces.Create(tab, { openAdvanced = openLook })
  local function showMode()
    local adv = ns.cfg.advanced and true or false
    simple:SetShown(not adv)
    page:SetShown(adv)
  end
  tab.Back = function()
    if page:IsShown() and page.Back then return page.Back() end
    return false
  end
  -- Switching to Advanced while a setting is open in simple mode opens that setting (Kim)
  local opening = false
  ns.Listen("MODE", function(adv)
    if adv and not opening and simple:IsShown() and simple.CurrentLook then
      local look = simple.CurrentLook()
      if look then
        opening = true
        ns.Safe(openLook, "open advanced", look)
        opening = false
      end
    end
    showMode()
  end)
  showMode()
end, "left")
