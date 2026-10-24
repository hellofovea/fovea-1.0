# Fovea Captures: the design

This document explains the design of Fovea's main window, as built in the `FoveaCaptures` prototype. It's written for people joining the work and for their coding agents. It covers what a capture is, what goes into each one, what every screen shows and why, and how the prototype is put together.

Read it with the app open:

```bash
cd Prototypes
swift run FoveaCaptures
```

Screenshots of every state are in `Prototypes/shots/captures/`. They're rendered from the same code with `swift run FoveaCaptures --snapshot <dir>`.

> **Settings is the least settled part of this design.** Section 9 says why and asks for your view. If a tab isn't useful, or something belongs in Settings that isn't there, say so.

> **The dev team's App UI review (Oct 6)** and every decision on it, row by row, are in [`docs/window/FEEDBACK_2026-10-06.md`](../../docs/window/FEEDBACK_2026-10-06.md). Where it and this document disagree, the record wins. The **States** menu shows each error, alert and empty state the review asked for.

---

## 1. Fovea in one minute

Fovea lets you point at anything on your screen and send it, with what you say, to where it needs to go. You can dictate into the app in front, put screenshots and text into it, or hand it all to an AI coding agent. You never switch windows.

You press a hotkey, speak, take things off the screen if you want to, and press the hotkey again. Everything between those two presses is one **capture**.

The product has three surfaces:

| Surface | What it is | In this prototype? |
|---|---|---|
| Menu bar | One icon: idle, listening, needs attention. Quitting is only from here. | No |
| The Island | The black shape around the notch that shows listening, transcribing and agent tasks while you work. | No. It's built in `Prototypes/FoveaWorkbench`. |
| The window | The history of everything you said and took, plus Settings. | **Yes. This document is about it.** |

The window is an **input tool's history**, not a workspace. It has no projects view and no agent output. You open it to find something you said, to see what you sent where, or to change a setting, and then you leave.

---

## 2. What a capture is

A capture is one session: from pressing the hotkey to pressing it again. It's the atomic unit of Fovea.

- **It never changes after the fact.** If you correct something, that's a new capture, not an edit, so the history stays honest.
- **You can delete one.** Deleting shows a toast with Undo for five seconds.
- **Every screen should be explainable in terms of captures.** If a screen can't be, it probably shouldn't exist.

### What goes into a capture

| Field | What it holds | Example |
|---|---|---|
| Type | Dictation, Capture or Dispatch (section 3). | Dispatch |
| Time | When you pressed the hotkey. | Today, 2:38 PM |
| App | The app in front when you pressed it. | Safari |
| Words | Your words as Fovea put them: the transcription it typed, or the request it sent. | "Make the ears on this one match the menu bar's height exactly…" |
| What you took | Zero or more things you took off the screen while speaking, in order (section 2.1). | A region of `IslandShape.swift`, a region of the Notch Workbench |
| Where it went | For a dispatch only: the agent (Claude Code or Codex) and the chat it went into. | Claude Code, "notch ears" |
| Theme | Three or four words Fovea writes about what it's about. Shown as the card's title. | "Notch ears height" |
| Length | Seconds of speech. Kept, not shown. | 31 s |

**A dictation keeps only its transcription.** Fovea doesn't keep or show what you said word for word (the raw speech before clean-up). The transcription is enough.

### 2.1 What you took

While you speak, you can take things off the screen. Each one is an **attachment**. The project's `AGENTS.md` calls these *referents*; this prototype's code says `Attachment`.

| Kind | How you take it | What's kept | How it's drawn |
|---|---|---|---|
| Region | Hold Left ⌥ and drag over part of the screen. | A screenshot of it, the text read off it, the app and window it came from. | The picture. |
| Passage | Hold Left ⌥ and click text. | The text, and where it came from. | A quote with its source. |
| File | Hold Left ⌥ and click a file. | Its name, type and folder. | Its icon, name and folder. |
| Whole screen | Press Left ⌥ twice. | A screenshot of everything on screen. | The picture. |

Every attachment has:

- **A number** (1, 2, 3…) in the order you took them. The number is drawn on a small blue tab wherever the thing appears, so "1" in your words and "1" on a picture are the same thing.
- **An anchor**: the place in your words where you took it. The card and the expanded card cut the words there and put a chip in.
- **The words that pointed at it.** These are words like "this one", "the second one" or "这一屏". They're highlighted with a light accent wash and end in the number's tab. Connecting these words to the right attachment is Fovea's hard problem, called *binding* in `AGENTS.md`.

The text read off a region is searchable, so you can find a capture by something that was only in a screenshot.

---

## 3. The three types of capture

| | Dictation | Capture | Dispatch |
|---|---|---|---|
| **Hotkey** | `fn` | `fn`, then Left ⌥ to take things | `fn` `⌃` |
| **What you do** | Speak. | Speak, and take regions, text or files off the screen. | Speak, and take things if you want. |
| **What Fovea does** | Types the transcription into the app in front. | Puts your words, with the things you took, into the app in front. | Sends your words and the things you took to an AI agent: Claude Code or Codex. Questions are dispatches too (the old "Quick Answer"). |
| **What's kept** | The transcription. No attachments. | The words and the attachments. | The words, the attachments, and the agent and chat it went to. |
| **The mark on its card** | A ring, teal | A bracket ⌜⌟, blue | A small island, purple |
| **The icon on its card** | The app it typed into. | The app it went into. | The agent it went to (Claude Code's spark, Codex's mark). |

The mark's shape and color both say the type, and the type's name is always written next to it in ink. Color is never the only signal.

**Examples from the sample data:**
- *Dictation, in Mail:* "Hi Lin, thanks for the notes on the second screen…" Fovea typed this into a reply.
- *Capture, in Mail:* "Lin, I looked into the errors from yesterday's demo. **The docs**① say the API allows 100 write requests…" ① is a region of the Stripe docs' rate-limit table.
- *Dispatch, to Claude Code:* "Make the ears on **this one**① match the menu bar's height exactly, and use the spacing from **the second one**②…" ① is a region of `IslandShape.swift`; ② is a region of the Notch Workbench.

---

## 4. The window

![The window: calendar on top, the last three days' cards under it](../shots/captures/window-grid.png)

- **One size: 1112 × 784 pt.** It can't be resized or made full screen, the way Wispr Flow's and Typeless's windows can't. Four columns of cards fit.
- **Closing the window doesn't quit Fovea.** In the product, quitting is from the menu bar icon; in the prototype it's ⌘Q.
- **Two layers, as in Aside** (a macOS notes app we studied for its finish):
  - The window itself is the system's translucent material, so the desktop shows through its edges.
  - The content sits on an opaque **page** inset 8 pt from the window's edges. Its corners are rounded 10 pt, so they run parallel to the window's own 17 pt corners.
- The toolbar sits on the material above the page.

### 4.1 The toolbar

From left to right: the window's traffic lights, then:

| Control | What it is | What it does |
|---|---|---|
| Four squares | A glass circle with a grid icon. There's no label; you find out what it does by opening it. | A menu that filters the cards. **App:** All Apps, then every app with its own icon, most used first. It filters by where the words went: the app for a dictation or a capture, the agent for a dispatch. **Tag:** the most used tags, then More Tags. **Show:** Last 3 days (the default) or Today. The squares fill in while a filter is on, and a line above the cards says which ("Filtered by Slack · Today  ✕ Clear"). |
| Type tabs | All · Dictation · Dispatch, centered. A sliding pill in a glass track; every tab is the same width. | Shows one type. The cards change at once and the pill slides over (0.2 s, Oct 21). ⌘1–⌘3 do the same. |
| Search | A glass circle with a magnifier. ⌘F opens it. | It opens leftward into a field. It searches your words, the text in what you took (read off regions, passages, file names), the app, and where a dispatch went. Every word you type must match somewhere. Matches are highlighted in the system's find yellow. Esc, or leaving it empty, folds it back. |
| You | Your initial in a glass circle, ringed by an arc of the credits used this month. | Hover shows your plan and credits. A click opens Settings on Account; a second click comes back. |

![The four squares' menu: apps with their icons, then the period](../shots/captures/window-filter-menu.png)

---

## 5. The first page: the last three days, and the calendar

![Search: the last three days' matches as cards, older ones marked in the calendar](../shots/captures/window-calendar-search.png)

The first page has two parts, top to bottom.

**1. The calendar** (on top, GitHub's contribution-graph style):
- It shows one year at a time. A tab above it picks the year, one tab per year you've used Fovea (2026 · 2025 · 2024). Opening a day from anywhere turns the calendar to that day's year.
- **Shading:** each day is shaded by how much you said that day. No captures is empty; the busy days split into four levels at their quartiles.
- **No streaks or stats.** The calendar shows how busy each day was and nothing more (`AGENTS.md` forbids efficiency metrics).
- Days still to come are outlines. The year's total is at the right ("865 captures in 2026").
- **Hover:** one ring follows the pointer square to square with no delay, and the line under the calendar names the day ("12 on Tuesday, September 15"). **A click** opens that day's page.

**2. The last three days' cards** (today and the two days before), newest first, grouped by day (Ryan, Oct 7: a week of cards was too much; other days are on the calendar above):
- Days are labeled "TODAY 10", "YESTERDAY 5", "THURSDAY, SEP 24", with the day's count in mono.
- The four squares' menu narrows the cards to **Today**, or back to **Last 3 days** (the default).
- **Nothing older than three days is ever shown as cards.** Anything older is in the calendar. There's no "Any Time": all time is what the calendar is for.

**Searching or filtering by app works the same way.** The last three days' matches are the cards, and the calendar shades the days of all the others ("120 matches in 2026"). Clicking a shaded day opens it with only its matches. When nothing matched in those three days, the page says "No matches in the last 3 days. The calendar marks the days with older ones."

### 5.1 A day's page

![A day's page](../shots/captures/window-history-day.png)

Clicking a day opens its own page:
- The date, large ("Tuesday, September 22").
- What it held, by type ("3 dictations · 1 capture · 5 dispatches").
- That day's cards. Times read as the time of day ("10:42 AM"), since the page already names the day.
- **‹ ›** go to the day before or after that has captures. The back arrow (⌘[) returns to the first page.

---

## 6. The card

![Four cards: the theme, the type and time, the app it went to, the words with their chips, and what was taken across the foot](../shots/captures/card-anatomy.png)

Each capture is a square card, 220 pt (236 until Oct 13: four a row in the 1024-pt window), in the style of Paste's clipboard cards. From top to bottom:

1. **Header, two lines.**
   - The **theme** in bold (13 pt): "Notch ears height".
   - Under it, the type's **mark**, the **type** and when: "Dispatch · 52m".
   - At the right, the **icon** of where it went: the app, or the agent. Small and whole; macOS doesn't crop app icons.
   - Times in this month: "now", "3m", "2h", "1d", "1w".
2. **Your words**, with a **chip** at each place you took something. A chip is a tiny picture of what you took plus its number. The words that pointed at it are highlighted.
3. **What you took**, as a strip across the bottom of the card, edge to edge. Each thing is drawn as itself (the region, the passage's first lines, the file's icon and name) and numbered at its lower left.

**What the card leaves out:** there's no footer, no destination text and no duration. Where it went is the icon; how long you spoke isn't shown.

**Spacing ("less in each card", the settled choice):**

| | Value |
|---|---|
| Inset | 16 pt |
| Header's two lines | 2 pt apart |
| Header to words | 16 pt |
| Lines of words over a preview | 2 |
| Lines of words with nothing taken | at most 7 |
| Words to preview | at least 14 pt |
| Between cards | 20 pt |
| Day label to its cards / between days | 14 pt / 44 pt |

The space between cards is larger than the space inside one, so each card reads as one object. Research behind this: Paste's own cards are about 24 between and 14 inside; Apple's widgets use a 16 pt margin.

**How it behaves:**
- **Hover:** the card's wider shadow grows; nothing moves.
- **Press:** it settles to 98.5 %.
- **Keyboard:** ←→↑↓ move a selection ring (system accent, 2.5 pt, just outside the card). Space or Return opens the card. Esc clears the selection.
- **Click:** opens the expanded card.

---

## 7. The expanded card

![The expanded card for a dispatch](../shots/captures/window-detail-dispatch.png)

Opening a card grows it into a larger card over the dimmed page, like Quick Look.

**What it shows:**
- **Your words in full**, at 15 pt, about 75 characters a line, with their chips. For a dictation this is the transcription only.
- **Everything you took, large:**
  - regions at their own shape, side by side when there are two;
  - passages as quotes, with where they came from;
  - files with their icon, name and folder.
  - Each is numbered, with its source under it.
- **Not shown:** the type, the destination and the time. The card it grew from already shows those.

**Controls:**

| Control | Where | Key |
|---|---|---|
| Close | A glass circle, top left | Esc, or click the dimmed page |
| Previous / next capture | A glass capsule, top right | ← → |
| Copy text | Same capsule; shows a checkmark briefly | — |
| Delete | Same capsule; pink under the pointer; Undo in a toast | ⌘⌫ (Undo: ⌘Z) |

**Motion.** Opening: one value drives everything, from 0 at the card to 1 open (0.32 s):
- The surface grows from the card's own frame, corners and shadow growing with it.
- The card's own face fades out over the first 30 %.
- The expanded content fades in from 16 % to 70 %, out of a 4 pt blur.
- The pictures you took fly from the card's strip to their places.
- **Closing has no animation** (Ryan, Oct 7). It used to run the same path back, which took the whole window through grey; the X, Esc or a click outside now closes it at once.
- With Reduce Motion, opening is a short fade in place.

**The foot** (Oct 7): the tags, and nothing else. No card plays the recording or has an Open in Claude Code (Yulun, Oct 7); the recording is still kept and saved from the Save menu, and a failed one has Transcribe Again in its notice.

![The expanded card for a dictation: the transcription only](../shots/captures/window-detail-dictation.png)

---

## 8. Settings

Settings opens in the window (from your avatar, or ⌘,), in place of the captures. A back arrow (⌘[) returns.

![Settings, as System Settings](../shots/captures/window-native-account.png)

**Layout: System Settings' own (October).** Ryan asked for Settings to work and look like the Mac's System Settings:
- **One section at a time.** Clicking a section in the sidebar shows that section alone on the right; sections never run into each other.
- **A sidebar at the left**, on the window's material, grouped by space as System Settings groups its own. Each section has System Settings' tile: a rounded square of color, lit a little from the top, with a white filled symbol. The colors follow System Settings' (blue as Users & Groups, black as Appearance, red as Sound, gray as Keyboard, indigo as Focus), studied from the pane icons on macOS 27.
- **The section you're in is marked in your accent** (Ryan, Oct 6), white text on it, as System Settings marks its own in the Mac's; behind other windows it greys, as the Mac's does. The List's own highlight knows only the Mac's accent, and greys whenever the list loses focus (after a click in the page, say), so each row draws its own mark over it, a point wider so none of the Mac's color fringes it.
- **Each section opens with a header**: its tile large, its name, and one line on what it's for, centered in a box.
- **The Mac's grouped boxes** below it, measured from SwiftUI's grouped Form on macOS 27: a white page, boxes a step off it (97.5 % white; dark, 19 % on 16 %), 1 pt hairlines in 10 pt from both ends, bold 13 pt headers over the boxes, and the system's switches, pop-up menus, segmented controls and push buttons (`T.Native`). Fovea's own controls stay only where a picture says more: the keys, the plans, the pictures to choose between, the chips.
- The toolbar names the section you're in, beside Back.

**Sections:** Account · Plan · Appearance · Notch · Language · Voice & Capture · Memory · Shortcuts · Connectors · Eye Tracking.
- AGENTS.md's seven, with Dictionary renamed **Memory** (Ryan, Oct 6). It holds the **Dictionary** and the **Memories**, both as they were under Account; Account keeps the profile and On this Mac. (In the tabs layout they're still under Account.)
- **Appearance, Notch, Language and Memory go past AGENTS.md** ("Do not add a Settings category beyond the seven (no General, Privacy, Memory, …)", which names Memory as one not to add). Ryan asked for all four (Language with the App UI review, row 6). If they stay, AGENTS.md's list needs updating.
- **Memory, redesigned** (App UI review, row 24): the Dictionary, then **About you** (the areas of your life Fovea has come to know, each a summary read from your captures' tags), every memory behind **Search Memories…**, and what Fovea may remember. The summaries are an inferred profile, which AGENTS.md forbids; Ryan decided it, and the record flags it.

![Notch: the glow's color board under the live notch](../shots/captures/window-native-notch.png)

**Appearance** (`AppearanceSettings.swift`), laid out as System Settings' Appearance pane, and only this (Ryan, Oct 6: "only light/dark + accent color is enough"):
- **Appearance:** Light, Dark or Auto, as pictures of a window (Auto follows the Mac).
- **Accent color:** the Mac's own set, as dots: Multicolor (follows the Mac), Blue, Purple, Pink, Red, Orange, Yellow, Green, Graphite. Only these, no color well. A color goes through the whole window: what's chosen, the numbered tabs on what you took, the words you pointed with, the calendar's shades, the system's own controls, and the bar in the avatar's usage popover (a popover is a window of its own, so it's given the accent itself). The usage arc round the avatar stays ink, as the toolbar does.
- The themes (Paper, Blue Pencil, Macula, Notch) and the card sizes, offered here for a day, are gone again.

**Notch** (`NotchSettings.swift`): what the Notch Workbench tunes, made hard to get wrong.
- **Glow**, first: the Workbench's color board under a live notch.
  - **The preview is always live**, as the Workbench's notch is (Ryan, Oct 6: see the notch change instantly, nothing to play). It shows a MacBook's screen top at its own size, from Core's geometry: the 200×32 notch, and the voice bar 212×76 with 6 pt ears and 14 pt corners, black as the Island ships. The voice bar listens the whole time. The glow is drawn by the Workbench's own renderer from its demo voice (`NotchGlow.swift`, copied from `FoveaWorkbench/MockDesktop/VoiceGlow.swift`), so a drag shows on the notch the moment it's made. There is no Play button. Snapshots and Reduce Motion get the Workbench's still frame.
  - **The glow is flattened into one image before it reaches the screen** (`.drawingGroup()`). Drawn straight to the screen, most moving frames lost everything under the band line: a black stripe along the bar's foot (Ryan saw it, Oct 6). Still frames never showed it, and the same frames drawn offscreen were whole. `--only glow-live` writes 23 moving frames through what a person does on the pane: 14 of them had the stripe before, none after.
  - **Palette:** a template to start from (Colorful, Ocean, Sunset, Forest, Candy, Ice, Gold, Mono) or **Custom**.
  - **Hue,** on a spectrum. It turns a template round the wheel ("+120°") or sets Custom's centre ("200°"). Mono stays gray.
  - **Spread:** how far Custom's seven hues fan across the wheel, 0–360°. It shows only for Custom.
  - **Hue drift:** the slow ±24° wander over 12 s.
  - **Mono** shows neither Hue nor Hue drift; its Palette row says it's gray, with no hue to turn.
  - **The seven colors** it makes, as the Workbench's swatches.
- **The Island's look** (Black, Black with an edge, Glass), offered for a day, is gone again (Ryan, Oct 6): the Island is black, as it ships.
- **Opening the board:** open when the pointer reaches the notch; how long to wait (Quick, Normal, Relaxed, never milliseconds); show an answer as soon as it's back.
- **Sending to an agent:** review your words before sending (the notch feedback of Oct 6, §19). The line under it says what happens either way.
- **Hard to get wrong:**
  - Everything but the glow's colors is a named preset with a picture. The glow keeps the Workbench's board because people want their own colors; the templates are where to start.
  - **A control shows only where it can change something** (Ryan, Oct 6: one that can't move looks like the program is broken). Spread shows for Custom alone; Hue and Hue drift don't show for Mono; Wait before opening shows only while the pointer opens the board. Each comes and goes with a fade.
  - Turning the hover off says the board still opens with ⌃ by itself, with a button to Shortcuts.
  - Restore Defaults puts it all back, after asking.

**Shortcuts follow the notch feedback of Oct 6 (§3):** ⌥ takes a screenshot (press once and drag; twice for the whole screen), ⌘ picks text or a file, ⌃ by itself opens the board.

**The earlier layouts are on the Variants menu** (Variants › Settings): the sidebar leading one scrolling page, the tabs across the top with the titles beside the cards (below), and one page with no sidebar. The shots of each pane below are the tabs.

**Everything in Settings is simulated.** Nothing reaches the system, and nothing is saved between launches.

**The tabs, as they were.** The tabs ran across the top, in the same sliding pill as the type tabs: Account · Plan · Voice & Capture · Shortcuts · Connectors · Eye Tracking. Each section's title (15 pt) sat in a column at the left with the card at the right, a 1 pt rule between sections, the title pinned while its section scrolled (Apple's spec pages, Tailwind's Catalyst, Shopify Polaris).

### 8.1 Account

![Account](../shots/captures/window-settings-account.png)

| Section | What's in it |
|---|---|
| Profile | Your initial, name and email; **Sign Out** (asks first: "Your captures stay on this Mac. You'll sign in again to dispatch."). |
| Dictionary | Words Fovea writes your way. A small pill filters **All · Learned · Added** (with counts). Words are chips; a sparkle marks the ones Fovea learned when you corrected what it typed. Hover a chip for its ✕; removal is immediate. **+ Add word** turns into a field. |
| Memories | **Remember things when you ask** (on/off): say "remember that …" and Fovea keeps it in your words, nothing it guessed. **Show when Fovea remembers something** (on/off). Up to three memories, each with what you said and where ("From 「把这个改动推到主仓」 · Sep 14"); **Forget** on hover, Undo in place; **All 5 memories** shows the rest. |
| On this Mac | **Appearance**: Light, Dark or System (also View › Appearance). **Open at login**, **Show in Dock** (off keeps Fovea in the menu bar and the notch), **Version 0.5 beta 7 · Up to date** with Check now, **Get beta updates**. |

### 8.2 Plan

![Plan](../shots/captures/window-plan.png)

| Section | What's in it |
|---|---|
| This month | A System Settings row: credits left, and what's used of the total with when they reset ("1,840 credits left · 3,160 of 5,000 used · resets Sep 30"), at the left; the Mac's own capacity indicator (`NSLevelIndicator`, continuous capacity, 180 pt) at the right, green, yellow past 70 %, red past 90 % (Oct 7: Apple shows a value in a range as a level indicator, not a progress bar). Under them, "Dictation is free. Taking things off the screen and dispatching use credits." |
| Plans | **Monthly · Yearly**, then three plans side by side: **Free** ("For speaking instead of typing.", $0, 300 credits a month, history for 30 days), **Pro** ("For pointing at things and sending them on.", $12 a month or $120 a year, 5,000 credits, history kept for good) and **Max** ("For handing work to agents all day.", $30 a month or $300 a year, 20,000 credits, history kept for good, eye tracking first). Your plan is ringed and marked **Current**. Moving up asks, then takes effect at once. Moving down asks, then waits until the credits reset; until then you can keep your plan. |
| Billing | When it renews, and for how much; or, after a move down, when your plan ends, with **Keep Pro**. |

**The prices, limits and plan names are placeholders** to confirm with whoever owns pricing.

### 8.3 Voice & Capture

![Voice & Capture](../shots/captures/window-settings-voice.png)

| Section | What's in it |
|---|---|
| Voice | **Microphone**: a live level meter and the device picker. **Speech language**: Automatic, English or 中文 ("Fovea detects the language as you speak."). **Play sounds when listening starts and stops.** |
| Screen awareness (Oct 7) | What dictation reads from your screen, item by item, as a question's (Connectors): "What Fovea reads from your screen while you dictate. Never the whole screen, unless you take it." **What you pick** (selected text, the regions and files you take): Always. **The window you're speaking into** (its app, title, web address or file): a switch, on. **The text in that window** ("A picture of the window, read on this Mac. Only its text goes with your words, to spell names and terms right."): a switch, on, shown while the window is allowed. Permissions' Screen Recording row says what it's for to match. |
| Capture | **Read the text in what you take** ("So you can search the words in a region you took."). **Never capture in**: apps as chips (1Password, Keychain Access) and **Add App…**. "Fovea takes nothing from these apps, and doesn't listen while they're in front." |
| History | **Keep captures**: 24 hours, 1 week, 1 month, Forever. **Keep screenshots**: 30, 90 or 180 days, Forever ("When a screenshot goes, your words and the text read off it stay."). |
| Permissions | Microphone, Speech Recognition, Screen Recording, each with its status. |
| Clear history | A danger card with the real count ("Deletes all … captures and their screenshots from this Mac. This can't be undone.") and **Clear History…**, which asks first. |

There's no choice of Island style: Fovea is always the Dynamic Island.

### 8.4 Shortcuts

![Shortcuts](../shots/captures/window-settings-shortcuts.png)

| Section | What's in it |
|---|---|
| (top) | "Press once to start, again to stop." Two large keys: **Voice Flow** `fn` ("Speak, and Fovea types it into the app in front of you.") and **Dispatch** `fn` `⌃` ("Send what you say to Claude Code or Codex."). |
| While you speak | **Take from the screen**: Left ⌥ ("Drag over a region, or click text or a file, to attach it."). **Take the whole screen**: Left ⌥ twice. |
| The Island | **Expand the Island**: ⌃ by itself ("…to open it when it has something to show."). **Restore Defaults.** |
| Permissions | **Accessibility** (Allowed) and **Input Monitoring** (Not allowed, with **Open Privacy Settings…**). "Fovea needs these to hear fn, Control and Option from any app." |

Each shortcut is a pill that records new keys: click it and type. Under the pointer it shows a ⓧ to clear.

### 8.5 Connectors

![Connectors](../shots/captures/window-settings-connectors.png)

| Section | What's in it |
|---|---|
| Agents | **Claude Code** (Ready · 2.1), **Codex** (Ready · 0.47), **Cursor** (Not installed, **Get Cursor ↗**). "Dispatches go to these, through the copy already signed in on this Mac." "Checked just now ↻" checks again. |
| Questions | **Answer with**: Fovea, Claude Code or Codex ("Who answers a question you dispatch."). |
| Screen context | Three picture tiles: **Minimal** ("Only what you took."), **Balanced** ("The window you're in.", chosen) and **Full** ("Everything on screen."). "More helps the answer, and shares more." |
| What agents can read | Claude Code: Can read. Codex: **Add…**. "Agents read only what you asked Fovea to remember." **Access Log.** |

### 8.6 Eye Tracking (coming)

![Eye Tracking](../shots/captures/window-settings-eyeTracking.png)

This tab is for a feature that doesn't exist yet. It shows what's coming and asks for help collecting data:
- **Coming soon.** An animated picture: a gaze moves between windows on a small screen, and "this" appears where it rests. "Soon you'll look at something and say 'this,' and Fovea will know what you mean."
- **Help build it.** Three steps (download the Gaze Collector, follow the dots for about ten minutes, review then send). **Download Gaze Collector** (38 MB) shows its progress, then becomes **Open Gaze Collector**.
- **What the Collector records:** video of your eyes, only while you follow the dots; where each dot was; nothing leaves without you; yours to delete.

---

## 9. Settings is open for review

The tabs and rows above are a best current guess, not a decision. Some may not earn their place, and some settings people need may be missing. **If you think a tab isn't useful, or that something should be in Settings and isn't, please say so**, with the tab or row, what's wrong, and what you'd do instead.

Questions we already have:

- **Account holds Dictionary and Memories.** `AGENTS.md` lists Dictionary as a category of its own. Should it be its own tab?
- **Memories:** `AGENTS.md` says "no stored learned facts or inferred user profiles, and no UI for curating them." These memories are only things you explicitly asked Fovea to remember, in your words. Does that hold up, or should the section go?
- **Plan** is its own tab (`AGENTS.md`'s "Usage & Plan"). Is a whole tab right for it, or should it be smaller?
- **Eye Tracking** is a tab for a feature that isn't built. Should it wait, or live somewhere smaller until it ships?
- **On this Mac** sits in Account because `AGENTS.md` forbids a "General" category. Is Account the right home for it?
- **Possibly missing:** appearance (the window follows the system's light or dark), how much the Island shows, data export, where captures are stored, what goes to which server. Note that `AGENTS.md` forbids General, Privacy, Memory, Security, Notifications and Access categories, so a missing setting has to fit one of the existing tabs, or the case for a new tab has to be made.
- **Rows that may need better words:** Screen context, What agents can read, Never capture in, Keep screenshots. Are they clear to someone new?

---

## 10. Visual language

### 10.1 Color

- **macOS's own colors.**
  - Labels: the system's label ladder (ink at 85 %, 50 % and 26 % in light).
  - Lines and fills: the system's separators and fills.
  - Accent: the user's chosen accent color.
- **The page and cards:** the page is the system's under-page gray (#F6F6F6) with white cards. In dark mode the page is #1E1E1E with #282828 cards.
- **Where color appears:**
  - the accent, for selection, focus and the words you pointed with;
  - the system's find yellow, for search hits;
  - the three type colors (teal, blue, purple), only in the type marks.
- Everything else is ink at an opacity.

### 10.2 Shading (from Aside)

- **Surfaces:** a surface is told from what it sits on by a 0.5 pt edge just inside it (ink at 8 %) and two soft shadows: a tight one where it touches, and a wide one around it. Never a gray box.
- **Hover and dark mode:** the wide shadow grows under the pointer. In dark mode, a faint line of light runs along each surface's top edge.
- **Fills:** a segmented track is ink at 6 %, a chip or field 7 %, a chosen row 9 %, a separator 12 %, and a focused field's edge 25 %.

### 10.3 Corners, kept concentric

When one rounded thing sits inside another, its radius is the outer radius minus the gap between them, so the gap stays even around the corner.

| What | Radius |
|---|---|
| Window | 17 pt (macOS) |
| Page | 10 pt (inset 8) |
| Card | 12 pt |
| Expanded card | 18 pt |
| Settings cards | 12 pt (20 where a picture sits inside) |
| Choice tiles, key wells | 14 pt outside, 8 pt inside |
| Buttons with words, chips, fields, segmented controls | capsules |
| Icon buttons | circles |
| The pill inside the toolbar's track | 14 pt in an 18 pt track (4 pt in on every side) |

### 10.4 Controls

| Control | Looks like | Used for |
|---|---|---|
| Pill button | Ink at 7 % with a 12 % edge; darker under the pointer | Every action with words: Check now, Forget, Manage…, Clear |
| Destructive pill | Red words; pink wash under the pointer | Sign Out, Clear History…, Delete |
| Prominent pill | Ink, lit from above (a slight top-to-bottom fall, a highlight along the top edge, three layered shadows); white in dark mode | The one main action on a page: Download Gaze Collector, Upgrade |
| Icon button | A symbol; a round plate under the pointer; the symbol bounces once when the pointer arrives | Close, ‹ ›, copy, delete |
| Glass capsule | Actions grouped in one Liquid Glass capsule | The expanded card's ‹ › · copy · delete; a day's ‹ › |
| Sliding segments | A capsule track; the chosen segment a white pill that slides | Type tabs, Settings tabs, Dictionary filter, Monthly · Yearly, calendar years |
| Switch | The system switch, in ink rather than the accent | On/off settings |
| Picker | The value and its chevrons in a pill | Microphone, language, how long to keep |
| Shortcut recorder | The keys in a pill, ⓧ under the pointer | Shortcuts |
| Choice tiles | Picture tiles; the chosen one ringed in ink with a check | Screen context |
| Toast | A black capsule at the page's foot | "Deleted" with Undo; confirmations |

### 10.5 Type and motion

- **Type:**
  - SF Pro throughout.
  - SF Mono only for times, counts and credits.
  - Day labels are small tracked capitals with a mono count ("TODAY  10").
- **Motion:**
  - Springs with no bounce.
  - Expanded card 0.32 s open, 0.26 s close.
  - Page and filter swaps 0.22 to 0.24 s.
  - The tab pill 0.12 s.
  - Hover 0.12 s.
  - A content swap fades and rises out of a light blur.
  - Reduce Motion turns all of these into a short fade.
- **The pointer's highlight never animates.** The calendar's hover ring jumps.

---

## 11. Keys and menus

| Key | Does |
|---|---|
| ⌘F | Search |
| ⌘1 … ⌘3 | All, Dictation, Dispatch |
| ← → ↑ ↓ | Move the selection between cards; ← → step the expanded card |
| Space, Return | Open the selected card |
| Esc | Close the expanded card; clear the selection; close search |
| ⌘⌫ | Delete the open capture |
| ⌘Z | Undo the delete (while the toast shows) |
| ⌘[ | Back (from a day, or Settings) |
| ⌘, | Settings |
| ⌘W, ⌘M, ⌘H, ⌘Q | Close the window (Fovea keeps running), minimize, hide, quit |

Every toolbar command is also in the menu bar (View, Go, Edit › Find).

**Variants** (in the menu bar, where the design panel used to be; the panel is gone for good) holds what's still being compared, each a menu with a check on the current choice:
- **Window:** cards under a toolbar (as now), or the sidebar (the library, Aside's layout).
- **Settings:** the sidebar with one section at a time (as now), the sidebar leading one scrolling page, tabs across the top, or one page with no sidebar.
- **Fitting the window to the new icon:** Focus (the selection ring as now; the icon's dot on the selected card and on today; or the o's thick ring), Avatar (the circle and arc; or the o, a rounded square with the credits as its ring), Type (SF Pro or SF Pro Rounded), and App Icon (put in the Dock as you pick them): the serif f, the app's icon since Oct 6, light and dark, and the geometric fo it replaced, in its variants.

---

## 12. What's real, what's simulated, what's not built

| Real in the prototype | Simulated | Not built here |
|---|---|---|
| Every screen and state described here; search over all fields; filters and periods; the calendar; the card and expanded-card motion; Settings' controls (their state lives in memory until quit) | The data (section 13.3); plan changes (nothing charged); sign out; checking for updates; the Gaze Collector download; agent status; permissions; deleting (in memory, with Undo) | Capturing itself (hotkeys, microphone, screen); the Island (`Prototypes/FoveaWorkbench`); storage on disk; accounts and payment; sync |

---

## 13. For coding agents

### 13.1 Where things are

| Path | What's in it |
|---|---|
| `Prototypes/CapturesCore/` | Pure Swift, no UI, tested: `Model.swift` (Capture, CaptureKind, Attachment, Destination, Library, Usage, DictionaryWord, Memory), `Search.swift` (CaptureQuery, CaptureSearch, the calendar periods), `History.swift` (a year's weeks, the years of use, months, quartile levels), `Lines.swift` (every computed string), `Fixtures.swift` (the data) |
| `Prototypes/FoveaCaptures/Model.swift` | `CapturesModel`: everything on screen (page, query, open card, Settings pane, plan…) and every action (open, step, delete, undo, setKind, openDay, choose a plan…). The settled design choices are its defaults. |
| `MainView.swift` | The window, the inset page, the toolbar, the first page's grid, the filter line, the toast |
| `CaptureCard.swift`, `Chips.swift` | The card; the inline chips and highlights |
| `DetailOverlay.swift` | The expanded card and its motion |
| `HistoryViews.swift` | The first page's feed, the calendar and its year tabs, a day's page |
| `SettingsPage.swift`, `SettingsKit.swift` | Every pane; the sections, cards, rows and Settings' layouts |
| `Controls.swift`, `Glass.swift` | Sliding segments, pills, icon buttons, the glass capsule, the shortcut recorder; the window material, the shading, Liquid Glass |
| `Tokens.swift` | **Every** color, size, radius, shadow and duration. Don't hard-code any of these in a view. |
| `Snapshots.swift` | The screenshot harness (`--snapshot`, `--frames`) |
| `LibraryView.swift`, `HotKey.swift` | A layout study kept in code: a sidebar library like Aside's, and ⌥⌘F to show the window from any app. Neither is used. |
| `Prototypes/Tests/CapturesCoreTests/` | 31 tests: search, periods, years, fixtures, lines |

### 13.2 Rules

- Use the vocabulary: **capture, type, attachment (the referent), words (the intent), destination, chat**. In UI copy, say "what you took", not "attachment".
- Keep `CapturesCore` free of SwiftUI and AppKit, and test what you add to it.
- Every color, size and duration goes through `Tokens.swift` (`T.Shade`, `T.Layout`, `T.Motion`).
- Never render an agent's output in this window. A dispatch shows only what you sent.
- No dashboards, streaks, stats or efficiency figures. The calendar shows density only.
- Don't add a Settings tab, or a section that amounts to a category, without raising it first (section 9).
- A dictation keeps its recording and what you took, as well as its words (App UI review, row 28: without them it couldn't be saved, played or transcribed again).

### 13.3 The data

- **Today:** "today" is Saturday 26 September 2026, 2:30 PM. The first page shows Thursday to Saturday.
- **This week** (20–26 September) is written by hand: realistic dictations, captures and dispatches, in English and Chinese, 60 to 100 words each.
- **History** goes back to January 2024, so the calendar has three years. It's generated from this week's words, busier on weekdays, quieter further back, with two trips with nothing at all. It's deterministic (a seeded generator), so every run and every screenshot is the same.
- **The rest:** the dictionary has about 120 words (the review asked for a design at 100–500), there are about 20 memories written by hand plus one for every fourth capture, in four areas of life, and the plan is Pro with 3,160 of 5,000 credits used. Five more captures show the review's additions: a site in Chrome, two failed transcriptions, Greek mythology and a budget (for the areas).

### 13.4 Check your work

```bash
cd Prototypes
swift build --product FoveaCaptures
swift test --filter CapturesCoreTests
swift run FoveaCaptures --snapshot /tmp/shots            # every state as PNGs, then quits
swift run FoveaCaptures --snapshot /tmp/shots --only plan # just the shots whose name starts with "plan"
cd .. && swift build                                     # the main app still builds
```

Look at the screenshots of whatever you changed, in light and dark, before calling it done.

### 13.5 Choices made, and where they depart from `AGENTS.md`

| Choice | Why | `AGENTS.md` says |
|---|---|---|
| Settings is in the main window, with tabs across the top. | Ryan's call: one window, no sidebar. | Settings is a flat sidebar and a detail pane. |
| macOS system colors, the accent and three type colors | Ryan asked for system colors. | The window is ink on paper, every neutral the ink at an opacity, no palettes. |
| Words in pills, a custom segmented control, monochrome switches | They follow Aside's finish, at Ryan's request. | (The HIG prefers system controls.) |
| The prominent pill has a gradient. | It gives the gloss. | Gradients are banned in the Island; nothing is said for the window. |
| Dictionary and Memories live in Account; Plan is its own tab. | Fewer tabs. | Dictionary and Usage & Plan are categories of their own. |
| A Language section (Fovea's language and the notch's) | App UI review, row 6. | Seven categories only. |
| Memory's areas of your life, summarized from your captures | App UI review, row 24 (Ryan's redesign, after ChatGPT's and Claude's memory). | No stored learned facts or inferred user profiles, and no UI for curating them. |
| A Help menu with Report a Problem… | App UI review, row 9. | (Nothing for the window's menu bar.) |

Other choices tried and set aside are still in code and in the screenshot harness: other color schemes (Macula, Blue Pencil, Notch, Paper), card spacing options, Settings layouts, the year graph below the cards, a library layout with a sidebar. They're not reachable in the app.
