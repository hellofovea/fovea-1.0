# Motion in Fovea 1.0: springs and curves (Oct 21)

Ryan: "research what spring animation is, then apply it to our Dynamic Island and all the other places that need it; use Emil Kowalski's skills to refine the animations."

**Read the last section first.** "Oct 21, last: less" removed much of what the tables below describe (blurs, scales, staggers, bounces, loops). Where they disagree, the last section and the tokens win; the tables stay as the record of what was there.

## What a spring is

A spring animation doesn't play a curve for a fixed time. It simulates a weight on a spring pulled toward its target:

- **Stiffness** is how hard the spring pulls.
- **Damping** is how much friction stops it.
- **Mass** is how heavy the weight is.

The motion has no fixed length; it ends when the weight settles. Two properties make it right for an interface:

- **It can be interrupted.** A new target mid-flight just re-aims the spring, and its current velocity carries over. There's no jump and no wait for the old animation to finish. A curve can't do this: it restarts, or it stops dead.
- **It reads as physical.** Things accelerate and settle the way real objects do. A little overshoot (bounce) makes a surface feel elastic and alive. Apple's Dynamic Island was designed "to feel like a living organism, with a deliberate elasticity".

Apple replaced the physics triplet with two numbers that are easier to reason about (WWDC23, *Animate with springs*). SwiftUI's `.spring(duration:bounce:)` and `.interpolatingSpring(duration:bounce:)` take them directly:

- **duration** is the *perceptual* duration: how long until the motion feels finished. A tiny tail settles after it.
- **bounce** runs from 0 (critically damped, no overshoot) to about 0.3 (visible overshoot). A negative bounce is overdamped: slower, no overshoot.

The two are related to the physics: `dampingFraction = 1 − bounce`. `.smooth` is bounce 0, `.snappy` is 0.15 and `.bouncy` is 0.3, each 0.5 s by default.

`.interpolatingSpring` adds overlapping animations together, keeping velocity through rapid re-targets. Use it for the island and for anything that can be re-triggered quickly, like a hover in and out. `.spring` retargets the running animation; it's fine for one-off moves.

## The rules (Emil Kowalski's design-engineering skills, and Apple's)

From `emilkowalski/skills` (MIT): *animate*, *review-animations* (STANDARDS.md), *improve-animations* (AUDIT.md), *apple-design*. From Apple: *Designing Fluid Interfaces* (WWDC18) and *Animate with springs* (WWDC23). And from Fovea's own course notes: docs/motion/NOTES.md.

1. **The right animation for what it's doing** (Oct 21, Ryan: "don't always use springs").
   - Springs for what is alive, thrown, dragged or interrupted all the time: the island, a released chat.
   - A strong ease-out curve for entering and exiting.
   - A strong ease-in-out curve for moving or morphing on screen.
   - `ease` for hovers and colour.
   - Linear for constant motion.
   - Never `easeIn` on the interface. The palette table below has the cases.
2. **Bounce follows the meaning.**
   - Most interface springs are critically damped (bounce 0) or nearly so.
   - Bounce is for things that are alive (the island) or were thrown (a flicked or dragged chat on release), and it stays subtle: 0.1–0.3.
   - A menu or sheet that just appears gets no overshoot.
3. **Bounce and size.** Smaller surfaces need more bounce for it to be noticed. Larger ones need a longer settle and less bounce (Emil's Dynamic Island builds: 0.5 between small states, 0.3–0.35 into and out of larger ones).
4. **Fast where the system answers, unhurried where the person is deciding.**
   - Interface motion is felt as done within about 0.3 s.
   - Exits are shorter and simpler than entrances.
   - Large surfaces may take longer (about 0.4–0.5 s) but with less bounce.
5. **Never from nothing.** Nothing scales from 0. Things enter from 0.95–0.97 and opacity 0, with a 2–4 pt blur at most.
6. **From where it came.**
   - The island grows out of the notch (top centre) and returns into it.
   - Popovers grow from their trigger; modals from the centre.
   - Enter and exit by the same path.
7. **Interruptible, always.** Never lock out input during a transition. SwiftUI animates from the on-screen value, so a re-target never jumps. Hover in and out, open and close, and expand and collapse must all be re-aimable mid-flight.
8. **Gestures track 1:1, then spring.** A drag follows the pointer exactly (no animation while dragging). On release it springs to its target, carrying the release velocity, with momentum projected to where it's going. Edges resist progressively (rubber-banding) rather than stopping hard.
9. **Frequency decides.**
   - Arrow-key steps in a list and other keyboard-repeated moves don't animate, or barely (a 0.12–0.18 s critically damped slide of the selection at most).
   - A hover on something seen dozens of times a day is quick (0.1–0.15 s).
   - The island is the exception the product is built on. Its morph is the feedback that Fovea heard the press, so it animates, but fast.
10. **Press feedback.** Scale to 0.97 on press, back on release, in about 0.12–0.16 s.
11. **Reduce Motion** (the person's Appearance › Motion, or the Mac's setting): no springs that move or scale. Short opacity crossfades (0.12–0.2 s) instead; nothing bounces.

## Fovea's motion palette: a spring where it's right, a curve where that's right

Ryan, Oct 21: "for other places, don't always use the spring animations. Use the correct
animations." Emil Kowalski's standard (review-animations/STANDARDS.md) reserves springs for four
things:

- drag with momentum;
- "alive" elements (the Dynamic Island);
- interruptible gestures;
- decorative pointer-tracking.

Everything else gets the curve that fits what it's doing:

| What it's doing | Animation | Why |
|---|---|---|
| Entering or exiting: a sheet, popover, menu, toast, banner, a row or a page arriving | strong **ease-out** `timingCurve(0.23, 1, 0.32, 1)`; 0.2–0.25 s in, 0.12–0.18 s out | Starts fast, so it feels responsive; exits are shorter (Emil, Radix: enter 200 ms, exit 150 ms) |
| Moving or morphing on screen: cards reflowing, a card opening into its detail, a pane changing size | strong **ease-in-out**: `timingCurve(0.645, 0.045, 0.355, 1)` (cubic) for short moves, `(0.77, 0, 0.175, 1)` (quart) for large ones; 0.25–0.4 s by size | Already on screen, so it accelerates and settles (Emil's Easing Blueprint) |
| A selection sliding: a segmented pill, a tab underline, a list highlight | ease-in-out cubic, 0.2–0.22 s; keyboard steps instant | Short on-screen move; quick re-clicks re-aim from where it is |
| Hover: colour, background, a fill | **ease** `timingCurve(0.25, 0.1, 0.25, 1)`, 0.1–0.15 s; no movement | Hovers happen dozens of times a day (Emil: 300 ms is too slow for a hover) |
| Press feedback | scale 0.97, ease-out 0.12–0.16 s; back the same | Emil: `transform 160ms ease-out` on `:active` |
| Constant or time-bound motion: spinners, progress over time, a draining ring, a countdown | **linear** | Constant speed is the meaning |
| Ambient and rare: the first run's light, the desktop clearing | ease-in-out, 0.6–1 s | Large, rare, explanatory; may be slow (Emil: marketing and explanatory can be longer) |
| The island: growing, shrinking, resizing, its small parts | **spring**, subtle bounce (the Island section below) | Alive, re-triggered constantly, interrupted mid-flight |
| A pulled-out chat let go or tucked into a side | **spring** carrying the release velocity, 0.4 s, bounce ~0.2 | Thrown: momentum |
| A drag in progress | **none**, 1:1 with the pointer | Direct manipulation (Apple) |
| Reduce Motion | opacity only, ease-out 0.15 s | Fewer and gentler, not none |

Other design engineers say the same thing:

- **Rauno Freiberg** (*Invisible Details of Interaction Design*): motion should come from where the interaction happened, and stay out of the way of frequent actions.
- **Josh Comeau** (*Springs and bounces in native CSS*): springs for things with momentum or that get interrupted; curves for simple enter and exit.
- **Apple's HIG** (Motion): brief, precise motion that conveys where something came from, and reduced motion for people who need it.

Nothing scales from 0 (enter from 0.95–0.97). Popovers grow from their trigger. Enter and exit go by the same path.

## How a change is checked

- Each module's smoke run still passes; timing-based checks follow the new values.
- The settle time and overshoot of each spring are computed from its parameters and noted beside it. SwiftUI's `Spring(duration:bounce:)` has `settlingDuration`, and its `value(target:time:)` gives the peak.
- Then Ryan feels it on the real Mac. It's played slowed in the Workbench where a state can be staged, and with Reduce Motion on and off.

## Island (Oct 21, FoveaIsland)

Everything is named in `WorkbenchTokens.Spring`, and the island's older tokens point there. Following the palette above:
- **Springs** for the island's own morphs, its small parts and a thrown chat. These are `.interpolatingSpring`, so a morph re-aimed mid-flight keeps its velocity.
- **Curves** for everything inside its panels.

Reduce Motion turns every spring and moving curve into a 0.12 s strong ease-out with nothing bouncing (`Spring.reduced` asks the model, which reads the person's Motion or the Mac's; `Spring.fade` is the one fade, Oct 21 motion review). The outline still changes size in that time rather than crossfading; the content in it only fades (no 0.97 scale or blur), and a pulled-out chat tucks in or comes out fading only.

### Springs

How the values were set:
- Bounce scales inversely with the size of the change.
- Exits are shorter, and their bounce (0.06–0.08) leaves no visible overshoot.

Each spring's figures come from SwiftUI's own `Spring(duration:bounce:)`: `settlingDuration`, the time to 98% of the way, and the peak of `value(target:time:)` sampled every 0.5 ms. The overshoot is a share of the change, so 4.6% of the bar's 44 pt growth is about 2 pt.

| Spring | Used for | Value | 98% at | Settles | Overshoot |
|---|---|---|---|---|---|
| `barGrow` | rest → a voice bar (fn, fn ⌃) | 0.24 s, bounce 0.3 | 0.119 s | 0.539 s | 4.60% at 0.168 s |
| `barShrink` | a bar → rest | 0.18 s, 0.06 | 0.148 s | 0.318 s | 0.02% |
| `panelGrow` | rest or a bar → a panel: held words, Choose chat, the board on hover, a session | 0.34 s, 0.18 | 0.213 s | 0.639 s | 1.11% at 0.297 s |
| `panelShrink` | a panel → rest | 0.26 s, 0.06 | 0.213 s | 0.443 s | 0.02% |
| `resize` | the island growing within a state: the stack opening, a closer look at one referent, a notice, every chat, the model sheet, the whole session, board ↔ session, Choose chat → board, a queued request joining | 0.30 s, 0.16 | 0.196 s | 0.559 s | 0.77% at 0.277 s |
| `fold` | the island shrinking within a state (the same, back), and a panel → a bar | 0.24 s, 0.06 | 0.197 s | 0.412 s | 0.02% |
| `part` | its small parts: the stack's cards fanning and settling, the +N riding the fan, a session's referents fanning, the last minute's nudge | 0.28 s, 0.25 | 0.152 s | 0.582 s | 2.84% at 0.212 s |
| `partBack` | small parts folding back | 0.22 s, 0.08 | 0.173 s | 0.389 s | 0.06% |
| `flight` | a capture flying from the screen into the stack: a long way, so under a point of overshoot | 0.42 s, 0.10 | 0.315 s | 0.711 s | 0.15% |
| `thrown` | a pulled-out chat let go, or tucked into a side; it starts at the release velocity | 0.40 s, 0.20 | 0.240 s | 0.757 s | 1.52% (more if thrown fast) |
| `reposition` | the end of a gesture that wasn't a throw: a chat's corner (or pinch) let go past its sizes, back within them | `.spring` 0.40 s, 0 | 0.372 s | 0.600 s | 0 |

For comparison, the springs these replace were all critically damped:
- the bar at 0.18 s (98% at 0.168 s) and 0.15 s;
- Dispatch's panels at 0.34 s (98% at 0.316 s) and 0.24 s;
- held words at 0.30 s.

Which morph a state change gets is decided in `WorkbenchModel.setNotchState`, with Dispatch's moves in `WorkbenchTokens.V2.spring(from:to:)`:
- from rest, `barGrow` for a bar and `panelGrow` for a panel;
- home, `barShrink` from a bar and `panelShrink` from a panel;
- a bar becoming a panel grows on `panelGrow`;
- a panel becoming a bar folds;
- anything else resizes.

An in-state resize sets the outline's spring as well (`reshapeV2`), so the outline and its content move together.

Pulled-out chats:
- A drag tracks the pointer 1:1 with no animation. Past the screen's edges it rubber-bands (Apple's 0.55 constant), and the resize corner and the pinch do the same past their sizes.
- Let go, the throw is projected with Apple's formula at a window's deceleration (0.99), so a flick of 1000 pt/s glides about 100 pt. It springs there on `thrown`, starting at the release velocity along its path.
- Thrown or let go at a side, it tucks in: the window fades to 0.96 and the tab slides in from that edge.

### Curves

| Curve | Used for | Value |
|---|---|---|
| strong ease-out in (`fadeIn`) | content appearing: the bar's waveform (0.14 s, 30 ms behind the shape), a panel's content (0.18 s, a beat behind), notices' words, the step line pushing up (0.2 s), Copied and the other in-place state changes (0.16–0.18 s), the drop well (0.14 s), a referent's number and ✕ (0.12–0.15 s), the session's name (0.2 s), the outline and the turn rail appearing (0.14 s) | `timingCurve(0.23, 1, 0.32, 1)` |
| strong ease-out out (`fadeOut`) | content going, shorter than it came: the bar's waveform and a panel's content (0.1 s), a removed card (0.16 s), the others stepping back (0.15 s), the marks (0.18 s over another app's window, 0.3 s over the first run's practice windows) | the same curve |
| strong ease-in-out (`rows`) | moving on screen, not alive or thrown: the board's rows reordering, a task's line or state changing, a scroll to a request | `timingCurve(0.645, 0.045, 0.355, 1)`, 0.28 s |
| `ease` (`hover`, `hoverShape`) | hovers: a fill (0.12 s); a small lean, a card's lift or a tucked tab leaning out (0.15 s) | `timingCurve(0.25, 0.1, 0.25, 1)` |
| ease-out (`press`) | press feedback on the island's controls (icons, pills, chips, Send, Copy and Paste, Undo, ✕): to 0.97 and back, or a 0.75 dim with Reduce Motion | 0.14 s |
| linear | Transcribing's line, the undo line draining, held words' countdown ring, the last minute's count | drawn from the clock (TimelineView), so constant by construction |
| none | keyboard steps (↑↓ in Choose chat, the board's focus and its scroll); the highlight being drawn as the pointer moves (1:1, here and over other apps' windows); a drag in progress | — |

### Needs Ryan's eye

These are tuned from the numbers and the rules; feel can only be judged on the real Mac. Each can be played slowed in the Workbench where the state can be staged.
- **The bar's 0.3 bounce.** It should read as a settle, not a wobble, tens of times a day.
- **Whether the board and a session want more bounce than 0.18.** On the largest panel 1.1% is about 5 pt.
- **The fanned cards against the old capped reference curves.**
- **A thrown chat's glide.** 0.99 deceleration, and whether a fast flick at a side should tuck it.

## First run (Oct 21, FoveaOnboarding)

Every value is named in `OT.Motion` (`FoveaV1/Sources/FoveaOnboarding/OnboardingTokens.swift`), each with its reason. Nothing in the first run is dragged, thrown or alive (the island it drives is the island's), so it has no springs: only curves. The first run is seen once, so it may take a little more time to explain itself, but it never makes anyone wait.

The three curves, and how far through its time each looks done:
- **Strong ease-out**, `timingCurve(0.23, 1, 0.32, 1)`: half-way at 13% of its time, 90% at 36%. For entering and leaving.
- **Strong ease-in-out**, `timingCurve(0.645, 0.045, 0.355, 1)`: half-way at 49%, 90% at 71%. For moving or resizing on screen.
- **`ease`**, `timingCurve(0.25, 0.1, 0.25, 1)`: 90% at 62%. For a hover or a colour.

### What the audit found

- **An ease-in on every page change.** The page before left on `easeIn` 0.45 s, and everything the new step moved rode the same ease-in.
- **Slow to arrive.** A reading page's four parts took 1.35 s to land (0.35 s wait, 0.7 s each, 0.1 s apart). The glass bar took 1.4 s, rising from a whole screen below (`move(edge:)` on a screen-sized frame).
- **Back went the same way as Continue.**
- **Choices, rows, toggles and colours on a 0.6 s ease-in-out**, the most common animation in the first run (32 places).
- **Dots and the ×2 badge grew from nothing.** Files grew from 0.8 and shrank to 0.6.
- **Words crossfaded on top of words**: the bar's title between doing steps, and sign-in's stages.
- **The team chat scaled about the screen's corner**, not its own centre.
- **No press feedback.**
- **Reduce Motion was never read.** The model had the flag; nothing set it.

### What each transition uses now

| Transition | Token | Curve and time | Before |
|---|---|---|---|
| A reading page's parts rising in (title, words, the step's part, the button): 12 pt and a 4 pt blur, from below on Continue, from above on Back | `pageIn` | strong ease-out 0.32 s; the first at 0.12 s, then 50 ms apart. The last lands by 0.59 s and looks done by 0.39 s | 0.7 s each, after 0.35 s, 0.1 s apart: 1.35 s |
| The page before leaving: 12 pt up on Continue, down on Back | `pageOut` | strong ease-out 0.2 s | `easeIn` 0.45 s, always up |
| The glass bar coming up, 24 pt | `barIn` | strong ease-out 0.32 s, after 0.6 s (as the dark lifts) | ease-out 0.7 s after 0.7 s, from a screen below |
| Leaving, when it isn't a page: the bar, Back, Skip, a note, a window closing | `contentOut` | strong ease-out 0.14 s | 0.2–0.6 s |
| Moving or resizing: the bar between steps and as the keyboard joins; a page making room as a section opens (More…, Customize, sign-in's stages, the permission rows, chips, the words to bring); the files column | `morph` | strong ease-in-out 0.3 s | ease-in 0.45 s, ease-in-out 0.6 s, or ease-out 0.2 s |
| Words replacing words: the bar's for a new step, sign-in's next stage, a new instruction. The old go at once; the new fade in 60 ms behind the new size | `content` | strong ease-out 0.2 s | both fading over each other |
| A part arriving in place: the primary language and Customize's sliders 6 pt from above, a chip, a file from 0.92, a sent bubble from below, a dot or the microphone's tick from 0.6 | `partIn` | strong ease-out 0.22 s | ease-in-out 0.6 s; dots from 0 |
| A practice window opening from 0.97 about its own centre; a file's preview from its file | `windowIn` | strong ease-out 0.25 s; it closes on `contentOut` | ease-in-out 0.6 s, fading only |
| A choice: a segment's pill sliding to the one chosen (new), a switch, a swatch, a palette, a language, the Allowed tick (with the symbol's own replace, new) | `select` | strong ease-in-out 0.2 s | ease-in-out 0.6 s, or ease-out 0.2 s; pills didn't slide |
| Press: every button on the board, to 0.97 (new; switches and checkboxes excepted) | `press` | strong ease-out 0.14 s, back the same | none |
| The window under the pointer lighting, in dictation | `hover` | ease 0.12 s | ease-out 0.2 s |
| A colour: the board light or dark, the accent on the line, the line to say brightening | `recolor` | ease 0.25 s | ease-in-out 0.6 s |
| The progress line filling | `progress` | strong ease-out 0.35 s | ease-in-out 0.6 s |
| The microphone's level | `meter` | linear 0.08 s | the same |
| The desktop frosting behind a page | `scrimIn` | ease-in-out 0.6 s | ease-in-out 0.9 s |
| The dark lifting as the doing starts | `stageLift` | ease-in-out 1.6 s (Ryan, Oct 9: "too fast" at less) | the same |
| The screen dimming as Fovea reopens, then clearing | `flashIn`, `flashOut` | strong ease-out 0.25 s; ease-in-out 0.6 s | ease-in-out 0.6 s; 0.9 s |
| The practice files cleared at the end, to 0.92 | `filesClear` | ease-in-out 0.8 s | ease-in-out 0.9 s, to 0.6 |
| The stage going at the end | `end` | ease-in-out 0.6 s | ease-in-out 0.9 s |
| Loops: the breathing dot, a key to press, the tab to click, the caret | `breathe`, `keyPulse`, `dropZone`, `caretBlink` | ease-in-out 1.1, 0.9, 1.0 and 0.55 s | the same; now held still under Reduce Motion, all but the caret |
| Reduce Motion | `reduceMotion` | opacity only, strong ease-out 0.15 s | never on |

How it's built:
- **Back's direction.** The page before reads which way the run went as it leaves. A transition is fixed when its view comes in, and the direction is known only at Back or Continue (`Travel`, `PageLeaving`).
- **Each part keeps its own curve.** Entrances and exits carry their curve on the transition, so a part fades in on the ease-out while the page makes room on the ease-in-out in the same change.
- **Interruptible.** Every change animates from what's on screen, so a second click mid-way re-aims it. Nothing waits for an animation to finish.
- **Reduce Motion** follows Settings › Motion (Match the Mac, Reduce, Full), read at the start and on each page. Nothing travels, grows or slides; things fade; a held button dims to 0.75 instead of giving, on the Reduce Motion fade (the island's and the window's dim, Oct 21 motion review).

### Needs Ryan's eye

- **The dark lifting stays 1.6 s.** That's your Oct 9 call. The palette's range for ambient motion is 0.6–1 s, and the bar now comes up during the lift rather than after it.
- **A page arriving in about 0.6 s** instead of 1.35 s, and whether 12 pt of travel reads as a direction both ways.
- **Words replacing words at once.** The old words go at once and the new ones fade in, where before they crossfaded.
- **The sliding pills** in the primary language and the notch's three choices.
- **Dots from 0.6**, not the palette's 0.95–0.97. At 10 pt, 0.97 wouldn't show.

## Window (Oct 21, FoveaWindow)

Home and Settings. Every value is named in `T.Motion` (`FoveaV1/Sources/FoveaWindow/Tokens.swift`) with its reason, and every view asks for a role (`model.animate(.layout)`, `motion.animation(.press)`), never a number. Nothing in the window is dragged, thrown or alive, so it has no springs: only curves. Home is opened about once a week, so it may be gentle, but it never makes anyone wait, and keyboard steps never animate.

The four curves, and how far through its time each looks done:
- **Strong ease-out**, `timingCurve(0.23, 1, 0.32, 1)`: half-way at 13% of its time, 90% at 36%. For arriving, leaving and press.
- **Strong ease-in-out (cubic)**, `timingCurve(0.645, 0.045, 0.355, 1)`: half-way at 49%, 90% at 71%. For moving or resizing on screen.
- **Ease-in-out quart**, `timingCurve(0.77, 0, 0.175, 1)`: half-way at 48%, 90% at 66%. For the one large move, the card opening.
- **`ease`**, `timingCurve(0.25, 0.1, 0.25, 1)`: 90% at 62%. For a hover's colour, fill or shadow.

### What the audit found

- **Every change rode one of four springs.** Rows, panes, filters, states, tiles and colours all used a 0.22 s spring (`swap`), whether they moved or only faded. Toasts and the card opening used a 0.32 s spring, and the note's blocks did too. There was no curve for anything that only appears.
- **Closing the expanded card was instant** (your Oct 7 call: shrinking back took the window through grey). Opening grew from the card's resting frame while the card stood pressed, a 1.5% pop as the click landed.
- **Hand-typed springs.** These were the search field (0.26 / 0.2 s), the library's hover plate (0.2 s), the eye-tracking picture's gaze (0.32 s, bounce 0.06) and the selection pill (0.12 s).
- **Reduce Motion was missed in places.**
  - Toolbar items don't inherit the window's environment, so the kinds' pill and search never saw Reduce Motion (nor the frame recorder's speed).
  - The Settings sidebar slid its whole width in, even with Reduce Motion on.
  - The selection pill still slid.
- **Press feedback only on cards** (0.985 in 0.08 s). Pill buttons, round buttons, tiles, swatches and the glow palettes had none.
- **A tile's check grew from 0.6.**
- **Hovers on ease-out**, not `ease`.

### What each transition uses now

| Transition | Role | Curve and time | Before |
|---|---|---|---|
| A card opening into its expanded card, from the card as pressed (0.97), its face and the regions you took flying with it | `zoomOpen` | ease-in-out quart 0.4 s; looks done by 0.26 s. The grey arrives on the ease-out over the same time, so the click is answered at once | spring 0.32 s from the resting card |
| The expanded card going home into its card. The grey has gone by 60% of the time and the expanded content too, both on the ease-out from the first frame. The card's face returns from 15% to 85%, so it's never a blank card in flight. A click on it turns it round | `zoomClose` | ease-in-out cubic 0.3 s | instant (Oct 7) |
| Cards reflowing: one deleted, one back with Undo, a notice leaving a card | `layout` | ease-in-out cubic 0.28 s | spring 0.22 s |
| A filter: a kind, an app, a time, a tag. The grid swaps as one layer (old out by 40%, new from 50%); cards don't travel | `fadeIn` | ease-out 0.2 s | spring 0.22 s |
| The kinds' pill, the years' pill, Settings' tabs, any segmented pill sliding. What it chooses follows at 0.15 s (nine tenths of the way) | `select` | ease-in-out cubic 0.22 s | spring 0.12 s; the choice at 0.12 s |
| Search opening out of its icon, and folding back. Its words wait 0.15 s, and leave in 0.05 s | `searchOpen`, `searchClose` | ease-in-out cubic 0.25 s; 0.2 s | springs 0.26 s, 0.2 s |
| A toast rising 8 pt out of a 2 pt blur, and sinking away | `toastIn`, `toastOut` | ease-out 0.22 s; 0.15 s | springs 0.32 s, 0.26 s |
| Home and Settings trading places (10 pt of drift as it fades); the Settings sidebar 10 pt from the leading edge | `page` | ease-out 0.24 s | spring 0.24 s; the sidebar slid its width |
| A Settings pane, a Dictionary tab, the calendar's year or month, a note in the library, the window's states (restoring, couldn't load, errors), a new primary language | `fadeIn` | ease-out 0.2 s | spring 0.22 s |
| Rows making room: a toggle revealing rows, Customize's sliders, the recorder's note, a clash, a word, a chip, a language, the eye-tracking steps, sign-in's stages, the price digits rolling | `layout` | ease-in-out cubic 0.28 s | spring 0.22 s |
| The row, note or line itself arriving and leaving (`AnyTransition.arrive`) | `fadeIn`, `fadeOut` | ease-out 0.2 s in, 0.14 s out | faded on the spring |
| A choice that only changes colour: a tile's ring, a glow palette, an accent, Appearance's Motion | `fadeIn` | ease-out 0.2 s; a tile's check from 0.8 | spring 0.22 s; the check from 0.6 |
| A note's blocks rising 6 pt, 55 ms apart | `layout` | ease-in-out cubic 0.28 s | spring 0.32 s |
| Press: cards, pill buttons, round buttons, tiles, swatches, the glow palettes, to 0.97 | `press` | ease-out 0.14 s, back the same | cards only, 0.985 in 0.08 s |
| Hover: a card's shadow, a pill's or a row's fill, the library's hover plate | `hover` | ease 0.12 s; nothing moves but the library's plate | ease-out 0.12 s; the plate on a 0.2 s spring |
| The eye-tracking picture: the gaze moving to the next window; "this" in and out | `gazeHop`, `fadeIn`, `fadeOut` | ease-in-out cubic 0.25 s; ease-out 0.2 s, 0.14 s | spring 0.32 s, bounce 0.06; 0.1 s, 0.08 s |
| A calibration dot filling | (`calibrationHold`) | linear 0.9 s | the same |
| Keyboard: arrows through the cards, ← → in the expanded card, ↑ ↓ in the library's list, held keys in the recorder | none | instant | the same |
| Sheets, the avatar's popover (from the avatar, after 0.4 s under the pointer), menus, the system's switches, segmented controls and the Settings sidebar | the Mac's own | — | the same |
| Reduce Motion (Settings › Appearance › Motion, or the Mac's) | every role | opacity only, ease-out 0.15 s. The pill fades in place, search is open at once, the card fades where it is, nothing drifts or rises; a press dims to 0.75 instead of settling (the island's and the first run's dim, Oct 21 motion review) | partly |

How it's built:
- **One role per kind of change.** `MotionSpec.Role` names them, and `T.Motion` holds each curve and time. The frame recorder's speed and Reduce Motion apply to all of them, toolbar items now included (`WindowMotion`).
- **Each part keeps its own curve.** A row's fade is carried on its transition (`AnyTransition.arrive`), so it comes in on the ease-out while the rows around it make room on the ease-in-out in the same change.
- **The card and its expanded card** run on one value, `detailProgress`. The frame follows the ease-in-out. The grey, and on the way home the content and the card's face, are timed against the zoom's own time on the ease-out (`Curve.timeGone`), so they answer the click while the large frame starts slowly. `closeDetail(animated: false)` still takes it away at once, before something changes the page under it.
- **Interruptible.** Every change animates from what's on screen, and nothing waits for an animation to finish. Esc while it opens sends it home from where it is, and a click on its way home turns it round.

### Needs Ryan's eye

- **The way home is back.** Your Oct 7 call made closing instant because it went through grey. Now the grey has gone in the first 60% of 0.3 s, and the card's face comes back as it lands. If it still reads grey, `closeDetail` goes back to instant in one line.
- **The quart's slow start.** The card's frame has moved 3% after 80 ms. The grey and the press answer the click at once to cover it. If it still feels late, cubic (5% at 80 ms) or a strong ease-out are the alternatives.
- **Filters crossfade; cards don't travel.** Emil: data you're reading shouldn't move for style. Cards travel only when one is deleted or comes back. Say if you want the cards to slide into their new places on a filter.
- **A card's press at 0.97** (it was 0.985): about 3 pt on each side of a 220 pt card.
- **The pill at 0.22 s** (it was 0.12 s). The choice still follows at 0.15 s, about as quickly as before.

### Oct 21, later: the board opens faster on hover

Ryan: "I need the Dynamic Island to expand faster when my mouse hovers above it." Two changes:

- **The wait is about half.** The board now opens 0.06–0.16 s after a deliberate aim, instead of 0.12–0.3 s. It still waits for the pointer to rest, so a sweep along the menu bar never opens it. Settings › Notch's hover wait is halved too: Quick 0.03–0.1 s, Normal 0.06–0.16 s, Relaxed 0.18–0.36 s.
- **The board opens from rest on its own spring.** `Spring.boardOpen` is `.interpolatingSpring(duration: 0.26, bounce: 0.16)`: 98% at 0.170 s, 0.8% overshoot, settled at 0.491 s. Before, it used `panelGrow` (0.213 s / 1.1%). The other panels keep `panelGrow`.

From pointer to board, a deliberate aim now takes about 0.23–0.33 s, down from about 0.33–0.51 s.

## Oct 21, last: less

Ryan: "act like a picky user who has the vision of a design engineer. Delete all the animations and effects that seem too much, and also debug any potential problems. Simpler is better (don't have too many ornaments)."

The rules this pass held everything to:
- **One effect per change.** A thing appears by fading, or moves by changing its frame, not both with a blur and a scale on top.
- **Nothing that's pressed many times a day moves for style.** That covers keyboard steps, filters, switching panes, and Home ↔ Settings.
- **No loop that isn't live.** A loop runs only while something is really happening (the voice, a run, a countdown, the caret).
- **No ornament that repeats what's already said.**
- **Feedback stays.** Copy, Save and Delete still turn into a checkmark while they happen (Ryan, Oct 21).

### Window
- **Opening a card** is the card's frame growing from its place, plus the grey. Its face and content cross-fade, with nothing else. It takes 0.3 s to open and 0.25 s to close. Cut: the blurs, the 0.985 scale, the pictures flying on their own, the start from the pressed card, the growing double shadow and the dark rim. A short card hugs its words.
- **Instant** (no drift, no blink between old and new):
  - Home ↔ Settings;
  - a kind (⌘1–4 too), a tag, search, a year;
  - a Settings pane (arrow keys too).
- **Gone:**
  - every symbol bounce on hover;
  - the 0.97 press on cards, pills, icon buttons and swatches;
  - a card's shadow lifting on hover;
  - the toast's rise and blur (it fades in 0.2 s and out in 0.15 s);
  - the icon swap's blur and scale (the checkmark is there at once);
  - rolling digits;
  - the empty state's dot grid.
- **Faked, so gone:** the microphone meter beside Microphone (not live), and the eye-tracking picture's endless gaze loop (a still picture now).
- **Ornaments:**
  - Settings panes lose the 56 pt icon tile and the title box (the toolbar and the sidebar already name the pane); the pane's summary stays as one line.
  - Plan says "Your plan" once.
  - Keycaps are flat.
  - A chip keeps room for its ✕, so it doesn't widen on hover.
  - Surfaces have one hairline and one soft shadow.
  - The primary button is a flat accent.
- **Kept:**
  - the segment pill sliding (0.2 s; the choice applies at once);
  - cards reflowing when one is deleted or comes back;
  - search widening (0.2 s; ⌘F opens it at once);
  - the popover's wait, the calibration fill, Reduce Motion.

### First run
- **The typewriter is gone.** Instructions and hints appear whole, and a hint stays 1.4 s plus 0.05 s a letter, at most 6 s.
- **A reading page fades in as one** (0.25 s) and the one before fades out (0.15 s). Cut: the parts rising one by one out of a blur.
- **The glass bar fades in at once** (0.2 s), with no 0.6 s wait and no rise. It has one fill, at 92%.
- **Still, not breathing:** the key to press (an accent wash and ring), and the tab to click next. The glow under a held key is gone.
- **Fades only:** practice windows, the file preview, desktop files, and a sent message or picture. Cut: their scale-ins and rises.
- **Ornaments:** Memory's four points and the closing page lose their icon circles. The Clear my screen card keeps its button as its one accent.
- **Timings:**
  - The frost comes in at 0.3 s.
  - The files clear and the stage goes at 0.3 s.
  - The dark still lifts in 1.6 s (Ryan, Oct 9).

### Island
- **Springs:**
  - The voice bar keeps a little life (bounce 0.12, was 0.3).
  - A thrown chat bounces 0.1.
  - Every other island spring settles without bounce: the board on hover, panels, resizes, small parts and the capture's flight.
- **Fades only:** a band's content fades as the island changes, with no 4 pt blur or 0.97 scale and no "beat behind" delay. The stack's cards move together, with no stagger.
- **Gone:**
  - the step line looping made-up steps every 0.9 s (a running session's step advances and stays on the last);
  - the creature with eyes beside answers;
  - the 1.6 s grey "naming" before a title;
  - the stack's tilt and hover fan, and Choose chat's tilted pile;
  - hover scales on referents;
  - the ✕ popping in;
  - the last minute's 6 pt nudge;
  - the run clock's rolling digits;
  - the header buttons' bounce;
  - the "Thinking…" and "Transcribing…" dots cycling (the line under them shows the progress).
- **Honest:**
  - The waveform is flat in silence.
  - The Dispatch glow follows the voice only. Its RGB ridge, halo and warp are gone, it doesn't breathe at rest, and its colours drift only as Customize asks.
- **Lighter:** the pulled-out chat has one edge and a 12 pt shadow, the tucked tab no longer widens on hover, and the rail cards carry less shadow.
- **Words:** "Worked for 2m 41s", as the board writes "10m" (it was "2 m 41 s").

### Bugs found by using it
- **Settings showed Home's toolbar.** When the page change was made with animation switched off, the toolbar never took it, so Home's filter and search stayed over Settings. It's a plain change now.
- **Every practice card said "23 requests".** Every first run's practice went to one chat name, and Home counted by name. First-run captures now count on their own.
- **A card said its words twice.** Its theme is the first words ("OK" over "OK."). Such a card now has no title line: the type and time head it, and the words follow once.
- **The expanded card's buttons took no clicks.** A gesture mask switched them all off; they answer now, each with its checkmark.

### Needs Ryan's eye
- **The Dispatch glow.** It's simpler but still there, since your palettes and Customize choose it. Say if it should go altogether.
- **The ambient sound in the first run.** It plays through the whole run and has a mute. Untouched.
- **The bar's 0.12 bounce.** It's the one bounce left on something used tens of times a day.

