# The window, aligned with the notch and the first run (Oct 24)

Ryan: "do you think the app itself is aligned with the design of the onboarding and the notch. i feel like there are little discrepencies. do extensive research on how can i adjust the ui of the app and then make it align with the notch and the onbaording more. generate a new version of the app ui for me to compare with the old." Then: "make sure to use skills from design engineers such as emil kowalski and others to refine the design."

**Short answer: no, not quite.** All three surfaces already share:
- the accent;
- the motion curves;
- capsules for words and circles for icons;
- SF Symbols.

The window then departs from the notch and the first run in about fifteen small ways. Each is minor alone; together they make Home and Settings feel like a different app from the one you just met in the first run and keep meeting at the notch.

So Fovea 1.0's window now has **two looks**:
- **Current**, as it was;
- **Aligned**, a new version drawn in the notch's and the first run's language.

Both are drawn by the same code (`WindowLook`, `T.Aligned` in `FoveaV1/Sources/FoveaWindow/Tokens.swift`), so they compare like for like. Current is the default and is unchanged.

**To compare:**
- **In the app:** View › Current Design / Aligned Design. The switch is immediate and kept for the next launch.
- **From a launch:** `Fovea --window-look=aligned`.
- **Pictures:**
  ```
  Fovea --design-shots window <dir> --data-dir=<scratch> --fixture --no-review [--window-look=aligned]
  ```
  `--fixture` puts the sample year in place of anyone's own captures, moved up to today. It only works with a `--data-dir` of its own.

---

## 1. What differs today

These come from an audit of the three tokens files and their views (`FoveaWindow/Tokens.swift`, `FoveaIsland/WorkbenchTokens.swift`, `FoveaOnboarding/OnboardingTokens.swift`). They're ranked by how much they show.

| # | The window | The notch (Native) and the first run |
|---|---|---|
| 1 | Labels are the Mac's light ladder: ink at 85 / 50 / 26 % | The board: 92 / 60 / 40 %. The first run: 94 / 62 / 40 % |
| 2 | Dictation is teal and Dispatch is purple, in the marks and the tabs | The notch's Voiceflow is "never a color", and Dispatch's color is the person's own light |
| 3 | Titles are 13 bold, meta 11 | A row's title is 13.5 semibold, its line 11.5 |
| 4 | The same Glass / Panels / Size prefs are the system's small segmented control in Settings | The first run draws them as its choice row: a track with the chosen one solid ink |
| 5 | The type tabs' pill is white and raised, with an edge and a shadow, and slides in 0.2 s on an ease-in-out | The first run's pill is solid ink, 0.12 s on the ease-out (Oct 23: the slow start made the button lag) |
| 6 | Three secondary-button styles: ink 7 % with an edge, the system push button, plain text | The notch has one, a fill with no edge |
| 7 | No press feedback at all | Both the notch and the first run give to a press, 0.97 in 0.14 s |
| 8 | Cards are white on gray with an edge and a shadow; Settings' groups are gray on white | The first run's cards and the notch's rows are fills, with no edge and no shadow |
| 9 | Home's cards say nothing of a task's state; "Not sent" is a red "!" | The notch: Working ring, Needs you "!" in orange, Complete check in green, Failed cross in red |
| 10 | Day labels are tracked capitals with an SF Mono count ("TODAY  12") | Sentence case, no capitals, counts in the system face |
| 11 | Page titles are 13 pt in the toolbar | The first run titles every page in New York, 30 semibold ("Make it yours") |
| 12 | The light's tiles in Settings › Notch are blurred bars, 5 across, ringed in the accent; the accent dots are 20 pt with a white ring | The first run's tiles are seven dots on black; its swatches are 16 pt with a white dot. These are the same prefs, drawn twice |
| 13 | Settings' sidebar has System Settings' colored tiles | Neither the notch nor the first run has colored tiles; their symbols are monochrome |
| 14 | The toast is a hard-coded black capsule | The notch has no black but the notch itself; the first run has no toast |
| 15 | Buttons are in Title Case ("Replay the Tour", "Try It") | The notch and the first run write them in sentence case ("Answer again", "Looks good", "Try it") |

Also found, but left for a decision (§5):
- **Appearance.** The window opens light (`windowAppearance = .light`), while the notch and the first run follow the Mac. Someone on a dark Mac finishes a dark first run and lands in a light Home.
- **AGENTS.md's claim is stale.** It says Home rows copy the Island's row ("44×32 thumbnail, same status words"); they don't.

## 2. What the research says

From a research pass with sources:
- Apple's HIG for Materials, Color, Typography, Toolbars, Sidebars and Live Activities;
- WWDC25 "Meet Liquid Glass" (219), "Get to know the new design system" (356) and "Build an AppKit app with the new design" (310);
- WWDC26 "Modernize your AppKit app" (289) and the brand sessions (250, 251);
- how Raycast, Wispr Flow, Granola, Linear and boring.notch keep one language across a small ambient surface and a full window.

The findings:
- **Glass is for controls and navigation, never content.** Content sits on an opaque layer. The window's toolbar glass stays, and the cards and groups don't become glass.
  - HIG Materials: "Don't use Liquid Glass in the content layer."
  - WWDC25 219: "always avoid glass on glass."
- **What travels between surfaces** in the apps that do this well:
  - the accent;
  - the status words and their colors;
  - the icon and mark system;
  - one row anatomy whose parts keep their order;
  - one radius scale;
  - one sans family.
- **What differs:**
  - the background (black or glass for the ambient surface, opaque for content);
  - density;
  - where display type appears.
- **The Live Activity rule applies to the notch and Home.** The expanded presentation is "an enlarged version of the compact… maintain the relative placement of elements."
- **Brand belongs in the content layer** (WWDC26 251), and a display face belongs in memorable moments and large headers. Granola and Wispr Flow keep their serif for those moments and the sans for the product. The first run already does this with New York, and the window can carry it in its page titles only.
- **Hierarchy comes from layout and grouping, not decoration** (WWDC25 356). Prefer fills to edges and shadows; scroll edges replace hard dividers.

## 3. The design engineers' rules applied

These come from Emil Kowalski's design-engineering skills and the Apple design skill in the scratchpad (`emil-skills/`, MIT), as already used for the motion pass (`docs/motion/SPRINGS.md`):
- **A press is answered on the press:**
  - 0.97 scale on the strong ease-out in 0.12 s (Emil: 100–160 ms);
  - the notch and the first run already do this, and the window now does too.
- **Choices made often move fast, and keyboard ones don't move at all:**
  - a choice slides over 0.12 s on the ease-out, never the ease-in-out's slow start;
  - ⌘1–3 jumps the pill ("Never animate keyboard-initiated actions").
- **Large type is tracked tighter:** the display titles at −2 % of their size, with tight leading. Body text keeps the system's tracking.
- **Hierarchy from weight, size and leading as a set.** Color is only for meaning:
  - the accent for what's chosen and the one main action;
  - green, orange and red for done, needs you and failed;
  - nothing for a capture's kind.
- **Things that look the same behave the same.** One button family, one choice control, one swatch and one light tile, wherever the same pref is set.
- **Nothing appears from nothing.** No new scale-from-zero. Reduce Motion stays an opacity fade.

## 4. The Aligned look

Every value is a token in `T.Aligned` (`Tokens.swift`), named for where it comes from. Current is untouched; each change is gated on `WindowLook.isAligned`.

### Foundation (`Tokens.swift`, `Controls.swift`, `Glass.swift`, `MainView.swift`)

| | Current | Aligned | Taken from |
|---|---|---|---|
| Labels | 85 / 50 / 26 % | 92 / 60 / 40 %, hairline 8 % | The board's title, line and time |
| The page | The window's material with an opaque page inset 8 pt (Aside) | The window's own opaque color, white or #1E1E1E, under the toolbar's glass | HIG: opaque content, glass for controls |
| Cards, groups | White on gray, with an edge and a shadow | A fill (ink 4.5 % / white 7 %), no edge, no shadow, r14. Only what floats keeps its shadow | The first run's cards; the notch's rows and outline card (r14) |
| A capture's kind | Teal / purple | Ink (secondary) on the cards; the toolbar's All · Dictation · Dispatch are words alone (Oct 24, Ryan: no mark before them) | Voiceflow "never a color" |
| Segments | White raised pill, 0.2 s ease-in-out; ⌘1–3 slides | Solid ink (white in dark) on the first run's track, 0.12 s ease-out; ⌘1–3 jumps | `NotchChoiceRow`; Emil |
| Primary button | Accent, darker under the pointer | Accent, lighter under the pointer (85 %) and pressed (72 %), 28 / 32 pt | The notch's Native buttons; the first run's heights |
| Secondary button | Ink 7 % with a 12 % edge | Ink 7 %, no edge, 11 % under the pointer, 15 % pressed | The notch's capsule |
| Press | None | 0.97, 0.12 s ease-out | The notch, the first run, Emil |
| Round icon buttons | A plate only under the pointer | A plate at rest (6 %), 12 % under the pointer; none inside a glass capsule | The notch's round buttons |
| Done | — | `palette.done`, the system green | The notch's Complete |

### Home

| | Current | Aligned | Taken from |
|---|---|---|---|
| A card's header | The title, with the app's icon at the trailing edge; under it the kind's colored mark, "kind · when" | The icon leads (24 pt), then the title (13.5 semibold) over the line (11.5, "kind · when", digits even). With no title row (the theme echoes the words), the line sits level with the icon | The board row: icon, title, line |
| Not sent | A red "!" | A red cross (`xmark.circle.fill`) | The notch's Failed. Its "!" means Needs you, in orange |
| Day labels | "TODAY  12", tracked capitals, an SF Mono count | "Today 12": New York 19 semibold, tracked −2 %, the count 13 pt with even digits in the tertiary ink | The first run's titles; the notch shows no capitals |
| The day page | The date in SF | The date in New York 26, tracked | The first run's page titles |
| Empty and no results | "No Captures Yet", 17 semibold | "No captures yet" / "No results", New York 22 | The first run's pages |
| Counts | SF Mono | The system face with even digits | The board's times |
| The toast | A black capsule | Glass, the words in the label color, Undo in the accent | The notch's surfaces: no black but the notch |
| Search's focus | Ink at 25 % | The accent | The notch's and the first run's fields |
| Tags | Fill and edge | Fill (7 %) | The notch's chips |
| The expanded card | White with an edge and a shadow | Opaque (`palette.detailSurface`), shadowed, since it floats | — |

A card fill is drawn as one opaque color (`palette.cardSurface`, #F4F4F4 / #2E2E2E), so a card zooming over the dim never shows through.

The window's root `.fontDesign` would turn New York back into SF, so display titles set their design closer in (`View.alignedDisplay(_:)`).

### Settings

| | Current | Aligned | Taken from |
|---|---|---|---|
| The sidebar | System Settings' colored tiles | The symbol alone, in the secondary ink, 12 pt in a 16 pt column, 7 pt to its 13 pt words (Oct 24, Ryan: "way too big… a better fit with the words": the Mac's sidebar list had scaled them up to its own icon size, so each row is drawn here). The chosen row is a fill (7 %), with no system selection under it; its symbol is in the accent and its words are semibold | The notch's and the first run's monochrome symbols |
| A pane's title | 13 pt in the toolbar; the page opens on its line | New York 26, tracked, at the top of the page, with the pane's line under it. The toolbar keeps only its back chevron | The first run's "Make it yours" over its line |
| Groups | Gray boxes on a white page, rows at the Mac's separator | The card fill at r14, rows split by the 8 % hairline; section headers 13 semibold | The first run's cards |
| Glass / Panels / Size, Wait, Motion… | The system's small segmented control | The first run's choice row: a solid ink pill (white in dark), 22 pt, sized to its words | `NotchChoiceRow` |
| Buttons in panes | System push buttons in Title Case | The notch's capsules in sentence case ("Replay the tour", "Try it", "Sign in…", "Restore defaults"); one prominent where a pane has one main action (Sign in, Upgrade) | The notch's buttons, the first run's voice |
| Pickers and fields | The system pop-up; an ink focus ring | A 28 pt capsule with no edge; fields ringed in the accent while focused | The notch's chips and fields |
| A setting that's on | A bare check in the secondary ink | `checkmark.circle.fill` in the system green | The notch's Complete |
| The light's tiles | Blurred bars, 5 across, ringed in the accent | The first run's: seven dots on black, three across, the chosen one ringed in the secondary ink; its Hue and Drift sliders | `AuraChip`, `HueSlider`, `DriftSlider` |
| Accent swatches | 20 pt with a white ring inside | The first run's: 16 pt, a white dot on the chosen one, its name at the end of the row | `Swatch` |
| Memory's areas | An accent tile | The symbol in ink | — |

Alerts, sheets, menus and links stay the system's, as AppKit dialogs should. The system switch stays too: it's already in the accent.

## 5. Departures, and what's left to decide

- **AGENTS.md "No palettes, no custom faces: SF Pro on both surfaces."** Aligned titles pages in New York, as the first run already does.
  - New York is a system face, not a custom one.
  - It stays out of controls, rows, cards and the sidebar.
  - Chinese uses the system face, as the first run does.
- **`FoveaWindow/DESIGN.md` §4 and §10 (the Aside chrome, the type colors, the raised white pill, Title Case buttons)** describe Current. Aligned departs from each of them, and says so above.
- **For Ryan:**
  1. Keep one look. Then delete the other's branches; the gates are all `WindowLook.isAligned`.
  2. Should the window follow the Mac's (or the notch's) appearance, rather than opening light? This changes a pref's default, so it's in neither look yet.
  3. Should Home's cards become the notch's rows outright, rather than cards that share the row's header?
  4. Should the window use the notch's agent artwork? It's bundled in FoveaIsland, which the window can't import.
  5. Fix AGENTS.md's Home-rows sentence either way.
