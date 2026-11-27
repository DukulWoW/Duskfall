-- Duskfall Core/PatchNotes.lua: the patch notes shown in the window (About > Patch Notes, Help >
-- Patch Notes, the toast after an update). Newest first. kind = "new", "change" or "fix".
-- Only what players need to know, and only against the release before (Kim, 2026-11-27).
-- date = nil while a version is not released yet; set it when tagging.
local ADDON, ns = ...

ns.PATCH_NOTES = {
  { version = "1.1.0", date = nil, notes = {
    { "new", "Patch notes: this page. Find it on About and in Help; after an update a short note by the minimap points to it." },
    { "new", "Compare: hold the Compare button (Places, mini panel) or its key binding to see your own settings; let go to see Duskfall's again." },
    { "new", "Sounds: a short sound the first time you walk into a place (on), and one when walking in starts one of your settings (off). Pick each sound, other addons' sounds too, on Settings > General." },
    { "new", "Duskfall warns once when another addon (such as Iris) also changes Gamma, Brightness and Contrast, and can turn it off for you." },
    { "new", "Refresh, left of the big switch on Settings (and /dusk refresh), puts the settings for here back at once if the screen ever seems stuck." },
    { "change", "Windows fade in and out gently, and the status display fades out smoothly." },
    { "change", "The line under each slider is softer: blue when you turn a value down, gold when you turn it up." },
    { "change", "Sharper close and help buttons in the title bar. Right-click the close button to move the window back to the middle of the screen." },
    { "change", "The About tab is tidier, with Commands, Help and Patch Notes buttons." },
    { "change", "The status display: left-click opens the settings for where you are, right-click closes it." },
    { "change", "Report a bug (About, welcome) opens a form for bugs and ideas." },
  } },
  { version = "1.0.0", date = "27 Nov 2026", notes = {
    { "new", "The first release." },
  } },
}
