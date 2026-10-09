# Fovea Captures

The app as an input tool: every capture as a Paste-style card, newest first by day. Search and
filters sit in the toolbar. The one icon at the top right is your profile. It opens Settings on
Account (you, your words, your memories; your plan has its own tab) in place of the captures. No
sidebar on the captures, no project view. The surfaces, corners and buttons follow Aside's (see
"Aside's shading, corners and buttons" below).

**New to this? Read `DESIGN.md` first.** It explains the whole design for people joining the work
and for their coding agents. This README is the log of how it got here. The dev team's App UI
review (Oct 6) and the decision on each of its rows are in `docs/window/FEEDBACK_2026-10-06.md`.

```bash
cd Prototypes
swift run FoveaCaptures                        # the window
swift run FoveaCaptures --settings voice:screen   # opens on a Settings section (and a part of it by id)
swift run FoveaCaptures --snapshot shots/c     # every state as a PNG (2×), then quits
FOVEA_OFFSCREEN=1 swift run FoveaCaptures --snapshot shots/c   # the same, drawn in-process: works with the screen locked (materials draw flat)
swift run FoveaCaptures --frames shots/frames  # the expanded card opening and closing, slowed 10×
swift run FoveaCaptures --eye-frames shots/eye # the Eye Tracking pane's gaze, every 150 ms
swift run FoveaCaptures --search-frames shots/s # the search icon opening into the field and closing
swift test --filter "CaptureSearchTests|AttachmentPlaceTests|LinesTests"
```

- `CapturesCore/` is pure and tested:
  - models, with the three types and anchored attachments
  - fixtures
  - search
  - every computed line
- `FoveaCaptures/`:
  - `MainView`: the window, the inset page and the toolbar
  - `Glass`: the window's material, Liquid Glass, and `shading` (Aside's edge and two shadows)
  - `Controls`: the sliding segments, pill buttons, round icon buttons, the glass action capsule
    and the shortcut recorder
  - `CaptureCard`: the card
  - `Chips`: the inline attachment chips
  - `DetailOverlay`: the expanded card and its motion
  - `SettingsPage`: every pane, including Account (with the dictionary and memories) and Eye Tracking
  - `CaptureExtras`: the App UI review's additions to a capture (a failed transcription, the
    recording, tags, where a dispatch went, Save, a picture opened large)
  - `FeedbackSettings`: the review's Settings (Language, your photo and name, Report a Problem,
    the plan's and the updates' states, places Fovea takes nothing from, the dictionary at
    its real size, Memory's areas and every memory, the questions, the window's errors) and the
    States menu's states
  - `Art`: the drawn regions
  - `LibraryView`, `HotKey`: the Aside layout study (a sidebar library, ⌥⌘F), off by default

## Two types (the App UI review, row 30: All · Dictation · Dispatch)

| Type | What happened | Fixtures |
|---|---|---|
| Dictation | You spoke; Fovea typed it into the app in front, with anything you took off the screen with Left ⌥ (a region, a passage or a file; twice: the whole screen). Fovea keeps what it typed, the recording and what you took (row 28). What was once a third type, Capture, is a dictation with things taken. | `d-…`, `c-…` |
| Dispatch | You spoke with fn ⌃, maybe taking things too. Fovea sent it to Claude Code or Codex; questions (the old Quick Answer) are dispatches. | `x-…` |

- **The fixtures are as long as people actually speak:** a few sentences to a paragraph each, 60 to 100 words, or 100 to 170 characters in Chinese. A test keeps them that way.

- **The header shows a three- or four-word theme, then the type and a compact time under it** (Ryan's pick). The type alone, or the theme alone, are panel options.
- **A theme is Fovea writing a summary of your words.** It can be wrong, and it costs a model call on every capture. The type is always true, which is why it stays under the theme.

## Fovea's own design language

The design-language study (sources in `shots/references/REFERENCES.md`) found that the window
read as Apple's sample code: gray canvas, white cards, a system-blue segmented control, every
neutral with no color at all. Fovea's ivory alone is too close to Granola's and Cursor's canvases
to carry a brand, so the identity comes from a second color, a few shapes, and the ink of the
notch.

**Color schemes** (the panel's Window › Surface; System is the default, at Ryan's request):

| Scheme | What it is |
|---|---|
| **Macula** | Ink and ivory, plus a highlighter yellow `#FCDE3D` used only as a fill behind ink. The fovea sits in the macula lutea, the "yellow spot"; highlighting what you point at is what Fovea does. |
| **Blue Pencil** | Ink and ivory, plus ultramarine `#283DDE` for what's chosen and what you pointed at (underlined, not highlighted). |
| **Notch** | The window as the Island grown out: an ink toolbar band in light mode with the controls in the dark appearance, black in dark mode, yellow only for what's live. |
| **Paper** | AGENTS.md's ink on `#FBFAF7`. |
| **System** | macOS's colors: the starting point, for comparison. |

- Every scheme sets the canvas, card, raised surface, text ladder, hairline, a color for each type, the calendar's five shades, and the selection and focus colors.
- Contrast was measured against the card: primary text 14–16:1, secondary about 7:1, tertiary about 4.7:1.
- Fovea's schemes draw the toolbar's band themselves (a transparent titlebar), so the toolbar is the scheme's canvas instead of the system's gray.

**Shapes and type** (in every scheme):
- **The referent tab:** a thing you took, numbered in SF Mono on a small squared tab in the scheme's mark. It's the same tab in your words, on the card's pictures and under the expanded card's pictures.
- **The Binding, made visible:** the words you pointed with ("this one", "这一屏") are highlighted (Macula, Notch) or underlined (Blue Pencil), and end in their tab. Fixtures mark them `{this one}⟨1⟩`; `Attachment.bound` keeps their length. Search hits are then set heavier and underlined, so the two never read alike.
- **The island pill:** in Fovea's schemes the type filter's chosen option is a small ink island that slides to it. System uses Aside's white raised pill instead.
- **Type marks:** a ring for Dictation, a ⌜⌟ bracket for Capture, a small island for Dispatch, each in its type's color; the word stays in ink.
- **Mono for numbers:** times, counts, credits. Day and section labels are small tracked caps with a mono count ("TODAY  10", "EARLIER  1,092 captures").
- **Texture only where nothing is:** a faint dot grid behind empty states.

**Where this departs from AGENTS.md:** "No palettes, no custom faces" (the window is ink at opacities only). The schemes add an accent and three type colors, at Ryan's request; SF Mono is a system face. The rule needs an amendment if Macula is kept. The calendar shows density only: no streaks, per AGENTS.md's rule on efficiency metrics.

## History: the last three days, then the calendar

- **The cards cover the last three days, and never more** (Ryan, Oct 7: a week was too much). The four squares' menu narrows them to Today (`CaptureSearch.within`: the calendar's own day, the last three days, week and month).
  - There's no "Any Time". Anything older is in the calendar above the cards.
  - Before Oct 7 the cards covered this month, and before that, seven days.
- **A search or an app works the same way.** Its matches in the last three days are the cards, and the calendar shades the days of all the others ("120 matches in 2026"). A click opens a day with only its matches. Empty: "No matches in the last 3 days. The calendar marks the days with older ones."
- **The expanded card closes at once** (Oct 7): shrinking back into the grid took the window through grey. It still grows from its card when it opens.
- **No recording to play and no Open in Claude Code** on any card (Oct 7). The expanded card's foot is its tags. The recording is still kept and is in the Save menu; Transcribe Again is only on a failed recording.
- **The calendar shows one year at a time.** A tab per year of use sits above it (the same sliding pill as the toolbar's), with the year's total beside it.
  - It's shaded like GitHub's contribution graph: no captures is empty, and the rest split into four levels at the quartiles of your busy days.
  - Days still to come are outlines.
  - Opening a day from anywhere turns the calendar to that day's year.
- **Hover follows the pointer at once.**
  - One tracker over the whole graph works out the day from the pointer's place, gaps counting as the day before, and moves one ring there with no animation.
  - The line under the graph names the day ("12 on Tuesday, September 15"); a click opens it.
  - Before, each of the 371 squares had its own hover area and tooltip. A fast pointer lost their enters and exits, and a tooltip waits a second and then stays where it first appeared.
  - The month calendars work the same way.
- **Four layouts**, on the panel's History section:
  - **Year graph below the cards**.
  - **Year graph above the cards** (the default, Ryan's pick): GitHub's profile order, so the calendar is reachable without scrolling past a month of cards.
  - **Month calendars below the cards**: the year's months, dated. Easier to find a date in; shows less at once.
  - **Timeline pinned on top**: a bar per day under the toolbar, scrolling back a year, always in reach.
- **A day opens two ways:**
  - **A page of its own** (the default): the date large, its types ("3 dictations · 1 capture · 5 dispatches"), and ‹ › to the day before or after with captures.
  - **In place**, under the calendar, with a close button.
- **Archived cards show the time of day** ("10:42 AM"), since the header already names the day. This week's cards keep "3m" and "2d".
- **The data:**
  - "Today" in the fixtures is Saturday 26 September 2026, late in a month, so there's a month of cards to scroll.
  - Use goes back to January 2024, so the calendar has three years. The last year is busier on weekdays, quieter a year ago, with two trips with nothing at all and a few heavy days; before it, the first months are quieter still.
  - It's deterministic, and `HistoryTests` covers it, along with the periods and a year's weeks.
  - "Just this week" is the panel's other set.

## The card (Paste 6, the default)

**Ryan's picks:** theme then type, the icon small and whole, chips with a preview below, medium.

**Anatomy:**
- **Header:** the theme in bold (Headline 13), and under it the type's mark, the type and the compact time ("Dispatch · 18m").
- **Icon:** where the words went, small and whole (20 pt) at the trailing end.
  - A dictation or a capture shows the app in front.
  - A dispatch shows its agent. Claude Code uses the Claude app's own icon (its spark is Claude Code's mark). Codex is its mark on a tile drawn to an app icon's grid, because the only OpenAI app here (`ChatGPT.app`, bundle id `com.openai.codex`) shows the ChatGPT knot.
  - Paste 6 moved to this, and the HIG doesn't crop app icons.
  - Paste 5's band, with a big icon cut by the corner, is the panel's alternative. So is a small icon before the type.
- **Body:** your words, with a chip at the exact place you took each thing (see below).
- **Preview:** what you took fills the rest of the card, edge to edge, each tile numbered at its bottom-leading corner.
- **No footer.**

**Spacing** (the panel's Card › Spacing; `CardSpacing`). Four options; the anatomy, sizes and colors are the same in all of them. Less in each card is the default (Ryan's pick):

| | As before | A little more air | Airy | Less in each card |
|---|---|---|---|---|
| Inset (medium card) | 14 | 16 | 18 | 16 |
| Header's two lines apart | 1 | 2 | 3 | 2 |
| Header to words | 12 | 14 | 16 | 16 |
| Line spacing (13 pt) | +3 | +3 | +4 (1.5×) | +4 |
| Lines over a preview | 3 | 3 | 3 | 2 |
| Lines with nothing taken | all that fit | all that fit | all that fit | 7 |
| Words to preview, at least | 10 | 12 | 14 | 14 |
| Between cards | 16 | 20 | 24 | 20 |
| Day label to cards / between days | 12 / 40 | 14 / 44 | 16 / 48 | 14 / 44 |

- **Why**, from the research (notes in the scratchpad's `research-cards/cards.md`):
  - What feels cramped is the padding and the gaps, not the line spacing.
  - The space between cards should be clearly larger than the space inside one (NN/g, proximity). It was 16 between and 14 inside (1.14×).
  - Paste's cards, measured from MacStories' full-size screenshots, are about 1.7×: 24 between, 14 inside, on a 320 pt card.
  - Apple's widgets take a 16 pt margin on smaller squares.
  - Narrow text reads best near 1.5× line height (Refactoring UI).
  - Every option keeps the order header lines < header to words < inset < between cards < between days.
- **Less in each card** finds its room by showing less: two lines over a preview (which gets about 20 pt more), and seven at most otherwise. It keeps Ryan's two-line header, where the research's version folded it into one line.
- **What the research couldn't verify in time:** Apple's Notes, Freeform, Photos and App Store cards, Raycast, Things, Craft, mymind, Notion, Linear, Arc, Are.na. Only Paste (measured), Pinterest (its source: 236 pt columns, 14 pt gutters, no padding inside) and Apple's guidelines gave numbers.

**Behavior:**
- Under the pointer the card's wide shadow grows; nothing moves.
- A press settles the card to 98.5 %.
- The keyboard's card gets an accent ring outside it with a small gap. It turns gray while the window isn't key.

**Inline attachments** (`Capture.segments`, `Chips`):
- Each attachment stores its `anchor`: the UTF-16 offset in your words where you took it.
- The card and the expanded card both cut the text at the anchors and set a chip there, drawn like the Island's voice bar:
  - a small picture of what you took: the region itself, a quote mark for a passage, or the file's icon
  - its number
- **Fixtures** mark the place in the text: `"…this one⟨1⟩ match…"`.
- **Tests** cover:
  - runs cover the text exactly
  - chips taken together sit together
  - VoiceOver hears "(region 1)" at the right place

## The expanded card

**What it shows:** only your words (for a dictation, the transcription and nothing more) and what you took, large.
- Regions are pictures, numbered under the image with where they came from.
- Passages are quotes; files show their icons.
- No type, no destination, no time, no duration.
- The app icon in the bar is a panel option, off by default.

**Buttons** follow the toolbar convention:
- Borderless SF Symbols at 28 × 28 pt, with a rounded fill on hover (eases in over 120 ms) and a deeper one while pressed (instant, no scale).
- Every button has a tooltip.
- **Close** sits at the leading edge, where a window keeps its own. Esc closes.
- **‹ ›** step through what's shown, also with ← →. Steps switch at once, because keyboard actions aren't animated.
- **Copy** swaps to a checkmark with the system's symbol replace effect.
- **Delete** (⌘⌫) is immediate. Undo sits in the toast and on ⌘Z, per the HIG's rule: don't confirm an undoable delete.

**Motion** (`DetailOverlay.swift`). The old version had three problems:
- The header and icon were drawn at their final place at once.
- Only the background grew.
- The content waited about 180 ms; the close removed it at once, so the open took about twice as long as the close.

The new one:
- **One progress value drives everything**, 0 at the card and 1 open:
  - the surface's frame, corners and shadow
  - the card's own face fading out (its header and icon riding the growing edge)
  - the expanded content fading in, out of a 4 pt blur, laid out at its final width so no line re-wraps
  - the regions flying from the card's preview to their places
- **The card in the grid is hidden** while the surface stands in for it, and shows again in the same frame the overlay goes.
- **Open:** spring, no bounce, 0.32 s.
  - The card's face is gone by 30 % of the way (about 55 ms).
  - The expanded content arrives between 16 % and 70 % (about 35–125 ms).
- **Close:** the same path backwards, 0.26 s, about 0.8 of the open.
  - The expanded content is gone within the first third.
  - The card's face returns over the last 30 %.
  - It settles into the same slot.
- **Interrupting** (a click or Esc mid-flight) reverses from where it is.
- **Reduce Motion** turns it into a fade in place.

**Sources:**
- Quick Look zooms from and back to the item's frame (QLPreviewPanel docs).
- Material's container transform, and its timings (open 300 / collapse 250 ms; exits shorter).
- Emil Kowalski's rules: under 300 ms; geometry first, content ~50 ms later; blur to hide a crossfade; never animate keyboard repeats.
- Apple's springs: bounce 0 by default.

The full notes are in the session scratchpad (`research-native/`).

## Settings, in the window

Rebuilt from the settings study (Raycast, Linear, Vercel's Geist, Bartender, Stripe, Primer; links in `shots/references/REFERENCES.md`) with `SettingsKit`:
- **Cards:** paper cards with a hairline, not gray boxes. Section titles in sentence case, 8 pt over their card and 36 pt below the one before.
- **Rows:** a title over a description only when the title doesn't say what it does, with the control at the right. Native switches, monochrome; values as pills (the value and its chevrons).
- **Custom controls only where a picture says more:**
  - choice tiles for Screen context;
  - key caps for shortcuts, with large tiles for fn and fn ⌃;
  - chip wells for the dictionary and for "Never capture in".
- **Status as a word:** "✓ Allowed" when all is well. When something needs you, a warning dot, the word in ink, and the fix beside it.
- **Buttons:** at most one bordered button per card; the rest are words.
- **Undo vs danger:** reversible removals act at once with Undo. The irreversible gets a danger card with real counts ("Delete 1,104 Captures").



- **The profile icon** at the top right is the only icon there. It opens Settings on Account; a second click comes back. ⌘, and Back (⌘[) work too.
- **Layout (October):** System Settings' own. A sidebar of tiles (a rounded square of color with a white symbol each, grouped by space) at the left; the section picked shown alone beside it, opening with its tile, name and purpose, its settings in the Mac's grouped boxes (`SettingsSidebar.swift`, `T.Native`). Nine sections: AGENTS.md's seven (Dictionary renamed Memory, holding the Dictionary and the Memories) plus Appearance (Light, Dark or Auto, and the accent from the Mac's set; `AppearanceSettings.swift`) and Notch (`NotchSettings.swift`). Notch has the glow's color board from the Notch Workbench: a palette or Custom, the hue, the spread, the drift and the seven colors. It sits under a live notch drawn by the Workbench's own renderer, so changes show at once (`NotchGlow.swift`). It also has how the board opens, reviewing before sending, and Restore Defaults. A control shows only where it can change something (Spread for Custom alone). The section you're in is marked in the accent you picked. The other layouts are on Variants › Settings.
- **Variants**, in the menu bar (the design panel is gone for good): Window (cards, or the library's sidebar), Settings (above), and the icon-fit variants: Focus, Avatar, Type, App Icon. View › Appearance holds Light, Dark and System, as does Account › On this Mac. `--snapshot <dir> --only menus` prints both menus with their checks. `--only glow-live` writes the Notch pane's glow moving, 23 frames through opening it, picking Custom, sweeping the hue and the spread, going dark and scrolling (the shots draw a still frame).
- **Width** (the panel's Window › Settings' width; `SettingsArrangement`). The one 560 pt column left the page's sides empty. Four options; Titles beside the cards is the default (Ryan's pick). An arrangement the page hasn't room for steps down to one that fits:

| Option | What it does | Width |
|---|---|---|
| One column (as before) | Every section in one centered column. | 560 |
| One wider column | The same, with more of the width. | 720 |
| Titles beside the cards | Each section's title and note in a column at the left, its card at the right. Untitled cards, such as the account header or the Eye Tracking picture, run across both. | 224 + 32 + 560 |
| Two columns | Sections flow into two columns, each into the shorter. | 2 × 440 + 24 |

**Titles beside the cards, divided.** The title column didn't read as a sidebar, or as anything. The research (notes in the scratchpad's `research-sections/sections.md`) checked four products that put titles beside content: Apple's spec pages, Tailwind's Catalyst, Shopify Polaris's annotated sections and Laravel Jetstream. Every one draws a hairline across both columns between sections. None tints the title column or draws a rule between the columns, which is what makes a column a sidebar. So:
- **A 1 pt rule (the ink at 10 %) across both columns** between one titled section and the next. It's 32 pt from each side, three times the gaps inside a section. There's none above the first, and none against a card that runs across both columns.
- **Titles are the section's heaviest text:** 15 pt semibold, level with the card's top, the note 4 pt under.
- **Each title stays 16 pt under the top of the page while its section scrolls by**, and leaves with it (Linear's changelog, GitLab's settings).

| Pane | Holds |
|---|---|
| Account | Profile (you, and Sign Out…), laid out as every section is, title at the left; Dictionary (All · Learned · Added by you, add a word); Memories (whether Fovea remembers, each memory with Forget); On This Mac (login, Dock, updates, version). Your plan and credits are the Plan tab's alone. |
| Plan | This month's credits; the plans side by side (Free · Pro · Max), each with who it's for under its name, its price (Monthly · Yearly) and what it includes, the one you're on marked Current; Billing (when it renews, or that a move down is waiting, with Keep). Moving up is at once; moving down waits for the credits to reset and can be taken back until then. Each asks first. Simulated, and the prices and limits are placeholders. AGENTS.md's "Usage & Plan" category, as one tab. |
| Voice & Capture | Voice (microphone, speech language, sounds when listening starts and stops); Screen awareness (what dictation reads from your screen: what you pick, always; the window you're speaking into and the text in it, each a switch, Oct 7); Capture (reading text, never capture in); History (keep captures, keep screenshots); Permissions (Microphone, Speech Recognition, Screen Recording); Clear History…. There's no Island style: Fovea is always the Dynamic Island. |
| Shortcuts | fn: Voice Flow · fn ⌃: Dispatch · Left ⌥ once: take a region, text or a file · Left ⌥ twice: take the whole screen · ⌃ alone: expand the Island when it can; Restore Defaults; Accessibility and Input Monitoring |
| Connectors | Agents (Claude Code, Codex, Cursor); Questions (answer with, screen context); What Agents Can Read |
| Eye Tracking (Soon) | Not built yet. It shows the feature and invites you to help collect data: an animated gaze moves between windows on a small screen and "this" appears where it rests; the three steps; Download Gaze Collector, then its progress, then Open; and what the Collector records |

- **No writing setting** (Oct 7): Fovea writes up what you said one way, Auto. That is Faithful in code editors and terminals, Polished everywhere else. "Transcribe Again" on a capture uses the same rule.
- **Removed:** how attachments go in (Simple / Clean / Detailed).
- **Every value is simulated.** The download fetches nothing, and the Collector's size and copy are placeholders to confirm.

## Native pass

**Colors:**
- macOS's semantic colors, sampled from AppKit on this Mac: window background #ECECEC behind white cards in light mode; #1E1E1E behind #2A2A2A in dark.
- The label ladder 85 / 50 / 26 %, 10 % separators, and the system fills.
- Search hits use the system's find highlight.
- **Paper** (AGENTS.md's ink on canvas) is the panel's other surface. There, hits are set heavier, because Paper has no highlight color.

**Type:** macOS's text styles: Headline 13 bold, Body 13, Subheadline 11, Title 3 15 in the expanded card. Nothing under 10 pt.

**Spacing** follows design engineers' rules: Jakub Krehel's layout skill, Vercel's interface guidelines, Refactoring UI, Linear and Apple's HIG Layout. The notes are in the scratchpad's `research-spacing/spacing.md`.
- **One scale:** 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40. The off-scale values are named as what they are: a card's inset (about 6 % of its width) or an optical nudge.
- **More space between groups than within one:**
  - 16 pt between cards (20 on Paper, where card edges barely show)
  - 40 pt above each later day
  - 12 pt from a day's title to its cards
  - 20 pt under the toolbar
- **The grid is one centered block**, 24 pt from the window's edge at least, and at most 6 columns. The window is at least 800 pt wide, so 3 columns always fit.
- **Card insets scale with the card:** 12, 14 and 16 pt for the small, medium and large cards. The header sits on one baseline, the app icon is centered on the title's capitals, and the space under the header is a little more than the space above it.
- **The expanded card's text is held to about 75 characters a line** (520 pt of 15 pt text).
  - With pictures, the card is 720 pt wide, so they use the full width under the narrower text.
  - Words only, it's 600 pt with 40 pt around them.
  - Close, and the actions' capsule, are glass, 12 pt in from the top and the sides.
- **Settings:** the form column is 560 pt, so a label stays near its switch, and the notes under each section are left-aligned with its rows.
- **The window has one size, 1112 × 784 pt** (`T.Layout.window`), as Wispr Flow's and Typeless's do: it can't be resized or made full screen. That's the size it had on Ryan's 13-inch Air, and four columns of cards fit in it.

**Corners:** see "Aside's shading, corners and buttons" below.

**Toolbar:** three groups, each with room, and no title.
- **Leading:** the app filter, just the four squares in a glass circle, as tall as the toolbar's other glass. What it does is found by opening it.
  - The whole circle opens it.
  - Its menu lists every app with its own icon, most used first, then the tags, then the period: Last 3 days (the default) or Today.
  - It filters by where the words went: the app for a dictation or a capture, the agent (Claude Code, Codex) for a dispatch, so it matches the icons on the cards.
  - While a filter is on, the squares are filled, and the line above the cards says which.
- **Center:** the type, like Calendar's Day · Week · Month, as Aside's sliding pill. On macOS 26 and later the toolbar's glass is its track.
  - Every segment is as wide as the widest, as a segmented control's are.
  - The pill answers the press itself (mouse down, as browser tabs do) on its own 0.12 s spring (`T.Motion.pill`). The cards change once it has landed, so a heavy grid swap can't stall it mid-flight; a quicker second press wins.
  - **Concentric ends.** The control draws its own glass track, as tall as the toolbar's other glass (36 pt), and the 28 pt pill sits 4 pt in on every side. A capsule inset evenly in a capsule is rounded by the track's radius less the inset (18 − 4 = 14), so at either end the pill's curve follows the track's. Before, the pill sat in the toolbar's own glass with more room above and below than at the side, and its ends didn't follow the track.
  - Settings' six tabs are as wide as the widest only where the window has room (1,100 pt and up). Below that each is as wide as its words, closer still under 900 pt. In a 980 pt window the toolbar gives its center about 530 pt.
- **Trailing:** search, then the profile icon, each in its own glass circle as tall as the toolbar's (36 pt).
  - **Search** is an icon until you want it. A click or ⌘F opens it into a glass capsule that grows leftward out of the circle, inside a slot the toolbar keeps for it, so nothing else moves. The slot hides the toolbar's own glass, so it never shows as an empty capsule.
  - The placeholder fades in once the field has opened, and leaves first when it closes, because AppKit draws the text field at its final size at once.
  - Leaving it empty, or pressing Esc, folds it back into the icon; while it holds a search it stays open.
- **Menu bar:** every toolbar command is also there:
  - View ⌘1–4
  - Go › Back ⌘[
  - Edit › Find ⌘F
  - Settings… ⌘,

**Grid:** one centered block as wide as its columns, so the space left over is split evenly instead of piling up on the right; the day headers align with the cards.

## Aside's shading, corners and buttons

Ryan's ask: keep this app as it was and take only how Aside shades its surfaces, rounds its
corners and draws its buttons. Sources:
- **heyaside.com's CSS.** The site rebuilds the app's views in HTML at the app's own point sizes, so its stylesheet gives exact values.
- **The app on this Mac** (macOS 27), explored earlier: its library, Settings and menus.
- The notes are in the scratchpad's `research-aside/web.md`.
- The values live in `T.Shade` and `T.Layout`.

**Shading.** Every neutral is the ink at an opacity:

| Ink at | Used for |
|---|---|
| 6 % | segmented track |
| 7 % | chip and field fill |
| 8 % | a surface's own edge |
| 9 % | a chosen row or a hovered icon |
| 10 % | a hovered fill |
| 12 % | separators and control edges |
| 25 % | a field's focus edge |
| 85–95 % | a prominent pill, a chosen tile |

- **A surface** is told from what it sits on by a 0.5 pt edge just inside it and two soft shadows: a tight one where it touches, a wide one around it. Never a gray box.
  - In dark, a rim of light along its top edge as well, the gloss.
  - Levels:
    - resting: the cards, Settings' cards, the tiles
    - raised: a card under the pointer; the wide shadow grows and nothing moves
    - floating: the expanded card, grown from the card's resting shadow
    - page: the inset page
  - Light uses Aside's own numbers: controls `0 1 3 .07`, its reading card `0 1 12 .08`. Dark needs about four times the opacity to show.
- **The window is the system's material around an opaque page.** The page is inset 8 pt, so the desktop shows through the frame, as through Aside's sidebar.
  - Fovea's own schemes frame the page in their canvas a step darker, or in the Island's ink (Notch).
  - The panel's Window › Page puts the page back across the whole window; Around the page picks the material (vibrant, Liquid Glass, solid).

**Corners, concentric** (Aside: "the reading card's corner follows the window's curve"):

| What | Radius |
|---|---|
| Window | 17 pt (macOS 27, measured from the shots) |
| Page | 10: inset 8 in the window, so 17 − 8, rounded up as Aside does |
| Card | 12 (Aside's card) |
| Expanded card | 18 (Aside's reading card) |
| Selection ring | the card's radius + its 3.5 pt offset |
| Eye Tracking's picture | 12, inset 8 in a card rounded 20 |
| Settings' tiles and key wells | 14 outside, 8 inside, inset 6 |
| Round buttons in a glass capsule | 28 pt circles with 4 pt of glass around them, so the capsule's ends are concentric with them |
| Controls with words | capsules |

**Buttons:**
- **Words are pills** (Aside 2.0).
  - Secondary: the ink at 7 % with a 12 % edge, a step darker under the pointer. Every former text button is one now: Manage account, Check now, Forget, Clear…
  - Destructive: red words, with Aside's pink wash under the pointer.
  - Prominent, one per page (Download Gaze Collector): the ink lit from above. A slight fall from top to bottom, a highlight along the top edge, a shade along the bottom, and three shadows at 1, 2 and 4 pt that double under the pointer and close to one when pressed. White in dark.
- **Symbols are circles**: one round control for every icon, with a plate under the pointer and a pink plate for Delete. Each symbol bounces once when the pointer arrives (Aside: "animated hover icons").
- **Actions sit together in one glass capsule:** the expanded card's ‹ › | copy, delete, and a day's ‹ ›. Close is a glass circle.
- **A choice of a few is a pill that slides along a track:** the kinds, Settings' panes, the Dictionary's All · Learned · Added.
- **Switches are monochrome:** the ink, not the accent. Aside went monochrome in 1.3.9.
- **Fields:**
  - Search's focus is Aside's 1 pt edge at 25 %, not a blue ring.
  - The pickers in Settings are pills with their chevrons.
  - Shortcuts are recorder pills that show a ⓧ under the pointer.
  - Chips are the ink at 7 % with a 12 % edge.
- **The accent stays for focus and selection only** (the selected card's ring, search hits, the calendar): macOS's color, as Ryan asked.

**Not taken:**
- Aside's segmented pill overshoots a little (`cubic-bezier(.32,1.3,.58,1)`). Here it settles with no bounce, as every other spring in Fovea does.
- Aside's layout. A sidebar library with an island over the page was built as a study first, then set aside at Ryan's word. It's kept on the panel's Studies › Layout, along with ⌥⌘F to show and hide the window from any app. Both are off by default.

## The control panel is gone

The design is settled, so the control panel that sat beside the window (Go to, Play, and every design switch) has been removed for good, along with the store that kept its choices.
- The settled choices are `CapturesModel`'s defaults: theme then type, a small whole icon, chips with a preview, medium cards with less in each, the calendar above the cards, the System surface, Settings with titles beside the cards.
- The alternatives this README describes as "the panel's" options are still in code. The snapshot harness renders them for comparison; the app doesn't reach them.
- **For the design as a whole, start with `DESIGN.md`** in this folder. It's written for people new to the work and their coding agents.

## Where this departs from a rule, and why

- **Settings live in the main window** because Ryan asked for it. The HIG wants a separate Settings window.
- **Search isn't last in the toolbar.** The HIG puts it at the trailing edge; here the profile icon comes after it, so it stays top-right on every page.
- **No window title.** The HIG titles a window after what it shows; here the filter takes that place, at Ryan's request.
- **The System surface is the default.** AGENTS.md makes the window ink on paper, and Ryan asked for macOS-native colors. Paper is one switch away.
- **Account › On This Mac holds what other apps call General.** AGENTS.md bans a General category, and the shipping spec puts these rows in Account too.
- **Words in pills, a custom segmented control, monochrome switches.** The HIG prefers system push buttons, segmented controls and accent-tinted switches. These follow Aside, at Ryan's request.
- **The prominent pill has a gradient.** AGENTS.md forbids gradients in the Island. Nothing says so for the window, but it's the one gradient here.

## Not verified

- **Keyboard routing in a live session.** Arrows, Space, Return and Esc in the grid, and ← → in the expanded card, weren't driven by hand. The snapshots and frame recordings run the same model calls without key events.
- **Inactive-window rendering.** Snapshots are taken with the window not key (`FOVEA_NO_ACTIVATE`), so toggles and segmented controls draw in their inactive gray.
- **Hover and press states** (the cards' lift, the pills, the icons' bounce, the pink wash) are in the code but not in the snapshots, apart from one card's hover (`window-hover`).
- **macOS 14 and 15.** Their fallbacks (the vibrant material in place of Liquid Glass, a drawn track under the sliding pill) were checked only with the panel's Liquid Glass switch on macOS 27. The toolbar's track and glass still come from 27 there.
- **Aside's Settings controls weren't re-checked in this pass.** Screen capture failed, so the switches, recorder and tiles follow the site's CSS and the earlier notes.
