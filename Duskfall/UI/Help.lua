-- Duskfall UI/Help.lua: how Duskfall works, in short topics (Kim, 2026-11-26). Opened by the help
-- button between Advanced and the close button; it lies over the tabs until closed (the button
-- again, Close, or ESC). Topics on the left, the text on the right.
-- Public: ns.Help.Toggle(), ns.Help.Open(key), ns.Help.Shown(), ns.Help.Hide()
local ADDON, ns = ...
local UI, W = ns.UI, ns.Window
local H = {}
ns.Help = H

local Y = "|cffffd100"
-- Topic keys for ns.Help.Open (the "?" icons next to features)
local KEYS = { start = 1, wins = 2, time = 3, feel = 4, own = 5, modes = 6, sharing = 7, commands = 8 }

local TOPICS = {
  { "Getting started", {
    "Duskfall changes the game's Gamma, Brightness, Contrast and Bloom for where you are.",
    "Nothing changes until you set something. Open " .. Y .. "Places|r, move a slider, and the place you "
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
    "Dawn, Day, Dusk and Night follow the server clock by default, the one the sky uses.",
    Y .. "Settings > Time of day|r shows the day as a bar: drag the edges to change when each part "
      .. "starts, or pick your computer's clock instead.",
    "When a part of the day begins, the change fades in slowly, so you hardly notice it.",
  } },
  { "How changes feel", {
    Y .. "Styles|r sets how the screen moves from one look to the next:",
    Y .. "Instant|r: at once.   " .. Y .. "Smooth|r: a soft fade.   " .. Y .. "Like your eyes|r: slowly into "
      .. "the dark with a short dip, quickly out into the light with a short glare.",
    Y .. "Speed|r makes it all quicker or slower, and " .. Y .. "Try it|r shows it on your screen.",
  } },
  { "Your own settings", {
    "Duskfall works from your own game settings, called the baseline, and every value in Places is a "
      .. "change from it. The sliders show what you get, with the change in brackets.",
    "Logging out or switching Duskfall off puts your own settings back.",
    "Moved one of the game's own sliders yourself? Duskfall keeps your change while you stay where you are. "
      .. Y .. "Settings > Baseline|r saves the values on screen as your new baseline.",
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
  { "Commands", {
    Y .. "/dusk|r (or " .. Y .. "/duskfall|r, " .. Y .. "/df|r) opens this window, " .. Y .. "/dusk settings|r "
      .. "the settings, " .. Y .. "/dusk help|r this help, " .. Y .. "/dusk status|r what Duskfall is doing, in chat.",
    Y .. "/dusk on|r, " .. Y .. "/dusk off|r: Duskfall on or off; there is a key binding for it too "
      .. "(Options > Keybindings > AddOns), and one to hold for a quick look at your own settings "
      .. "(as the Compare button). " .. Y .. "/dusk baseline|r: the current values become your baseline. " .. Y .. "/dusk refresh|r (or the Refresh "
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
  local win = W.frame
  local f = CreateFrame("Frame", nil, win)
  f:SetPoint("TOPLEFT", win, "TOPLEFT", 6, -26)
  f:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -6, 30)
  f:SetFrameLevel(win:GetFrameLevel() + 40)
  f:EnableMouse(true)
  local bg = f:CreateTexture(nil, "BACKGROUND", nil, 0)
  bg:SetAllPoints()
  bg:SetTexture(UI.ART .. "Backgrounds\\wood", "REPEAT", "REPEAT")
  bg:SetHorizTile(true)
  bg:SetVertTile(true)
  UI.Glow(f, nil, 0.8)

  local title = UI.Label(f, "How Duskfall works", "GameFontNormalHuge")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -16)
  local close = UI.Button(f, "Close", 90, function() f:FadeHide() end)
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -16)

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
  page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 16)
  UI.RoundBox(page, { radius = 12, bottom = { 0, 0, 0, 0.4 }, top = { 0.16, 0.12, 0.08, 0.35 },
    border = { 1, 0.82, 0, 0.2 } })
  heading = UI.Label(page, "", "GameFontNormalLarge")
  heading:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -18)
  body = UI.Label(page, "", "GameFontHighlight")
  body:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -14)
  body:SetPoint("RIGHT", page, "RIGHT", -20, 0)
  body:SetJustifyV("TOP")
  body:SetSpacing(4)
  body:SetTextColor(0.9, 0.88, 0.84)

  -- Closing the window or picking a tab closes help too
  win:HookScript("OnHide", function() f:Hide() end)
  UI.Fader(f)   -- ESC: the window's OnKeyDown closes it (Help first, then the page)
  -- The window's status strip (Style / Here / values) does not belong under the help (Kim)
  f:HookScript("OnShow", function() if win.strip then win.strip:Hide() end end)
  f:HookScript("OnHide", function() if win.strip then win.strip:Show() end end)
  f:Hide()
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
