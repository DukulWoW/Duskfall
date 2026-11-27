-- Duskfall Locales/enUS.lua: every string the player sees, in English (v1.2.0, Kim 2026-11-27).
-- Loads first. Other languages (Locales/<code>.lua) load after it, return at once unless they are
-- the active language, and set only the keys they translate; the rest stays English.
-- Public: ns.L[key] (a missing key shows its own name, "!!KEY" in debug mode), ns.HasL(key),
--         ns.locale (the active language code), ns.LANGS (codes /dusk lang accepts)
-- Testing (Kim): /dusk lang <code> shows another language on any client (DuskfallDB.lang);
-- /dusk pseudo mark puts "@@" before every string, so text that skips ns.L stands out;
-- /dusk pseudo long also makes every word about 30% longer (overflow, pages never scroll).
-- Both need the saved variables while this file runs: the TOC has LoadSavedVariablesFirst.
-- Keys: upper case, a prefix per area; whole sentences with %s so a language can reorder them.
local ADDON, ns = ...

local db = type(DuskfallDB) == "table" and DuskfallDB or nil
ns.LANGS = { "enUS", "zhCN", "zhTW", "deDE", "frFR", "esES", "ruRU", "koKR" }
ns.locale = (db and type(db.lang) == "string" and db.lang ~= "") and db.lang or GetLocale()
if ns.locale == "enGB" then ns.locale = "enUS" end
if ns.locale == "esMX" then ns.locale = "esES" end
local PSEUDO = db and db.pseudo

-- /dusk lang on a client of another script: its fonts lack the letters, so while testing every
-- font object gets one that has them (whole UI). Files verified on an enUS Forever client (S6).
local TEST_FONTS = { zhCN = "Fonts\\ARKai_T.ttf", zhTW = "Fonts\\bKAI00M.TTF", koKR = "Fonts\\2002.TTF",
                     ruRU = "Fonts\\FRIZQT___CYR.TTF" }
local swap = ns.locale ~= GetLocale() and TEST_FONTS[ns.locale]
if swap and GetFonts then
  for _, entry in ipairs(GetFonts() or {}) do
    local fo = type(entry) == "string" and _G[entry] or entry
    if type(fo) == "table" and fo.GetFont and fo.SetFont then
      local _, size, flags = fo:GetFont()
      if size then pcall(fo.SetFont, fo, swap, size, flags or "") end
    end
  end
end

-- Pseudo-locale "long": each run of letters grows by about 30% (its last letter repeated), so
-- wrapping behaves like a longer language. Escapes, links, textures and format specifiers stay.
local PROTECT = { "^|c%x%x%x%x%x%x%x%x", "^|r", "^|H.-|h.-|h", "^|T.-|t", "^|A.-|a", "^|n",
                  "^%%[%-%+ #0]*%d*%.?%d*[%a%%]" }
local function stretch(s)
  local out, i, n = {}, 1, #s
  while i <= n do
    local hit
    for _, p in ipairs(PROTECT) do
      local a, b = s:find(p, i)
      if a then hit = b break end
    end
    if hit then
      out[#out + 1] = s:sub(i, hit)
      i = hit + 1
    else
      local a, b = s:find("^%a+", i)
      if a then
        local w = s:sub(a, b)
        out[#out + 1] = w .. w:sub(-1):rep(math.ceil(#w * 0.3))
        i = b + 1
      else
        out[#out + 1] = s:sub(i, i)
        i = i + 1
      end
    end
  end
  return table.concat(out)
end

local DATA = {}
ns.L = setmetatable({}, {
  __index = function(_, key)
    local v = DATA[key]
    if v == nil then
      if type(key) ~= "string" then return nil end
      return (ns.cfg and ns.cfg.debug) and ("!!" .. key) or key
    end
    if type(v) ~= "string" or not PSEUDO then return v end
    if PSEUDO == "long" then return "@@" .. stretch(v) end
    return "@@" .. v
  end,
  __newindex = function(_, key, value) DATA[key] = value end,
})
function ns.HasL(key) return DATA[key] ~= nil end

local L = ns.L

-- Testing commands (Core/Slash.lua) -----------------------------------------------------------
L["LANG_NOW"] = "language: %s (client %s). Reloading..."
L["LANG_USAGE"] = "/dusk lang <code> or /dusk lang client. Codes: %s."
L["PSEUDO_NOW"] = "pseudo-locale: %s. Reloading..."
L["PSEUDO_USAGE"] = "/dusk pseudo off, mark (@@ before every string) or long (also every word about a third longer)."

-- Shared ---------------------------------------------------------------------------------------
L["CH_GAMMA"] = "Gamma"
L["CH_BRIGHTNESS"] = "Brightness"
L["CH_CONTRAST"] = "Contrast"
L["CH_BLOOM"] = "Bloom"
L["CH_GAMMA_SHORT"] = "G"
L["CH_BRIGHTNESS_SHORT"] = "B"
L["CH_CONTRAST_SHORT"] = "C"
L["CH_BLOOM_SHORT"] = "Bl"
L["PERIOD_DAWN"] = "Dawn"
L["PERIOD_DAY"] = "Day"
L["PERIOD_DUSK"] = "Dusk"
L["PERIOD_NIGHT"] = "Night"
L["EVERYWHERE"] = "Everywhere"
L["SCOPE_GLOBAL"] = "Global"
L["BY_DUKUL"] = "by Dukul"
L["VERSION_FMT"] = "Version %s"
L["MY_STYLE"] = "My Style"

-- Chat: core ----------------------------------------------------------------------------------
L["CORE_ERROR"] = "error in %s: %s"
L["DETECT_HELD_HINT"] = "kept your %s change while you are here. |cffffd100/dusk save|r (sub, zone or instance) keeps it for this place, |cffffd100/dusk baseline|r makes it your default."
L["DETECT_NO_CVARS"] = "can't read Gamma, Brightness or Contrast on this client, so Duskfall stays idle."
L["DETECT_FIRST_BASELINE"] = "your current settings (gamma %.2f, brightness %d, contrast %d, bloom %.2f) are now your baseline. Type |cffffd100/dusk|r for status."
L["DETECT_UNCLEAN"] = "the last session did not log out cleanly; your baseline is kept."
L["DETECT_CHANGED_AWAY"] = "your settings changed while Duskfall was away; they are your new baseline."

-- Sound channels (Settings > General) ---------------------------------------------------------
L["SND_CH_SFX"] = "Sound effects"
L["SND_CH_MASTER"] = "Master"
L["SND_CH_AMBIENCE"] = "Ambience"
L["SND_CH_MUSIC"] = "Music"
L["SND_CH_DIALOG"] = "Dialog"

-- Options > AddOns and key bindings -----------------------------------------------------------
L["BIND_TOGGLE"] = "Toggle Duskfall on/off"
L["BIND_COMPARE"] = "Hold to see before (your own settings)"
L["BIND_PEEK"] = "Hold to brighten"
L["BIND_ON"] = "on."
L["BIND_OFF"] = "off; your baseline is back."
L["OPT_HINT"] = "Gamma, brightness, contrast and bloom for every place. Type /dusk for status."
L["OPT_OPEN"] = "Open Settings"

-- Import from another addon, starter Style ---------------------------------------------------
L["AI_FROM"] = "From %s"
L["AI_LOOK_INDOORS"] = "%s indoors"
L["AI_LOOK_OUTDOORS"] = "%s outdoors"
L["AI_LOOK_TIME"] = "%s (%s)"
L["AI_OTHER_ADDON"] = "the other addon"
L["AI_NOTHING_MATCHED"] = "nothing from %s could be matched to a place."
L["AI_NOTHING_MATCHED_LIST"] = "nothing from %s could be matched to a place: %s."
L["AI_IMPORTED_ONE"] = "imported 1 setting into the Style \"%s\"."
L["AI_IMPORTED_MANY"] = "imported %d settings into the Style \"%s\"."
L["AI_SKIPPED"] = "skipped (no matching place): %s."
L["AI_USE_NOW"] = "Use \"%s\" now?"
L["AI_STARTER"] = "Starter"
L["AI_DARK_PLACES"] = "Dark Places"
L["AI_STARTER_NONE"] = "the starter Style found none of its places."
L["AI_STARTER_USED"] = "using the Style \"%s\": dark places and nights are a little brighter. Change it on the Styles tab."

-- Chat: slash commands (the commands and their words stay English) -----------------------------
L["SL_NOT_READY"] = "not ready yet."
L["SL_ON"] = "on"
L["SL_OFF"] = "off"
L["SL_STATUS_STYLE"] = "Style: %s"
L["SL_INSTANCE"] = "%s (instance %s, %s)"
L["SL_ZONE"] = "%s (zone %s)"
L["SL_UNKNOWN"] = "unknown"
L["SL_FROM_BASELINE"] = "baseline"
L["SL_FROM_LOOK"] = "Look \"%s\""
L["SL_HELD"] = "held at %s"
L["SL_CHANNEL_LINE"] = "(target %s, base %s, from %s)"
L["SL_LOOK_OFF"] = "(off)"
L["SL_LOOK_CHARS"] = "(characters)"
L["SL_WHICH_PLACE_SAVE"] = "which place? |cffffd100/dusk save sub||zone||instance|r"
L["SL_WHICH_PLACE_CLEAR"] = "which place? |cffffd100/dusk clear sub||zone||instance|r"
L["SL_NOT_INSTANCE"] = "you are not in an instance."
L["SL_NO_ZONE_IN_INSTANCE"] = "inside instances there is no zone or subzone; use |cffffd100/dusk save instance|r."
L["SL_NONE_HERE"] = "there is no %s here."
L["SL_BAD_CONDITION"] = "unknown condition \"%s\" (see |cffffd100/dusk help|r)."
L["SL_NO_VALUES"] = "no values to save yet."
L["SL_NOTHING_DIFFERS"] = "nothing differs from what Duskfall already shows here. Move a slider first."
L["SL_LOOK_UPDATED"] = "updated Look \"%s\"."
L["SL_LOOK_SAVED"] = "saved Look \"%s\" in Style \"%s\"."
L["SL_NO_GLOBAL_LOOK"] = "no Global Look for exactly this place and these conditions. |cffffd100/dusk looks|r lists them."
L["SL_LOOK_REMOVED"] = "removed Look \"%s\"."
L["SL_NO_LOOKS"] = "Style \"%s\" has no Looks yet. Try |cffffd100/dusk save zone|r."
L["SL_LOOKS_HEAD"] = "Looks in Style \"%s\" (offsets from baseline):"
L["SL_WHICH_STYLE"] = "which Style? |cffffd100/dusk style|r lists them."
L["SL_STYLE_USED"] = "this character now uses Style \"%s\"."
L["SL_STYLE_NEW_NAME"] = "Style %d"
L["SL_STYLE_CREATED"] = "created Style \"%s\" for this character."
L["SL_STYLES_HEAD"] = "Styles:"
L["SL_UNUSED"] = "unused"
L["SL_STYLE_LINE"] = "(%s, %d Looks)"
L["SL_STYLE_USAGE"] = "/dusk style use <n>, /dusk style new <name>"
L["SL_WHICH_CHAR"] = "which character? |cffffd100/dusk chars|r lists them."
L["SL_NO_CHAR"] = "no known character \"%s\"."
L["SL_CANT_REMOVE_SELF"] = "you can't remove the character you are playing."
L["SL_CHAR_REMOVED"] = "removed %s."
L["SL_SCOPES_EMPTIED"] = "%d scope(s) named only that character: those Looks are now Global, those Styles unused."
L["SL_CHARS_HEAD"] = "known characters:"
L["SL_YOU"] = "(you)"
L["SL_CHAR_LINE"] = "(%s, last seen %s)"
L["SL_CHARS_USAGE"] = "/dusk chars remove <name>"
L["SL_TRANSITION"] = "mode %s; fade %.1fs; adapt to dark %.1fs / %.2f, to light %.1fs / %.2f; time of day %ds; overshoot gap %ds"
L["SL_USAGE_MODE"] = "/dusk mode instant||fade||adapt"
L["SL_USAGE_FADE"] = "/dusk fade <0-30 seconds>"
L["SL_USAGE_ADAPT"] = "/dusk adapt dark||light <0-30 seconds> [strength 0-1]"
L["SL_USAGE_TIMEFADE"] = "/dusk timefade <0-600 seconds>"
L["SL_ADJUST_ON"] = "automatic adjusting on."
L["SL_ADJUST_OFF"] = "automatic adjusting off; your baseline is back."
L["SL_BASELINE_SAVED"] = "baseline saved: gamma %.2f, brightness %d, contrast %d, bloom %.2f."
L["SL_REFRESHED"] = "refreshed: the settings for here are back."
L["SL_DEBUG"] = "debug %s."
