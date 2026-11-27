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

-- Shared: buttons, places, conditions ----------------------------------------------------------
L["TAB_PLACES"] = "Places"
L["BTN_COPY"] = "Copy"
L["BTN_PASTE"] = "Paste"
L["BTN_DELETE"] = "Delete"
L["BTN_RESET"] = "Reset"
L["BTN_BACK"] = "Back"
L["BTN_IMPORT"] = "Import"
L["BTN_EXPORT"] = "Export"
L["BTN_REMOVE"] = "Remove"
L["BTN_COMPARE"] = "Compare"
L["COPY_VALUES"] = "Copy values"
L["PASTE_VALUES"] = "Paste values"
L["ON_OFF"] = "On / off"
L["LOOK_OFF_TIP"] = "An off Look is kept but never used."
L["LOOK_DELETE_CONFIRM"] = "Delete the Look \"%s\"?"
L["ITYPE_PARTY"] = "All dungeons"
L["ITYPE_RAID"] = "All raids"
L["ITYPE_PVP"] = "All battlegrounds"
L["ITYPE_ARENA"] = "All arenas"
L["ITYPE_SCENARIO"] = "All scenarios"
L["KIND_SUB"] = "Subzone"
L["KIND_ZONE"] = "Zone"
L["KIND_INSTANCE"] = "Instance"
L["KIND_ITYPE"] = "Instance type"
L["INDOORS"] = "Indoors"
L["OUTDOORS"] = "Outdoors"
L["UNDERWATER"] = "Underwater"
L["WHEN_INDOORS"] = "indoors"
L["WHEN_OUTDOORS"] = "outdoors"
L["WHEN_RESTING"] = "resting"
L["WHEN_COMBAT"] = "in combat"
L["WHEN_MOUNTED"] = "mounted"
L["WHEN_SWIMMING"] = "swimming"
L["WHEN_UNDERWATER"] = "underwater"
L["WHEN_GHOST"] = "ghost"
L["WHEN_DAWN"] = "dawn"
L["WHEN_DAY"] = "day"
L["WHEN_DUSK"] = "dusk"
L["WHEN_NIGHT"] = "night"
L["WHEN_NOT"] = "not %s"

-- Places tab, Advanced mode --------------------------------------------------------------------
L["PL_SEARCH"] = "Search"
L["PL_ACTIVE"] = "Active"
L["PL_ACTIVE_TIP"] = "Only places with Looks."
L["PL_HERE"] = "Here"
L["PL_HERE_TIP"] = "Jump to the place you are in."
L["PL_HERE_LABEL"] = "Here:"
L["PL_INSTANCES"] = "Instances"
L["PL_ZONES"] = "Zones"
L["PL_FORGET"] = "Forget place"
L["PL_FORGET_USED_ONE"] = "Forget place (used by 1 Look)"
L["PL_FORGET_USED_MANY"] = "Forget place (used by %d Looks)"
L["PL_FORGET_TIP"] = "Right-click: forget place"
L["PL_NO_VALUES"] = "no values yet"
L["PL_OTHER_ONE"] = "+1 other place"
L["PL_OTHER_MANY"] = "+%d other places"
L["PL_FOR"] = "for %s"
L["PL_PICK"] = "Pick a place on the left."
L["PL_LOOKS_HEAD"] = "Looks using this place"
L["PL_NO_LOOKS"] = "No Looks here, so this place is off. Add one below to switch it on."
L["PL_PLACE_OFF"] = "(this place is switched off in it)"
L["PL_TAG_OFF"] = "off"
L["PL_TAG_ACTIVE"] = "active"
L["PL_TAG_MATCHES"] = "matches, outranked"
L["PL_EXISTS"] = "Look \"%s\" already exists, opened it."
L["PL_ADDED"] = "added Look \"%s\" with the values on screen."
L["PL_NAME_INDOORS"] = "%s (indoors)"
L["PL_NAME_NIGHT"] = "%s (night)"
L["PL_ADD_ANY"] = "+ Look here"
L["PL_ADD_ANY_TIP"] = "A Look for this place with no conditions. Takes the values on screen where you changed them."
L["PL_ADD_IN"] = "+ Indoors here"
L["PL_ADD_IN_TIP"] = "A Look for this place that only counts indoors."
L["PL_ADD_NIGHT"] = "+ Night here"
L["PL_ADD_NIGHT_TIP"] = "A Look for this place that only counts at night."
L["PL_CLICK_TIP"] = "Click a Look to edit it."
L["PL_SUB_OF"] = "%s of %s"
L["PL_STYLE"] = "Style: %s"

-- Places tab, simple mode ----------------------------------------------------------------------
L["SP_TIP_GAMMA"] = "How light the dark parts of the picture are. The strongest of the four."
L["SP_TIP_BRIGHTNESS"] = "The whole picture lighter or darker."
L["SP_TIP_CONTRAST"] = "Flat and soft, or deep and punchy."
L["SP_TIP_BLOOM"] = "The glow around bright light (the game's Bloom Intensity)."
L["SP_KIND_SUB"] = "Part of a zone"
L["SP_KIND_ITYPE"] = "Every instance of a kind"
L["SP_IO_INDOORS"] = "%s indoors"
L["SP_IO_OUTDOORS"] = "%s outdoors"
L["SP_IO_UNDERWATER"] = "%s underwater"
L["SP_AT_DAWN"] = "%s at dawn"
L["SP_AT_DAY"] = "%s by day"
L["SP_AT_DUSK"] = "%s at dusk"
L["SP_AT_NIGHT"] = "%s at night"
L["SP_COMPARE_TIP"] = "Hold to see your own settings (before); let go to see this place again (after). There is a key binding for it too (Options > Keybindings > AddOns)."
L["SP_NOTHING_SET"] = "nothing set"
L["SP_WHY_OFF"] = "It is switched off."
L["SP_WHY_ABSOLUTE"] = "It uses fixed values, not changes."
L["SP_WHY_CHARS"] = "It is only for some characters."
L["SP_WHY_PLACES"] = "It is for several places."
L["SP_WHY_WHEN"] = "It uses conditions simple mode doesn't show."
L["SP_PLACE"] = "Place"
L["SP_TIME"] = "Time"
L["SP_INSIDE"] = "Inside"
L["SP_THIS_INSTANCE"] = "This instance"
L["SP_ONLY_INSTANCE"] = "Only this instance."
L["SP_EVERY_KIND"] = "Every instance of this kind."
L["SP_ONLY_PART"] = "Only this part of %s."
L["SP_THE_ZONE"] = "the zone"
L["SP_THIS_ZONE"] = "This zone"
L["SP_WHOLE_ZONE"] = "The whole zone, all of its parts."
L["SP_EVERYWHERE_TIP"] = "Everywhere you go. A place's own setting wins over this one."
L["SP_PICKED"] = "The place you picked in Your places."
L["SP_PLACE_TIP"] = "Where the setting counts: this part of the zone, the whole zone, or everywhere. The most specific one wins."
L["SP_ANY_TIME"] = "Any time"
L["SP_ANY_TIME_TIP"] = "Day and night."
L["SP_TIME_DAWN"] = "Only at dawn. The hours are on Settings > Time of day."
L["SP_TIME_DAY"] = "Only by day. The hours are on Settings > Time of day."
L["SP_TIME_DUSK"] = "Only at dusk. The hours are on Settings > Time of day."
L["SP_TIME_NIGHT"] = "Only at night. The hours are on Settings > Time of day."
L["SP_TIME_TIP"] = "Only at one part of the day, or any time."
L["SP_IN_AND_OUT"] = "In and out"
L["SP_IN_AND_OUT_TIP"] = "Indoors, outdoors and underwater."
L["SP_INDOORS_TIP"] = "Inside buildings and caves the game counts as indoors."
L["SP_OUTDOORS_TIP"] = "Under the open sky."
L["SP_UNDERWATER_TIP"] = "With your head under water."
L["SP_INSIDE_TIP"] = "Only indoors, only outdoors, only underwater, or all. The game decides what counts as indoors; inside dungeons it never does, so there it is only underwater or not."
L["SP_REMOVE_CONFIRM"] = "Remove the setting \"%s\"?"
L["SP_RESET_TIP"] = "Remove this setting: the screen goes back to normal for it."
L["SP_MINI_NOTHING"] = "Nothing set yet."
L["SP_IN_EFFECT_HERE"] = "In effect here now."
L["SP_MINI_NOT"] = "Not in effect here: a preview shows while you drag."
L["SP_BACK_TIP"] = "Back to the Duskfall window."
L["SP_MINI"] = "Mini panel"
L["SP_MINI_TIP"] = "Swap this window for a small panel with only the sliders, so you see the whole screen while you adjust. Back brings the window back."
L["SP_COPY_TIP"] = "Remember these values, to paste them into another setting."
L["SP_PASTE_TIP"] = "Put the copied values here: this place, time and inside / outside. Replaces what is set here."
L["SP_YOUR_PLACES"] = "Your places"
L["SP_CLICK_ONE"] = "Click one to adjust it."
L["SP_IMPORT_TIP"] = "Paste a setting or a Style someone exported (right-click a place > Export)."
L["SP_YOUR_PLACES_TIP"] = "Everything you have set. Click one to adjust it; right-click to copy, paste, export or remove it. Search finds every place you have been."
L["SP_SEARCH"] = "Search all places"
L["SP_EMPTY"] = "Nothing set yet.\n\nMove a slider on the left and the place shows up here."
L["SP_NOTHING_FOUND"] = "Nothing found."
L["SP_CLICK_ADJUST"] = "Click to adjust it."
L["SP_LIVE"] = "In effect where you are now."
L["SP_ADVANCED_WHY"] = "Set up in Advanced mode. %s"
L["SP_OPEN_THERE"] = "Click to open it there."
L["SP_RIGHT_CLICK"] = "Right-click: copy, paste, export or remove"
L["SP_ADVANCED"] = "Advanced"
L["SP_OFF"] = "Duskfall is switched off."
L["SP_IN_EFFECT"] = "In effect: %s"
L["SP_NORMAL"] = "your normal settings"
L["SP_HINT_NOTHING"] = "Nothing set for this yet. Move a slider to change it."
L["SP_HINT_AT_ONCE"] = "Changes show at once."
L["SP_HINT_MORE"] = "Something more specific wins here."
L["SP_HINT_PREVIEW"] = "Showing a preview."
L["SP_HINT_NOT_HERE"] = "Not in effect where you are now."

-- Look editor ----------------------------------------------------------------------------------
L["LE_BACK_TIP"] = "Back to the place (ESC)"
L["LE_TITLE"] = "Edit Look"
L["LE_NAME"] = "Name"
L["LE_ON"] = "On"
L["LE_SCOPE"] = "Scope"
L["LE_SCOPE_TIP"] = "Who this Look is for: Global (everyone using this Style), or only the characters you tick."
L["LE_SCOPE_ALL"] = "Apply this scope to all Looks in this Style"
L["LE_SCOPE_ALL_CONFIRM"] = "Give every Look in Style \"%s\" the scope %s?"
L["LE_VALUES"] = "Values"
L["LE_ABSOLUTE"] = "Absolute"
L["LE_ABSOLUTE_TIP"] = "Off: the values are offsets from your baseline (+/-), so they follow it when you change it. On: fixed values."
L["LE_COPY_TIP"] = "Remember this Look's values to paste into another Look."
L["LE_PASTE_TIP"] = "Replace this Look's values with the copied ones."
L["LE_SETS_TIP"] = "On: this Look sets %s. Off: it falls through to the next Look, or your baseline."
L["LE_CURRENT"] = "Current"
L["LE_USE_CURRENT"] = "Use current"
L["LE_USE_CURRENT_TIP"] = "Take the %s on screen now (for example after moving the game's own slider)."
L["LE_FIXED_NOTE"] = "Fixed values: your baseline does not change them."
L["LE_OFFSETS_NOTE"] = "Offsets from your baseline: %s"
L["LE_PREVIEW"] = "Preview"
L["LE_PREVIEW_TIP"] = "Show this Look's values for %d seconds, even where it does not match. Click again to stop."
L["LE_STOP"] = "Stop (%d)"
L["LE_REVERT"] = "Revert"
L["LE_REVERT_TIP"] = "Back to how this Look was when you opened it."
L["LE_DUPLICATE"] = "Duplicate"
L["LE_DUPLICATE_TIP"] = "A copy of this Look, right after it, opened in the editor."
L["LE_LOOK"] = "Look"
L["LE_COPY_NAME"] = "%s (copy)"
L["LE_UP"] = "Up"
L["LE_DOWN"] = "Down"
L["LE_MOVE_UP"] = "Move up"
L["LE_MOVE_DOWN"] = "Move down"
L["LE_ORDER_TIP"] = "Order only decides between two Looks that are equally specific."
L["LE_ORDER"] = "%d of %d"
L["LE_WHERE"] = "Where"
L["LE_ANY_OF"] = "any one of these"
L["LE_NO_PLACES"] = "No places: this Look counts everywhere."
L["LE_ALL_OFF"] = "All places are off: this Look counts everywhere."
L["LE_PLACE_OFF_TIP"] = "A place switched off is kept in the list but not used."
L["LE_REMOVE_PLACE_TIP"] = "Take this place out of the Look."
L["LE_ADD_HERE"] = "Add current place"
L["LE_ADD_PLACE"] = "%s: %s"
L["LE_NO_PLACE_HERE"] = "No place to add here"
L["LE_ADD_TYPE"] = "Add instance type"
L["LE_IN_ZONE"] = "zone"
L["LE_IN_INSTANCE"] = "instance"
L["LE_WHEN"] = "When"
L["LE_ALL_OF"] = "all of these"
L["LE_RESTING"] = "Resting"
L["LE_COMBAT"] = "In combat"
L["LE_MOUNTED"] = "Mounted"
L["LE_SWIMMING"] = "Swimming"
L["LE_GHOST"] = "Ghost"
L["LE_ANY"] = "Any"
L["LE_YES"] = "Yes"
L["LE_NO"] = "No"
L["LE_CUSTOM"] = "Custom"
L["LE_INDOORS_TIP"] = "Yes = indoors, No = outdoors. Inside instances the game never reports indoors."
L["LE_TIME_TIP"] = "Dawn, day, dusk and night follow Settings > Time of day."
L["LE_NOT_TIME"] = "Not %s"
L["LE_FROM_TIME"] = "From"
L["LE_TO_TIME"] = "To"
L["LE_HERE_NOW"] = "Here now"
L["LE_FROM"] = "from %s"
L["LE_PREVIEWING"] = "Previewing"
L["LE_PREVIEWING_SUB"] = "The screen shows this Look's values until the preview ends."
L["LE_OFF"] = "Off"
L["LE_OFF_SUB"] = "Switched off: never used."
L["LE_NOT_CHAR"] = "Not for this character"
L["LE_NOT_CHAR_SUB"] = "Its scope names other characters."
L["LE_IN_EFFECT"] = "In effect"
L["LE_IN_EFFECT_SUB"] = "It sets the screen where you stand now, so edits show at once."
L["LE_MATCHES"] = "Matches, outranked"
L["LE_MATCHES_SUB"] = "A more specific Look wins here (or sets every channel this one sets)."
L["LE_NO_MATCH"] = "Does not match here"
L["LE_NO_MATCH_SUB"] = "Use Preview to see it."
