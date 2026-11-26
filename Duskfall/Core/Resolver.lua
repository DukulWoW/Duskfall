-- Duskfall Resolver.lua: the active Style for this character, the Looks that match, and the
-- target value of every channel.
--
-- Winner per channel: the first matching Look that sets it, sorted by
--   1. Where specificity (sub 4 > zone 3 > instance 2 > itype 1 > everywhere 0)
--   2. number of When conditions (more = more specific)
--   3. character scope before Global
--   4. list order (higher in the list first)
-- Unset channels fall through to the next Look, then to the baseline. Values are offsets from
-- the baseline unless the Look is absolute. Results are clamped.
--
-- Public: R.ActiveStyle(), R.Resolve(env) -> target, source, style, candidates
local ADDON, ns = ...
local R = {}
ns.Resolver = R
local C, S = ns.Channels, ns.Situations

-- The Style naming this character, else the first Global one, else the first Style.
function R.ActiveStyle()
  local guid, global = ns.charKey, nil
  for _, st in ipairs(ns.db.styles) do
    local sc = ns.ScopeOf(st.scope, guid, true)
    if sc == "char" then return st end
    if sc == "global" and not global then global = st end
  end
  return global or ns.db.styles[1]
end

local function byRank(a, b)
  if a.where ~= b.where then return a.where > b.where end
  if a.when ~= b.when then return a.when > b.when end
  if a.char ~= b.char then return a.char > b.char end
  return a.index < b.index
end

function R.Resolve(env)
  local style = R.ActiveStyle()
  local guid = ns.charKey
  local cands = {}
  for i, look in ipairs(style.looks) do
    if look.on ~= false then
      local sc = ns.ScopeOf(look.scope, guid)
      if sc then
        local w = S.LookWhere(look, env)
        local n = w and S.LookWhen(look, env)
        if w and n then
          local isChar = 0
          if sc == "char" then isChar = 1 end
          cands[#cands + 1] = { look = look, where = w, when = n, char = isChar, index = i }
        end
      end
    end
  end
  table.sort(cands, byRank)

  local base = ns.db.baseline or {}
  local target, source = {}, {}
  for _, ch in ipairs(C.list) do
    local k = ch.key
    local v = base[k]
    for _, c in ipairs(cands) do
      local x = c.look.values and tonumber(c.look.values[k])
      if x ~= nil then
        if c.look.absolute then v = x else v = (base[k] or 0) + x end
        source[k] = c.look
        break
      end
    end
    target[k] = C.Clamp(k, v)
  end
  return target, source, style, cands
end
