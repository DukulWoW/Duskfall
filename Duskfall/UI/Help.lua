-- Duskfall UI/Help.lua: how Duskfall works, in short topics (Kim, 2026-11-26). Opened by the help
-- button between Advanced and the close button; it lies over the tabs until closed (the button
-- again, Close, or ESC). Topics on the left, the text on the right.
-- Public: ns.Help.Toggle(), ns.Help.Open(key), ns.Help.Shown(), ns.Help.Hide()
local ADDON, ns = ...
local UI, W = ns.UI, ns.Window
local H = {}
ns.Help = H

local Y = "|cffffd100"
-- Links (Kim, 2026-11-27, as BNB's help): Duskfall blue text that opens what it names (gold stays for
-- names that only stand out, Kim). Targets:
-- settings:<page>, tab:<id>, calibrate, notes (the OnHyperlinkClick in build)
local function L(target, text) return "|cff5c80ff|Hdusk:" .. target .. "|h" .. text .. "|h|r" end
-- Pictures in the text (Kim): our own art, inline
local ART = "Interface\\AddOns\\Duskfall\\Assets\\"
local function PIC(file, size) return "|T" .. ART .. file .. ":" .. (size or 16) .. "|t" end
-- Topic keys for ns.Help.Open (the "?" icons next to features)
local KEYS = { start = 1, wins = 2, time = 3, feel = 4, own = 5, modes = 6, sharing = 7, starter = 8, others = 9,
               compare = 10, hdr = 11, sounds = 12, commands = 13 }

local TOPICS = {
  { "Getting started", {
    "Duskfall changes the game's Gamma, Brightness, Contrast and Bloom for where you are.",
    "Nothing changes until you set something. Open " .. L("tab:places", "Places") .. ", move a slider, and the place you "
      .. "stand in has its own look from then on. Everywhere else stays as you had it.",
    "The window opens on where you are. " .. Y .. "Your places|r on the right lists everything you have set; "
      .. "click one to adjust it.",
    "Want to see the whole screen while you adjust? " .. Y .. "Mini panel|r swaps the window for a small "
      .. "panel with only the sliders.",
  } },
  { "What wins where", {
    "A setting is for a part of a zone, a whole zone, a dungeon, all dungeons, or everywhere.",
    "The most specific one wins: a part of a zone beats the zone, the zone beats Everywhere. A time of "
      .. "day or indoors / outdoors makes a setting more specific too, so " .. Y .. "Undercity at night|r "
      .. "beats " .. Y .. "Undercity|r.",
    "Each value is decided on its own. If Undercity at night only changes Gamma, its Brightness comes "
      .. "from Undercity, and from your own settings when nothing sets it.",
  } },
  { "Time of day", {
    PIC("Day\\ui-dawn") .. " Dawn, " .. PIC("Day\\ui-day") .. " Day, " .. PIC("Day\\ui-dusk") .. " Dusk and "
      .. PIC("Day\\ui-night") .. " Night follow the server clock by default, the one the sky uses.",
    L("settings:time", "Settings > Time of day") .. " shows the day as a bar: drag the edges to change when each part "
      .. "starts, or pick your computer's clock instead.",
    "When a part of the day begins, the change fades in slowly, so you hardly notice it.",
  } },
  { "How changes feel", {
    L("tab:styles", "Styles") .. " sets how the screen moves from one look to the next:",
    Y .. "Instant|r: at once.   " .. Y .. "Smooth|r: a soft fade.   " .. Y .. "Like your eyes|r: slowly into "
      .. "the dark with a short dip, quickly out into the light with a short glare.",
    Y .. "Speed|r makes it all quicker or slower, and " .. Y .. "Try it|r shows it on your screen.",
  } },
  { "Your own settings", {
    "Duskfall works from your own game settings, called the baseline, and every value in Places is a "
      .. "change from it. The sliders show what you get, with the change in brackets.",
    "Logging out or switching Duskfall off puts your own settings back.",
    "Moved one of the game's own sliders yourself? Duskfall keeps your change while you stay where you are. "
      .. L("settings:baseline", "Settings > Baseline") .. " saves the values on screen as your new baseline.",
  } },
  { "Simple and Advanced", {
    "Duskfall starts simple. Pick " .. Y .. "Advanced|r at the top (Simple | Advanced) for everything else:",
    "every place you have visited, one setting for several places, combat, mounted, swimming, "
      .. "underwater, resting and ghost, your own hours, fixed values instead of changes, settings for "
      .. "only some characters, and several Styles with who uses which.",
    "Both modes show the same settings. Anything made in Advanced mode is listed in simple mode with an "
      .. Y .. "Advanced|r tag, and clicking it opens it there.",
  } },
  { "Sharing", {
    "Right-click a place in " .. Y .. "Your places|r > " .. Y .. "Export|r copies it as a line of text. "
      .. Y .. "Share this Style|r on Styles copies every setting at once.",
    "Give the text to a friend; they paste it with " .. Y .. "Import|r. A setting replaces the same one "
      .. "they have, a Style comes in as a new Style.",
    "Copy and Paste values in the right-click menu copy the numbers from one place to another.",
  } },
  { "A head start", {
    "Not sure where to begin? " .. L("tab:styles", "Starter Style") .. " on the Styles tab adds the Style " .. Y .. "Dark Places|r, with a little more light in "
      .. "the darkest zones (Duskwood, Deadwind Pass, Felwood, Swamp of Sorrows) and at night everywhere. The welcome "
      .. "offers it too. Your own Style stays as it is, and you can change the starter like any other.",
    "Coming from another lighting addon? While it is still on, Duskfall offers to bring its settings along as a new "
      .. "Style, as changes from your own settings. Places Duskfall can't find are named in chat.",
  } },
  { "Other addons", {
    "Duskfall works by changing four of the game's own settings: Gamma, Brightness, Contrast and Bloom. Another "
      .. "lighting addon that changes the same settings fights over them with Duskfall, and the screen flickers or "
      .. "jumps. Use one of them.",
    "When Duskfall finds such an addon it says so once, and can turn it off for you (the interface reloads), or you "
      .. "keep both. If something else keeps changing these settings, it tells you that too.",
    "Before you turn the other addon off, Duskfall can bring its settings along as a new Style: in that message, or "
      .. "on the " .. L("tab:styles", "Styles") .. " tab while the other addon is still on.",
    "Addons that only draw over the screen (filters, tints, vignettes) and leave these settings alone work fine "
      .. "next to Duskfall.",
  } },
  { "Compare and brighten", {
    "Hold " .. PIC("Buttons\\compare") .. " " .. Y .. "Compare|r (the half light, half blue button on Places, or on the mini panel) to see your own "
      .. "settings; let go to see Duskfall's again.",
    Y .. "Hold to brighten|r is a key binding (Options > Keybindings > AddOns > Duskfall): while you hold it the "
      .. "screen is brighter, to peer into a dark corner. How much is on " .. L("settings:general", "Settings > General") .. ".",
    "Screen looks stuck? " .. Y .. "Refresh|r on Settings (or " .. Y .. "/dusk refresh|r) puts the settings for here "
      .. "back at once.",
  } },
  { "HDR and calibrating", {
    L("calibrate", "Calibrate") .. " on " .. L("settings:baseline", "Settings > Baseline") .. " shows grey squares to set your own look by. Black level: "
      .. "raise Brightness until square 2 is just visible while square 1 stays black. White level: set Contrast so "
      .. "square 9 still differs from square 10. Grey steps: set Gamma so every step looks about as far from the next. "
      .. Y .. "Save as baseline|r keeps it, Cancel puts the old values back.",
    "Do it in a room lit as when you play; the squares change with the game's settings like everything else.",
    "With an HDR screen, the " .. L("tab:hdr", "HDR") .. " tab turns HDR on (Windows HDR must be on) and sets peak brightness, "
      .. "paper white and strength. Set peak brightness to your screen's own, then paper white until white text and "
      .. "the sky look right. These apply everywhere in the game; the game's own options have none of them.",
  } },
  { "Sounds and notes", {
    "A short sound plays the first time you walk into a place, and, if you like, when walking in starts one of your "
      .. "settings. Turn each on or off and pick the sounds (other addons' too) on " .. L("settings:general", "Settings > General") .. ".",
    "The status display by the minimap shows what changed. Left-click it for the settings for where you are, "
      .. "right-click to close it.",
    "After an update a short note points to the " .. L("notes", "Patch Notes") .. ": what is new in each version. They are "
      .. "also on About and next to Close here.",
  } },
  { "Commands", {
    Y .. "/dusk|r (or " .. Y .. "/duskfall|r, " .. Y .. "/df|r) opens this window, " .. Y .. "/dusk settings|r "
      .. "the settings, " .. Y .. "/dusk help|r this help, " .. Y .. "/dusk notes|r the patch notes, "
      .. Y .. "/dusk status|r what Duskfall is doing, in chat.",
    Y .. "/dusk on|r, " .. Y .. "/dusk off|r: Duskfall on or off; there is a key binding for it too "
      .. "(Options > Keybindings > AddOns), one to hold for a quick look at your own settings "
      .. "(as the Compare button), and one to hold for a brighter screen. " .. Y .. "/dusk baseline|r: the current values become your baseline. " .. Y .. "/dusk refresh|r (or the Refresh "
      .. "button on Settings) puts the settings for here back at once if the screen ever seems stuck.",
    Y .. "/dusk save sub|r, " .. Y .. "zone|r or " .. Y .. "instance|r, then any of " .. Y .. "dawn day dusk night "
      .. "21:00-05:30 indoors outdoors resting combat mounted swimming underwater ghost|r (! in front = not): "
      .. "saves the current values there. " .. Y .. "/dusk clear|r the same way removes it. " .. Y .. "/dusk looks|r "
      .. "lists them.",
    Y .. "/dusk mode instant|r, " .. Y .. "fade|r or " .. Y .. "adapt|r, " .. Y .. "/dusk fade <s>|r, " .. Y
      .. "/dusk adapt dark|r or " .. Y .. "light <s> [0-1]|r, " .. Y .. "/dusk timefade <s>|r, " .. Y
      .. "/dusk transition|r: how changes feel.",
    Y .. "/dusk style|r lists Styles (" .. Y .. "use <n>|r, " .. Y .. "new <name>|r). " .. Y .. "/dusk chars|r "
      .. "lists characters (" .. Y .. "remove <name>|r). " .. Y .. "/dusk welcome|r shows the welcome again.",
    "The minimap's day and night moon opens Duskfall: left-click the window, right-click on / off, "
      .. "shift-right-click Settings.",
  } },
}

local frame, buttons, body, heading = nil, {}, nil, nil
local current = 1

local function show(i)
  current = i
  heading:SetText(TOPICS[i][1])
  body:SetText(table.concat(TOPICS[i][2], "\n\n"))
  for n, b in ipairs(buttons) do
    b.pick:SetShown(n == i)
    -- Dark on the gold, without the drop shadow (it smeared the letters, Kim)
    if n == i then
      b.text:SetTextColor(0.14, 0.08, 0)
      b.text:SetShadowOffset(0, 0)
    else
      b.text:SetTextColor(1, 0.82, 0)
      b.text:SetShadowOffset(1, -1)
    end
  end
end

local function build()
  -- An overlay over the pages (W.NewOverlay: wood, title, Close, fades, hides the page and strip)
  local f = W.NewOverlay("How Duskfall works")
  -- Patch Notes next to Close (Kim)
  local notes = UI.Button(f, "Patch Notes", 120, function() if ns.PatchNotes then ns.PatchNotes.Open() end end)
  notes:SetPoint("RIGHT", f.closeBtn, "LEFT", -8, 0)

  -- Topics
  local list = CreateFrame("Frame", nil, f)
  list:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -56)
  list:SetSize(200, #TOPICS * 34 + 12)
  UI.RoundBox(list, { radius = 10, bottom = { 0, 0, 0, 0.45 }, top = { 0.14, 0.11, 0.07, 0.4 },
    border = { 1, 0.82, 0, 0.25 } })
  for i, t in ipairs(TOPICS) do
    local b = CreateFrame("Button", nil, list)
    b:SetSize(184, 30)
    b:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -6 - (i - 1) * 34)
    local inner = CreateFrame("Frame", nil, b)
    inner:SetAllPoints()
    b.pick = UI.RoundBox(inner, { radius = 8, bottom = { 0.5, 0.33, 0.05, 0.95 }, top = { 0.93, 0.72, 0.24, 0.95 } })
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)
    local top = CreateFrame("Frame", nil, b)
    top:SetAllPoints()
    top:SetFrameLevel(inner:GetFrameLevel() + 2)
    b.text = UI.Label(top, t[1], "GameFontNormal")
    b.text:SetPoint("LEFT", b, "LEFT", 12, 0)
    b:SetScript("OnClick", function() show(i) end)
    buttons[i] = b
  end

  -- Text
  local page = CreateFrame("Frame", nil, f)
  page:SetPoint("TOPLEFT", list, "TOPRIGHT", 20, 0)
  page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 20)
  UI.RoundBox(page, { radius = 12, bottom = { 0, 0, 0, 0.4 }, top = { 0.16, 0.12, 0.08, 0.35 },
    border = { 1, 0.82, 0, 0.2 } })
  heading = UI.Label(page, "", "GameFontNormalLarge")
  heading:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -18)
  -- Blue links open what they name (L above)
  if page.SetHyperlinksEnabled then page:SetHyperlinksEnabled(true) end
  page:SetScript("OnHyperlinkClick", function(_, link)
    local target = type(link) == "string" and link:match("^dusk:(.+)$")
    if not target then return end
    local setting = target:match("^settings:(.+)$")
    local tab = target:match("^tab:(.+)$")
    if setting then
      if ns.OpenSettingsPage then ns.OpenSettingsPage(setting) end
    elseif tab then
      W.CloseOverlays(true)
      ns.OpenWindow(tab, true)
    elseif target == "calibrate" then
      if ns.OpenSettingsPage then ns.OpenSettingsPage("baseline") end
      if ns.Calibrate then ns.Calibrate.Open() end
    elseif target == "notes" then
      W.CloseOverlays(true)
      if ns.PatchNotes then ns.PatchNotes.Open() end
    end
  end)
  page:SetScript("OnHyperlinkEnter", function(self, _, text)
    local name = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:AddLine("Open " .. name, 1, 1, 1)
    GameTooltip:Show()
  end)
  page:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
  body = UI.Label(page, "", "GameFontHighlight")
  body:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -14)
  body:SetPoint("RIGHT", page, "RIGHT", -20, 0)
  body:SetJustifyV("TOP")
  body:SetSpacing(4)
  body:SetTextColor(0.9, 0.88, 0.84)

  frame = f
  show(current)
end

function H.Shown() return frame ~= nil and frame:IsOpen() end
function H.Open(key)
  if not W.frame then return end
  if not frame then build() end
  frame:Show()
  show(KEYS[key] or current)
end
function H.Hide() if frame then frame:FadeHide() end end
function H.Toggle()
  if not W.frame then return end
  if not frame then build() end
  if frame:IsOpen() then frame:FadeHide() else frame:Show() end
end
