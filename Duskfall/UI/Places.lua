-- Duskfall UI/Places.lua: the Places tab (B-04b).
--   left:  search, "Active" filter, "Here" jump, and the place list: Instances (the five instance
--          types first, then every instance visited) and Zones with their subzones. The number is
--          how many Looks of the active Style use the place (green = one of them is in effect now),
--          grey = no Looks (off). A blue bar marks where you are. Right-click: Forget place.
--   right: the selected place, its Looks (on/off, Delete, "active" / "matches" tags) and the
--          quick-add buttons. Clicking a Look (or adding one) opens the Look editor over the tab.
-- Opening the window selects the place of the Look in effect now, and that Look (Kim).
-- A flat list with open / closed zones, not Blizzard's tree view (untested on Forever).
local ADDON, ns = ...
local UI, W, C, S, D, R = ns.UI, ns.Window, ns.Channels, ns.Situations, ns.Detect, ns.Resolver

local LEFT_W = 270
local ROW_H = 20
local LOOK_H = 34
local GREY = "|cff9d9d9d"

local ITYPES = {
  { key = "itype:party", name = "All dungeons" },
  { key = "itype:raid", name = "All raids" },
  { key = "itype:pvp", name = "All battlegrounds" },
  { key = "itype:arena", name = "All arenas" },
  { key = "itype:scenario", name = "All scenarios" },
}
local ITYPE_NAME = {}
for _, it in ipairs(ITYPES) do ITYPE_NAME[it.key] = it.name end

local KIND_TEXT = { sub = "Subzone", zone = "Zone", instance = "Instance", itype = "Instance type" }

local WHEN_TEXT = {
  indoors = "indoors", outdoors = "outdoors", resting = "resting", combat = "in combat",
  mounted = "mounted", swimming = "swimming", underwater = "underwater", ghost = "ghost",
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
  if tm then t = tm else t = WHEN_TEXT[s] or s end
  if neg then t = "not " .. t end
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
  if #out == 0 then return GREY .. "no values yet|r" end
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
  if others > 0 then parts[#parts + 1] = string.format("+%d other place%s", others, others == 1 and "" or "s") end
  local scope = look.scope
  if type(scope) == "table" and not scope.global and type(scope.chars) == "table" and next(scope.chars) then
    local names = {}
    for guid in pairs(scope.chars) do names[#names + 1] = ns.CharName(guid) end
    table.sort(names)
    local s = "for " .. table.concat(names, ", ")
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

local function shade(parent)
  local t = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
  t:SetAllPoints()
  t:SetColorTexture(0, 0, 0, 0.3)
  return t
end

-- The tab --------------------------------------------------------------------------------------
W.AddTab("places", "Places", function(page)
  UI.Glow(page, nil, 0.8)

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

  local search = CreateFrame("EditBox", nil, left, "SearchBoxTemplate")
  search:SetSize(160, 20)
  search:SetPoint("TOPLEFT", left, "TOPLEFT", 14, -10)
  search:SetAutoFocus(false)

  local active = UI.Check(left, { label = "Active",
    tip = "Only places with Looks.",
    get = function() return activeOnly end,
    set = function(v) activeOnly = v refreshAll() end })
  active:SetPoint("LEFT", search, "RIGHT", 10, 0)

  local here = CreateFrame("Button", nil, left)
  here:SetPoint("TOPLEFT", left, "TOPLEFT", 8, -36)
  here:SetPoint("RIGHT", left, "RIGHT", -4, 0)
  here:SetHeight(ROW_H)
  local hereHL = here:CreateTexture(nil, "HIGHLIGHT")
  hereHL:SetAllPoints()
  hereHL:SetColorTexture(1, 1, 1, 0.08)
  here.text = UI.Label(here, "", "GameFontHighlightSmall")
  here.text:SetPoint("LEFT", here, "LEFT", 4, 0)
  here.text:SetPoint("RIGHT", here, "RIGHT", -4, 0)
  here.text:SetWordWrap(false)
  UI.Tooltip(here, "Here", "Jump to the place you are in.")

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
      local label = "Forget place"
      if used > 0 then label = string.format("Forget place (used by %d Look%s)", used, used == 1 and "" or "s") end
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
  view:SetElementExtent(ROW_H)
  view:SetElementInitializer("Button", function(row, e)
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
      row.arrow = CreateFrame("Button", nil, row)
      row.arrow:SetSize(14, 14)
      row.arrowTex = row.arrow:CreateTexture(nil, "ARTWORK")
      row.arrowTex:SetAllPoints()
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
        if not d.fixed then GameTooltip:AddLine("Right-click: forget place", 0.6, 0.6, 0.6) end
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
      local tex = "Interface\\Buttons\\UI-PlusButton-Up"
      if e.open then tex = "Interface\\Buttons\\UI-MinusButton-Up" end
      row.arrowTex:SetTexture(tex)
    end
    row.arrow:SetScript("OnClick", function()
      if e.row == "group" then collapsed[e.key] = (not collapsed[e.key]) or nil
      else expanded[e.key] = (not expanded[e.key]) or nil end
      refreshAll()
    end)
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row, "LEFT", x + 18, 0)
    row.name:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
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
      row.bar:SetShown(e.here)
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
    for _, z in ipairs(zlist) do
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
      rows[#rows + 1] = { row = "group", key = "g:inst", name = "Instances", depth = 0, open = not collapsed["g:inst"] }
      if not collapsed["g:inst"] then for _, e in ipairs(inst) do rows[#rows + 1] = e end end
    end
    if #zrows > 0 or not filtering then
      rows[#rows + 1] = { row = "group", key = "g:zones", name = "Zones", depth = 0, open = not collapsed["g:zones"] }
      if not collapsed["g:zones"] then for _, e in ipairs(zrows) do rows[#rows + 1] = e end end
    end
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
    here.text:SetText("|cff9fb4ffHere:|r " .. text)
  end

  -- Right --------------------------------------------------------------------------------------
  local right = CreateFrame("Frame", nil, page)
  right:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT_W + 14, 0)
  right:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 0)

  local empty = UI.Label(right, "Pick a place on the left.", "GameFontHighlight")
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

  local listHead = UI.Header(detail, "Looks using this place")
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
  local noLooks = UI.Label(lookArea, "No Looks here, so this place is off. Add one below to switch it on.")
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
      row.on = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
      row.on:SetSize(24, 24)
      row.on:SetPoint("LEFT", row, "LEFT", 4, 0)
      UI.Tooltip(row.on, "On / off", "An off Look is kept but never used.")
      row.del = UI.Button(row, "Delete", 64, nil, 20)
      row.del:SetPoint("RIGHT", row, "RIGHT", -6, 0)
      row.tag = UI.Label(row, "", "GameFontHighlightSmall")
      row.tag:SetPoint("TOPRIGHT", row, "TOPRIGHT", -78, -4)
      row.tag:SetJustifyH("RIGHT")
      row.name = UI.Label(row, "", "GameFontHighlight")
      row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 32, -3)
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
    if e.placeOff then name = name .. GREY .. "  (this place is switched off in it)|r" end
    row.name:SetText(name)
    if look.on == false then row.name:SetTextColor(0.6, 0.6, 0.6) else row.name:SetTextColor(1, 1, 1) end
    row.info:SetText(detailText(look, selKey))
    local tag = ""
    if look.on == false then tag = GREY .. "off|r"
    elseif e.active then tag = "|cff40ff40active|r"
    elseif e.matching then tag = GREY .. "matches, outranked|r" end
    row.tag:SetText(tag)
    row.sel:SetShown(look == selLook)
    row.on:SetChecked(look.on ~= false)
    row.on:SetScript("OnClick", function(self)
      look.on = self:GetChecked() and true or false
      changed("places")
    end)
    row.del:SetScript("OnClick", function()
      UI.Confirm("Delete the Look \"" .. (look.name or "?") .. "\"?", function()
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

  -- Quick-add: values = what is on screen where it differs from what Duskfall shows (as /dusk save).
  local function quickAdd(when, suffix)
    if not selKey then return end
    local style = R.ActiveStyle()
    local existing = ns.FindLook(style, selKey, when)
    if existing then
      ns.Print("Look \"%s\" already exists, opened it.", existing.name or "?")
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
    local name = placeName(selKey) .. suffix
    local look = { id = ns.NewID("l"), name = name, on = true, scope = { global = true }, absolute = false,
                   where = { selKey }, when = when, values = values }
    table.insert(style.looks, look)
    if n > 0 then ns.Print("added Look \"%s\" with the values on screen.", name) end
    changed("places")
    openEditor(look)
  end

  local addAny = UI.Button(detail, "+ Look here", 120, function() quickAdd({}, "") end)
  addAny:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 0, 10)
  UI.Tooltip(addAny, "+ Look here", "A Look for this place with no conditions. Takes the values on screen where you changed them.")
  local addIn = UI.Button(detail, "+ Indoors here", 120, function() quickAdd({ "indoors" }, " (indoors)") end)
  addIn:SetPoint("LEFT", addAny, "RIGHT", 8, 0)
  UI.Tooltip(addIn, "+ Indoors here", "A Look for this place that only counts indoors.")
  local addNight = UI.Button(detail, "+ Night here", 120, function() quickAdd({ "time:night" }, " (night)") end)
  addNight:SetPoint("LEFT", addIn, "RIGHT", 8, 0)
  UI.Tooltip(addNight, "+ Night here", "A Look for this place that only counts at night.")

  local clickTip = UI.Label(detail, "Click a Look to edit it.")
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
    if k == "sub" then kind = kind .. " of " .. zoneName(zoneKeyOf(selKey)) end
    local style = R.ActiveStyle()
    kindLine:SetText(kind .. "     Style: |cffffffff" .. (style.name or "?") .. "|r")

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
  search:HookScript("OnTextChanged", function() refreshAll() end)

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
end, "left")
