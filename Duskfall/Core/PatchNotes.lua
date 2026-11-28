-- Duskfall Core/PatchNotes.lua: the patch notes shown in the window (About > Patch Notes, Help >
-- Patch Notes, the toast after an update). Newest first. kind = "new", "change" or "fix".
-- Only what players need to know, and only against the release before (Kim, 2026-11-27).
-- date = nil while a version is not released yet; set it when tagging, as YYYY-MM-DD (numbers read the
-- same in every language, Kim 2026-11-27).
-- The text of each note is in Locales/enUS.lua (PN_<version>_<nn>), so it can be translated:
-- a new note is a new key there and its L["..."] here.
local ADDON, ns = ...
local L = ns.L

ns.PATCH_NOTES = {
  { version = "1.3.0", date = nil, notes = {
    { "new", L["PN_130_04"] },
    { "new", L["PN_130_06"] },
    { "new", L["PN_130_07"] },
    { "new", L["PN_130_08"] },
    { "new", L["PN_130_09"] },
    { "new", L["PN_130_10"] },
    { "new", L["PN_130_11"] },
    { "new", L["PN_130_12"] },
    { "new", L["PN_130_13"] },
    { "change", L["PN_130_02"] },
    { "change", L["PN_130_01"] },
    { "change", L["PN_130_05"] },
    { "fix", L["PN_130_03"] },
    { "fix", L["PN_130_14"] },
  } },
  { version = "1.2.0", date = "2026-11-27", notes = {
    { "new", L["PN_120_02"] },
    { "new", L["PN_120_01"] },
    { "new", L["PN_120_05"] },
    { "change", L["PN_120_03"] },
    { "change", L["PN_120_04"] },
    { "change", L["PN_120_06"] },
  } },
  { version = "1.1.0", date = "2026-11-27", notes = {
    { "new", L["PN_110_01"] },
    { "new", L["PN_110_02"] },
    { "new", L["PN_110_03"] },
    { "new", L["PN_110_04"] },
    { "new", L["PN_110_05"] },
    { "new", L["PN_110_06"] },
    { "new", L["PN_110_07"] },
    { "new", L["PN_110_08"] },
    { "new", L["PN_110_09"] },
    { "new", L["PN_110_10"] },
    { "new", L["PN_110_11"] },
    { "change", L["PN_110_12"] },
    { "change", L["PN_110_13"] },
    { "change", L["PN_110_14"] },
    { "change", L["PN_110_15"] },
    { "change", L["PN_110_16"] },
    { "change", L["PN_110_17"] },
    { "change", L["PN_110_18"] },
    { "change", L["PN_110_19"] },
    { "change", L["PN_110_20"] },
    { "change", L["PN_110_21"] },
  } },
  { version = "1.0.0", date = "2026-11-27", notes = {
    { "new", L["PN_100_01"] },
  } },
}
