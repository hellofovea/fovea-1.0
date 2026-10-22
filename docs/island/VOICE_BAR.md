# The voice input bar: size, corners, fit and motion

A research note for the Notch Workbench's Voice flow state (2026-09-25). Sources: the Island
PRD (§5, §6, §9, §10, §14, §15), its amendments (§10, §14, Input), `docs/motion/NOTES.md`, and
the shipping Island (`IslandLayoutSpec`, `IslandShape`, `ListeningView`, `Tokens.Motion`).
The workbench draws these numbers; nothing here changes the product.

## Size

| Number | Value | Why |
|---|---|---|
| Width | the notch's width, plus a 6 pt ear on each side (200 + 12 = 212 pt on the 13-inch display) | Amendment §10: voice states are exactly the notch's width and grow only downward. The ears sit outside the notch. |
| Height | the notch's height plus 44 pt below it (32 + 44 = 76 pt from row 0) | 44 is what Transcribing needs: a 24 pt text row, a 2 pt progress line, 6 pt above, between and below. PRD §10 gives Listening and Transcribing one outer size, so Listening reserves the same 44. |
| Waveform | 9 bars, 4 pt wide, 4 pt apart (68 pt across), 5.3 to 20 pt tall, centered | PRD §9: no more than 8 to 10 short white bars, narrow and centered, restrained amplitude, and the outer bounds never pulse with volume. |
| Rest shape | every bar rests at its shortest (5.3 pt); the voice lifts the middle on a bell curve (spread 0.4 of the half-width), so the middle bar reaches 20 pt while the edge bars stay within about 1 pt of their rest | The edges holding still frames the motion and keeps the bar reading as narrow and restrained (PRD §9); an earlier valley shape, tall at the edges, read as always at full length. |
| Nothing else | no icon, label, close or cancel | PRD §9. |

## Bar thickness

Measured on 2026-09-27, bars found as runs of ink pixels:

| Source | Width : gap | Tallest ÷ width | Shortest ÷ width |
|---|---|---|---|
| The reference image (9 bars, 12 px wide, 12 px apart) | 1 : 1 | 3.42 | 1.33 |
| Apple's `waveform` SF Symbol, regular weight | 1 : 1.10 | a glyph, not comparable | |
| Apple's `waveform` SF Symbol, semibold / bold | 1 : 0.85 / 1 : 0.75 | | |

Both agree on the spacing: a gap about as wide as the bar. With the silent dot kept at the
reference's 1.33 and the peak at 20 pt, the width trades two things against each other:

| Bar width | Silent dot | Peak ÷ width | Middle's travel (peak ÷ dot) | Span of 9 bars |
|---|---|---|---|---|
| 3 pt (before) | 4 pt | 6.7 | 5.0× | 51 pt |
| **4 pt** | 5.3 pt | 5.0 | 3.75× | 68 pt |
| 5 pt | 6.7 pt | 4.0 | 3.0× | 85 pt |
| 6 pt | 8 pt | 3.3 | 2.5× | 102 pt, over half the body |

A thicker bar moves the peak toward the reference's 3.42, but it eats the middle bar's
travel, which is the waveform's only motion now that the edges rest; and past 5 pt the span
stops being narrow (PRD §9). 3 pt read as thin sticks at the peak. 4 pt is the balance: the
peak within reach of the reference, the middle still travelling 3.75×, the span a third of
the body. Whole points keep every bar edge on a pixel of a 2× notched display.

## Corners

| Number | Value | Why |
|---|---|---|
| Top corners | 6 pt concave ears | The shape fuses into the menu bar's edge at the notch's top corners instead of sitting under the notch like a card (PRD §5: compact states connect around the notch; §14: continuous with the top edge). The path follows DynamicNotchKit's notch shape. |
| Bottom corners | 14 pt convex, continuous curvature | The resting island's corners, so the bar grows out of the shape the notch already has, the way a device's software corners match its hardware corners. |
| Sides | straight, the notch's own edges | Amendment §10. |

## Where the notch meets the Mac

The physical notch meets the top edge with square corners: it is a cut in the bezel. The
utilities that draw at the notch round that junction anyway, with a concave fillet on each
side, so the black shape reads as one thing growing out of the edge rather than a rectangle
stuck under it. The two references, read on 2026-09-25:

| | Closed (top, bottom) | Expanded (top, bottom) | Note |
|---|---|---|---|
| DynamicNotchKit (`NotchShape`, `DynamicNotchStyle`) | 6, 14 | 15, 20 | Fovea's `IslandShape` follows this path. Its docs add a rule for nested corners: outer radius = inner radius + padding. |
| boring.notch (`NotchShape`, `ContentView`) | 6, 14 (the defaults) | larger when its "corner radius scaling" is on | Content is inset by the top radius, so nothing sits under the fillet. |
| Fovea (`IslandLayoutSpec`) | 6, 14 | 19, 24 | The same closed numbers; a little rounder when expanded. |

What fits, and what the workbench draws in every state:

- Concave at the top, convex at the bottom. The top corners curve inward, a fillet into the edge; the bottom corners curve outward. Both are quadratic curves, so the curvature is continuous and the shape never looks like a sticker.
- Small at the top, larger at the bottom: 6 and 14 pt when compact. The fillet only has to soften the junction; the bottom corners carry the shape's character. Both grow when the surface expands (19 and 24 pt), since a bigger surface needs bigger corners to keep the same feel.
- The fillet lives outside the notch, in the menu bar. The body between the ears is exactly the notch's width, so the notch's own pixels are never covered and the black continues straight down from its sides; content is inset by the top radius.
- It sits wherever the island hangs from. On the desktop that is the screen's top edge, so the
  fillet fuses into the menu bar. When an app is full screen, the menu bar is gone and the band
  beside the notch is solid black; the island then hangs from the band's bottom edge, so the ears
  move down to it and the bar still meets the black above it with a rounded corner instead of a
  square one (`IslandShape.earY`). A resting island stays inside the band, so its ears ride up with
  it and grow into place as the bar opens.
- It belongs to the resting shape, not to a state. The silent notch already has it, and every later state takes its corners from the same geometry (`NotchGeometry.frames` per density), so a new state cannot leave them out.

## Seamless and native

- The body is exactly the notch's width, so the black continues straight down from the notch's sides. The surface is pure black like the notch, with no shadow, gradient or glow (PRD §6): the desktop provides the separation.
- The ears belong to the shape and animate in the same transaction as its size, so ears, sides and corners move as one (`IslandShape`).
- White bars, SF Pro only, and the accessibility modes: Reduce Motion stops the flutter and turns the spring into a fade (PRD §14, §15).

## Motion when it appears

| Step | Value | Why |
|---|---|---|
| The shape | `.interpolatingSpring(duration: 0.18, bounce: 0)`: a critically damped spring, no bounce, that reads as finished in about 180 ms | PRD §14 asks for restrained springs and the amendment rules out bounce anywhere. The shipping island opens in 0.34 s, but the bar is its smallest growth (44 pt) and answers a key press, and the motion notes have duration scale with the size of the change and want fast, ease-out motion for something used many times a day and triggered by the user; 0.34 s felt slow in use, and so did 0.24; 180 ms is the notes' responsive dropdown, and a 44 pt change is still trackable at that speed. A spring keeps its velocity when interrupted, which press-to-toggle needs. |
| The waveform | a 100 ms crossfade on ease-out-quint (0.23, 1, 0.32, 1): opacity 0 to 1, 4 pt blur to none, scale 0.97 to 1 from the top, starting 20 ms after the shape | The shipping content hand-off (`Tokens.Motion`): the shape leads, the content follows; blur bridges the two states; never scale from 0. |
| Going away | `.interpolatingSpring(duration: 0.15, bounce: 0)`; the waveform fades on that same spring while the outline clips it, so the shrinking shape swallows the bars and both are home together | Exits shorter than entries; nothing lingers after the bars. |
| Which spring | the interpolating one | Measured frame by frame in the workbench: SwiftUI's `.smooth` and `.spring(duration:bounce:)` hand the outline about 85% of a growth on its first frame and then creep for 100 ms, while shrinking normally, so the bar popped open and lingered shut. The interpolating spring, same duration and bounce, moves through the whole range both ways. The outline is an `Animatable` modifier, so it moves through real layout rather than a render-time frame tween, and its content is animated as a plain value rather than an insert/remove transition, which does not keep time with the outline. |
| Reduce Motion | a 120 ms opacity fade, bars still | PRD §14, §15. |
| While listening | the bars follow the level at 40 frames per second with a small flutter; the outline never moves | PRD §9. |

**Oct 21 (Ryan): a subtle bounce.** Ryan asked for springs across the island ("research what spring animation is, then apply it to our Dynamic Island"), refined with Emil Kowalski's skills. The voice bar's shape now opens on `.interpolatingSpring(duration: 0.24, bounce: 0.3)` and closes on `(duration: 0.18, bounce: 0.06)` (`WorkbenchTokens.Spring.barGrow` / `barShrink`). The waveform is a curve, not a spring: it fades in on the strong ease-out curve over 140 ms, 30 ms behind the shape, and out over 100 ms. This departs from the amendment's "no bounce anywhere".

Why the bounce:
- The island is meant to feel alive ("a living organism, with a deliberate elasticity"), and that feel comes from the settle, not the speed.
- The bar is the island's smallest growth (44 pt). A small change needs more bounce for any of it to be seen. The 4.6% overshoot is about 2 pt and peaks 0.17 s in.
- The bounce costs no speed. SwiftUI's own spring model has it at 98% of the way in 0.12 s, sooner than the old critically damped 0.18 s (0.17 s to 98%). A key press still gets an answer at once.
- Going home stays nearly critically damped (0.02% undershoot) and quicker, as exits should be.

It's still an interpolating spring, so press-to-toggle re-aims it mid-flight and keeps the velocity. Reduce Motion is unchanged: a short fade, nothing bouncing. The other states' values, each with its settling time and overshoot, are in docs/motion/SPRINGS.md › Island.

**Oct 21 (Ryan: "simpler is better", later the same day).** Ryan, as a picky user, asked to delete the motion that was too much. The bar keeps a touch of life, a smaller one: `barGrow` is now `(duration: 0.24, bounce: 0.12)`, under a point of overshoot. Every other island spring (`panelGrow`, `boardOpen`, `resize`, `part`, `flight`) has no bounce; a thrown chat keeps 0.1. A band's content now fades in with the shape (no beat behind it) and only fades: the 4 pt blur and the 0.97 scale from the top are gone (`VoiceContentTransition`). Silence is flat: the bars no longer wobble on their own with no voice; the flutter rides on the level only (`VoiceBarView.heights`).

## The key

fn, press-to-toggle (amendment, Input): one press shows the bar, the next hides it. A press is fn down then up with no other key in between; fn held as a modifier for another key (fn+←, fn+F5) is not a press. Fovea swallows the bare press with an event tap so macOS never opens the emoji picker. The workbench listens without a tap, which needs no permission, so while testing set System Settings › Keyboard › "Press 🌐 key to" to Do Nothing if the picker gets in the way.
