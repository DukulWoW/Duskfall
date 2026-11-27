-- Duskfall Core/PatchNotes.lua: the patch notes shown in the window (About > Patch Notes, Help >
-- Patch Notes, the toast after an update). Newest first. kind = "new", "change" or "fix".
-- Only what players need to know, and only against the release before (Kim, 2026-11-27).
-- date = nil while a version is not released yet; set it when tagging.
local ADDON, ns = ...

ns.PATCH_NOTES = {
  { version = "1.1.0", date = nil, notes = {
    { "new", "Patch notes: this page. Find it on About and in Help; after an update a short note by the minimap points to it." },
    { "new", "Compare: hold the Compare button (Places, mini panel) or its key binding to see your own settings; let go to see Duskfall's again." },
    { "new", "HDR tab: turn HDR on and set peak brightness, paper white and strength, for HDR screens. The game's own options have none of these." },
    { "new", "Calibrate (Settings > Baseline): grey squares to set your own Gamma, Brightness and Contrast by." },
    { "new", "Hold to brighten: a key binding that makes the screen brighter while you hold it, to peer into a dark corner." },
    { "new", "Sounds: a short sound the first time you walk into a place (on), and one when walking in starts one of your settings (off). Pick each sound, other addons' sounds too, on Settings > General." },
    { "new", "Duskfall warns once when another addon also changes Gamma, Brightness and Contrast, and can turn it off for you." },
    { "new", "Import from another lighting addon: bring its settings into a new Style before you turn it off (in that warning, or on the Styles tab while it is on)." },
    { "new", "Starter Style: a little more light in the darkest zones and at night, as a Style of its own. On the Styles tab, and as a choice in the welcome." },
    { "new", "Refresh, left of the big switch on Settings (and /dusk refresh), puts the settings for here back at once if the screen ever seems stuck." },
    { "new", "Simple mode: a setting can be for underwater only (Inside: In and out, Indoors, Outdoors, Underwater)." },
    { "change", "The status display shows a thin bar while a change runs, and can stay for exactly as long as the change (Settings > Display)." },
    { "change", "The cursor light costs less: it only draws while the mouse is over a Duskfall window, and switches itself off while the game runs below 60 frames a second." },
    { "change", "Help: gold names open the page they name, with pictures, and new topics (other addons, HDR and calibrating, and more)." },
    { "change", "Styles: delete a Style straight from the list with the X on its line." },
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
