# Screenshots in the voice bar: capture mode, referent shapes, and the stack's expansion

A research note for the Notch Workbench (2026-09-27). "Attachments" in conversation are
**referents** here and in code (root AGENTS.md vocabulary). Sources: the Island PRD (§9, §11,
§14, §15) and its amendments, `docs/motion/NOTES.md`, `docs/island/VOICE_BAR.md`, the shipping
referent stack (`ReferentStackLayout`, `ReferentStackView`, `Tokens.Island.Layout`), and the
source of transitions.dev's "Card stack hover" demo, read on 2026-09-27. The workbench draws
all of it; nothing here changes the product.

## Capture mode

| Behavior | Choice | Why |
|---|---|---|
| In the panel | **Add screenshot** is the third entry in the Notch list, after Silent notch and Voice flow: the bar with capture mode on. Right ⌃ moves between Voice flow and Add screenshot. | One list of the notch's states. The shape and motion are decided (below), so the panel has no controls for them. |
| Key | **Right ⌃**, press-to-toggle: one bare press starts, the next stops. Left ⌃ does nothing; right ⌃ held for another key (⌃Tab) is not a press. | The same rule as fn (amendment, Input). The right key is told apart by its key code and the device flag `NX_DEVICERCTLKEYMASK`. |
| The bar | Starting capture opens Voice flow if it is closed; stopping leaves the bar and its captures. Closing the bar (fn) ends the session and clears them. | Captures need a home, and the bar is it. A capture session in the product is one hotkey session (AGENTS: Capture). |
| Pointer | The system's rectangle-selection pointer (`.pointerStyle(.rectSelection)`, macOS 15; a crosshair before). Applied inside the pages' scroll views too, whose clip views keep their own cursor otherwise. | The native pointer for drawing a rectangle. |
| What a drag does | A drag of 4 pt or more draws a region; released with both sides at least 12 pt, it is captured. | Smaller drags are clicks. |
| What still works | Clicks, the scroll wheel and the keyboard reach the page: tabs switch by click, ⌃Tab / ⌃⇧Tab or ⌘⇧] / ⌘⇧[, and pages scroll. | The drag is a *simultaneous* gesture on the screen and off outside capture mode, so it never takes a click or a wheel event from the page. Checked with real posted events in `--smoke`. |
| The region | Shaded as macOS's ⌘⇧4 shades a selection: translucent neutral gray over the selected area (a white page goes light gray, a photo darkens a little), a thin gray outline, nothing outside it dimmed. No size readout. | The way a Mac already shows "this part of the screen"; the numbers were noise for a capture that is not measured. |
| The pixels | The window as the window server composited it, cropped to the region: `CGWindowListCreateImage` on the app's own window (no Screen Recording permission), the region mapped from display points through the stage's probe. The selection is cleared 50 ms first so it is not in the pixels. | A real screenshot of what is on screen, scrolled page and all. |
| Feedback | The capture flies from its region into its card (0.45 s, critically damped), which waits hidden until it lands; its rounded corners grow into the card's shape on the way. | The eye follows the capture into the stack instead of losing it. |
| Esc | Closes the innermost thing: the opened stack, then capture mode. | PRD §15. |

## The bar with captures

The bar keeps its size, 212 × 76 pt (the notch's width, 44 pt below it). The first capture sits
in front at the left of the band; up to two more peek out behind it to the right, each 8 % smaller,
dimmer (60 % opacity, the reference's back cards are at 50 %) and tilted (+4°, −3°); the rest hide
behind them. The waveform moves right into the space left over, 23 to 29 pt depending on the
shape. The cards are 28 pt tall: an 8 pt inset from the band's edges, which makes the rectangles'
corners 6 pt, concentric with the bar's 14 pt corners (outer radius = inner radius + inset, the
rule DynamicNotchKit's docs state). Every card has a 0.75 pt white hairline at 20 %, so a dark
capture never dissolves into the black.

## Shapes

**Decided: the rounded rectangle** (2026-09-27). The other three stay in code for the comparison
snapshots, and the cards morph between shapes if the model's `referentShape` changes.

| Shape | In the bar | Opened | Of a 16:10 screenshot it shows | Where Apple uses it | Reads as |
|---|---|---|---|---|---|
| **Rounded rectangle** | 40 × 28, 6 pt corners | the capture's own proportions (0.6 to 2.2), 8 pt corners | about 99 % opened; 89 % in the bar | macOS's floating screenshot thumbnail, Messages and Mail attachments, the product's own review stack (44 × 32) | content |
| **Rounded square** | 28 × 28, 6 pt corners | 60 × 60, 8 pt corners | 62 % | album art in the Dynamic Island, app icons | an object, a token |
| **Circle** | 28 × 28 | 60 × 60 | 49 % | people: Contacts, Messages and FaceTime avatars; round buttons | a person or a control |
| **Capsule** | 45 × 28 | 96 × 60 | 87 %, but the four corners go, where tabs, toolbars and window titles live | pills and controls; the waveform's own bars | a control |

**Recommendation: the rounded rectangle.** Screenshots are content, usually text and interface,
and the rectangle is the only shape that shows all of one when opened, keeps its orientation
(a tall capture stays tall), and shares the island's geometry: its corners are concentric with the
bar's and the opened island's. It is also what Apple shows a screenshot as, and what the product's
review stack already uses, so the bar and the review would agree. The circle crops away half of
each capture and, on Apple platforms, says "person"; it only fits if referents should read as
small tokens rather than content. The rounded square is the fallback if the bar needs every card
the same footprint regardless of shape. The capsule echoes the waveform but cuts the corners
where a screenshot's chrome is.

## The expansion

### What the reference does (transitions.dev, "Card stack hover")

| Part | Value |
|---|---|
| Rest | three 78 px cards, 12 px corners, rotated −8°, +4°, 0°; the back cards at 50 % opacity |
| Hover: fan | each card moves `dx × 1.42` (±48 px) and rotates 6° further, opacity to 1, over 410 ms on `cubic-bezier(0.31, 1.84, 0.64, 1)`: past the target by 19.1 % at 207 ms, first at the target at 110 ms |
| Leave: fold | 360 ms on `cubic-bezier(0.34, 1.5, 0.64, 1)`: 8 % past at 213 ms |
| Hovered card | scale 1.04 over 610 ms on `cubic-bezier(0.22, 1, 0.36, 1)`, raised to the top |

### What the workbench does with it

- **To the right, never sideways.** The reference fans its cards left and right from the middle.
  Here every movement goes right from the first capture: at rest the pile peeks right; hovered,
  it fans further right (5 → 11 pt apart, tilts +8° and −6°) without moving the front card or the
  waveform; clicked, every capture is laid out left to right in the order taken, in rows that
  wrap, never reordered (PRD §14: "originates from the front thumbnail and reveals the stack
  without reordering items").
- **The island makes room.** The captures do not fit the bar, so the island opens, symmetric
  about the notch like every state: as wide as its widest row (at most 560 pt, the review width),
  cards 60 pt tall, shrinking by 4 pt steps before a fourth row is needed. Corners go to the
  expanded 19 / 24 pt; the cards' 8 pt corners are concentric with them (24 − 16 pt padding).
- **The surface leads, the cards follow.** The outline moves on a critically damped spring
  (0.24 s), the island's own rule (amendment §14). The cards start 60 ms behind it, 30 ms apart,
  front first (at most six steps, so the tail never waits past 0.24 s); folding back, last first.
- **The reference's bounce, capped.** The fan and fold keep the reference's curves and durations,
  but the overshoot is capped in points. A 19 % overshoot is 9 px on the reference's 48 px move and
  would be 57 pt on a 300 pt move, flinging a card out of the island's 16 pt padding:

  | Move | Reference overshoot | Capped |
  |---|---|---|
  | 48 pt (the reference's own) | 9.2 pt | 8.5 pt |
  | 120 pt | 23 pt | 11.6 pt |
  | 300 pt | 57 pt | 12.0 pt |

  The cap is `over / (1 + (over / 12)⁴)^¼`: nearly linear below 12 pt, saturating above it.
- **It breaks a rule, on purpose.** The amendments say nothing on the island bounces; the cards use
  the reference's capped curves because that is the motion asked for. The outline itself stays
  critically damped. A **No bounce** variant (critically damped springs, 0.30 s out, 0.24 s back)
  stays in code (`WorkbenchTokens.CardMotion`) if the rule should win.
- **Opened cards** scale 1.04 under the pointer on the reference's 610 ms ease-out and rise to the
  top; their help tag names the tab they came from.
- **Getting out.** A small `✕ esc` pill at the footer's left closes it, and so does Esc. The
  waveform keeps listening at the footer's right, so the voice session stays visible.

### Looking closer at one

- A click on a capture in the opened stack grows **that same card** into a close look: the
  capture's own proportions (0.4 to 3.0), up to the review width and 300 pt tall, centered, with
  8 pt corners, whatever the stack's shape, since a close look is for reading the capture. It
  moves on the card motion (the reference's fan by default); the island fits it on its critically
  damped spring; the other cards fade where they were (0.15 s), so going back is the same move
  reversed. PRD §11: "a larger inspection view without losing the draft".
- The footer names the tab the capture came from, and the pill becomes `‹ esc`: it steps back to
  all of them. So do Esc and a second click on the capture. Esc always closes the innermost thing:
  the close look, then the opened stack, then capture mode (PRD §15).

### Removing one

- Hovering a capture in the opened stack (or the one being looked at) shows a **✕** in its
  top-right corner; a click on it removes that capture.
- It is drawn in the island's own black and white: an 18 pt disc in the island's raised black
  (#111114, `Tokens.Island.Colors.surfaceElevated`), a white cross (8 pt bold, 90 %), and a 0.75 pt
  ring of white at 28 % so the disc reads on a white page as well as on a photo. Under the pointer
  the disc lightens. It fades and grows in with the hover (0.12 s, from 80 %), takes no clicks
  while hidden, and says "Remove screenshot" to VoiceOver (the card also offers a Remove action).
- Placement follows the shape: 5 pt in from the top and right edges of a rectangle; on the circle
  and the capsule, 45° up the right-hand curve, far enough in that the whole disc stays on the card.
- The removed card fades and shrinks to 90 % where it was (0.16 s) while the rest close the gap and
  the island fits them on one spring, then it leaves the list. Removing the last folds the stack
  away and the waveform goes back to the middle.
- **Reduce Motion:** every card and outline change becomes a 0.12 s fade; nothing flies.

### How it is rendered

- **One identity per card, one layout for every state.** `StackLayout` (pure) gives each card's
  place for rest, hover and opened, and the outline, the waveform, the stack's hit area and the
  pill with it. Cards are never swapped between views: no insert and remove transitions and no
  `matchedGeometryEffect`, which need a view to leave and another to arrive. Insert and remove
  transitions did not keep time with the island's outline when this was measured for the waveform
  (VOICE_BAR.md), and a morph between two layouts of the same views avoids the problem.
- **One vector per card.** `CardPlacement` is an `Animatable` modifier over a single
  `VectorArithmetic` value: position, width, height, corner radius, tilt and opacity. One animation
  moves all of them together, so a card grows, straightens and brightens on the same curve, and the
  stagger is one `.delay` per card.
- **The curve as a `CustomAnimation`.** `CappedOvershoot` evaluates the CSS cubic-bezier for its x
  and saturates the part past the target in points, using the moving value's own magnitude.
- **The outline is separate.** `IslandOutline`, also `Animatable`, carries the island's size and
  corners on its own spring and clips the cards, so a card still travelling never shows outside it.
- **The flight** uses the same modifier, from the region's rectangle to the card's placement,
  over the screen and above the island.

## Seeing it

- The panel: **Add screenshot** in the Notch list (right ⌃).
- `swift run FoveaWorkbench --play-demo` plays the walkthrough on launch;
  `--record demo.mp4` records it into a movie and exits.
- `--snapshot shots` adds `workbench-capture`, `workbench-stack-<shape>` and `-open` for each
  shape, `workbench-stack-peek`, `workbench-stack-hover` (the ✕) and `workbench-stack-inspect`.
- `--smoke` drives the flow with events posted through the app's queue (right and left ⌃, a click
  on a tab, the wheel, a drag, ⌃Tab, a click on the stack, Esc, the pill) and checks the shapes,
  the opened layout and the overshoot cap.
