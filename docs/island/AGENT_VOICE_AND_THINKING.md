# Voice input for agents, and the agent at work

A research note for the Notch Workbench (2026-09-28). The panel's Notch section has three flows:

- **Voiceflow**: dictation.
- **Dispatch**: speaking a task to an Agent.
- **Quick actions**: a short spoken request an Agent carries out.

Dispatch and Quick actions each get a voice bar. Since 2026-09-29 both are one design,
**libraries.dev/voice copied and fitted to the notch**, with no options. Quick actions also gets
**Thinking**: the agent at work, with one line of what it is doing on the Mac and an orb, in
one of seven forms made for Fovea. Dispatch will get its own form later.

**Exception to the Island's rules, by the user's choice:** the voice glow is the reference's own
full-color, gradient look. (Aura, the other marked exception, was removed on 2026-09-30.)

Everything else is SF Pro and white at the Island's opacities on black. Nothing here changes the
product. Sources were read on 2026-09-28 and 2026-09-29.

## References

**libraries.dev/voice** (voice-glow, Jakub Antalik, MIT;
[source](https://github.com/Jakubantalik/Libraries.dev/tree/main/packages/voice-glow)). Soft
ellipses rise from the bottom edge of their host.
- **Bands:** each ellipse follows a band of the voice. The center takes 80–300 Hz, the next
  pair 0.3–2 kHz, the outer pair 2–6 kHz, so speech ripples outward instead of one blob pumping.
- **Envelope:** attack 325 ms, release 860 ms, noise gate 0.015.
- **At rest:** it breathes at 0.18 over 5.2 s.
- **Processing:** it gathers into one beam that sweeps side to side, 1.1 s per pass (easing
  exponent 2.1).
- **Size:** the `pill` preset (about 150×44) is nearly the notch's band.

**libraries.dev/orbs** (thinking-orbs, Jakub Antalik and Alexandr Brinza, MIT; a SwiftUI port,
ThinkingOrbsKit, lives in the repo).
- **What it is:** nine monochrome dotted spheres. The states are working, searching, solving,
  listening, connecting, composing, breathing, weaving and shaping.
- **How it's drawn:** plain 2D dots on a turning sphere. Depth is shown only by dot size
  (0.6 + 1.7·depth) and grey level. No shaders, blur or gradient.
- **Its status line:** holds each message 2000 ms, then swaps in 150 ms, rising 8 px through a
  2 px blur.
- **Its author's rule:** no orb for waits under 2 s.

**Peers:**

| Reference | What was used | Source |
|---|---|---|
| ElevenLabs UI (Matrix, LiveWaveform, BarVisualizer) | LED dots at 12 fps with brightness tiers; opacity tracking level (0.4 + 0.6·level) | github.com/elevenlabs/ui |
| LiveKit Agents UI (Bar, Grid, Wave) | bars that rest as dots; dots that light fast and fade slowly (comet tails); a single line whose amplitude (0.015 + 0.4·level) and frequency follow the voice | github.com/livekit/components-js |
| Siri's edge glow, recreated | four stacked strokes: widths 1.5 / 0.8 / 0.3 / 0.1×, opacities 0.15 / 0.3 / 0.7 / 0.95, blurs 12 / 8 / 2 / 0 | dev.to/vector4wang |
| Claude computer use | the notification "…using your computer · press Esc to stop" | code.claude.com/docs/en/computer-use |
| Claude for Chrome | a phantom cursor gliding 180 ms on cubic-bezier(0.2, 0, 0, 1) | — |
| ChatGPT agent | narrates each action with its own cursor | — |
| Apple Live Activities | compact leading and trailing halves beside the camera that read as one fact; animations of 2 s at most; one control | developer.apple.com/design/human-interface-guidelines/live-activities |
| Linear's agent guidance | a temporary action line replaced by the next | linear.app/developers/agent-interaction |

**The product's own rules** (PRD, AMENDMENTS, AGENTS.md):
- One line of current activity per task; never steps or logs.
- No provider icon or model name inside Quick Answer.
- No gradients.
- The Agent task words: Working, Needs you, Complete, Failed.

## Voice input: libraries.dev/voice, fitted to the notch (Dispatch and Quick actions)

**Decided 2026-09-29:** no options. Both flows' voice bars are voice-glow as libraries.dev/voice
shows it:
- the dark theme and the colorful palette;
- driven by the site's own demo voice: phrases of 6.6 s with 2.4 s of silence between, so the
  resting breath shows.

It is ported from the package's source (`src/styles.ts`, `src/voiceDriver.ts`, `src/presets.ts`;
MIT, © 2026 Jakub Antalik). The host is the island: the glow rises from its bottom edge and is
clipped to its outline.

**The style is Wide** (chosen 2026-09-30): the package's chat-input tuning, made for a ~350 pt
host, fitted to the notch's 200 pt band at scale 0.57.
- The glow spans the bar.
- The colors flow sideways at 27 pt/s at full voice.
- The ridge runs the full width, rising into the corners (tail 0.59).

The first port used the recording-pill preset (~150×44, the site's poster); the section below
records the variations it was compared against.

**The layers, in the package's order:**

| Layer | What it is | Numbers |
|---|---|---|
| **Inner light** | seven colored lobes centred on the bottom edge, masked to an elliptical ceiling and to within a corner fade of the edges, with a faint white inner shadow | alpha 0.46; opacity 0.47 × presence |
| **Bloom** | the same lobes blurred, taller, masked to a wider ceiling | blur 5.7 pt; alpha 0.9; opacity 0.89 × presence |
| **Stroke** | the lobes painted into a 1 pt ring inside the island's edge, with a white hot core at the centre of the bottom edge | opacity 1.16 × presence |
| **Band** | the bend's contour: an organic bell (exponent 1.75, width 0.87, skew 0.12) drawn as a ridge with a red fringe above, blue below, green between, and a white core, over a wide soft halo; its ends rise toward the corners | fringes split up to 8 pt with the voice |

**The driver:**
- **Level:** shaped by a noise gate (0.015) and soft saturation, then followed with attack
  325 ms and release 860 ms.
- **Bands:** three synthesized from the level, as the package does without a spectrum. The centre
  lobe follows the lows, the others the mids and highs.
- **Breath:** 0.18 over 5.2 s.
- **Growth at full voice:** height 0.5 → 1.7×, width 0.85 → 1.9×. The ceiling humps up by 34 pt
  (the bend).
- **Flow:** the lobes slide sideways while a voice is heard and rest when it stops.
- **Hue drift:** ±24° over 12 s.
- **Color filters:** hue-rotate, then brightness 1.15, then saturate 1.2, the chat input's dark
  tuning, applied per color with CSS's own matrices.
- **Palette:** rose, sky, violet, green, orange, periwinkle, teal, centre lobe first.

**Where the port differs:**
- **Distortion:** the package's SVG displacement map under the band line becomes horizontal
  strips shifted by drifting noise, since SwiftUI has no displacement filter. The displacement
  is up to about 13 pt at full voice.
- **Microphone:** the workbench has none, so the demo voice drives it.
- **Processing:** the package's travelling beam isn't used; that belongs to the state after
  listening.

Earlier options (Glow, Hairline, Dots, Rim, Aura) were compared on 2026-09-28 and removed.

### Variations and color (2026-09-29; Wide chosen 2026-09-30)

The Original alone left the notch feeling empty, so it got variations, each built from the
package's own host tunings. **Wide was chosen; the others were removed**, and the colors stayed.

| Variation | What it is |
|---|---|
| **Original** | the recording pill, as above |
| **Wide** | the chat input's tuning (scale 0.57 for its ~350 pt host). The glow spans the bar, the colors flow sideways at 48 px/s with the voice, and the ridge runs the full width, rising into the corners (tail 0.59). |
| **Aurora** | the phone's tuning (scale 0.5 for its ~400 pt host, reach brought down from 3 to 2): a taller, wider wash that fills the bar, flowing at 60 px/s |
| **With bars** | the Original with seven crisp white voice bars over it (3 pt, 4 apart), following the same voice. It gives the bar a focal point. |
| **With edge** | the Original with the island's sides and bottom lit in the palette, a soft line and a crisp one, breathing with the voice |

**Colors:** the panel's Voice glow section lets you try any palette.
- **Palette:** the package's eight (colorful, mono, ocean, sunset, forest, candy, ice, gold), or
  Custom.
- **Hue:** a spectrum slider, 0–360°. For a palette it turns every layer around the wheel, the
  package's hue base; for Custom it is the hue the colors fan out from.
- **Spread:** Custom's fan of seven hues, from 0° (one color) to 360° (the whole spectrum). The
  band's fringes follow it: the ends of the fan above and below, the centre between. The palettes
  keep the package's own red, green and blue fringes.
- **Hue drift:** the package's ±24° wander, which can be turned off to judge a color.
- **Swatches:** the seven colors as the glow shows them, left to right across the bar.

Changing any of these with the notch at rest opens Dispatch's voice bar, so the change shows.
The choices are remembered.

## Thinking: the agent at work (Quick actions)

**The activity place** is one line of what the agent is doing, never a log.
- **Line:** SF Pro 13.5 medium, white 0.85. The Live Activities guidance asks for medium or
  heavier on the black island.
- **App and action:** the app it's driving (Safari's own icon, grayscale, 0.85) and the action's
  symbol (`macwindow`, `text.viewfinder`, `arrow.down`, `cursorarrow.click.2`, `keyboard`,
  `checkmark`) at 11 pt semibold, white 0.55. The symbol swaps with SF Symbols' replace.
- **Swap:** a new line rises 8 pt out of a 2 pt blur in 150 ms while the old one leaves upward.

**Two layouts** (the panel's Activity control):
- **Under:** a 360 pt bar under the notch with compact corners. One 44 pt band holds the mark,
  the line, the app and the action.
- **Beside:** a Live Activity's compact presentation. The mark sits in the left wing beside the
  notch and the app and action in the right, each wing 60 pt at the notch's height. The line
  sits in a 28 pt band below.

**The orb is the Lasso** (decided 2026-09-30: "for the orb, just have lasso, delete the other
options"). It is one orb, the same in every state, and Fovea's own: Fovea is used by circling
things on screen. `LassoRenderer` in `MockDesktop/AgentThinking.swift`; tokens in
`WorkbenchTokens.Lasso`.
- **Drawing:** a hand-drawn circle in the 24 pt mark, white on the black island. The stroke is
  1.6 pt, round, at white 0.9, with a 2.4 pt white head dot.
- **Shape:** a little uneven and overlapping where it closes.
  - It goes 1.12 turns.
  - The radius (8.6 pt) wavers by its 2nd and 3rd harmonics (5% and 3%). The 2nd drifts
    0.7 rad/s, so no two loops are quite alike.
  - It closes in 6% as it comes round.
- **Motion:** the head traces the loop and a tail three quarters of it long follows and erases.
  A loop takes 1.5 s, and each starts 0.9 rad further round than the last.
- **Holding still:** while the agent waits on the person (Needs you) or is done, and under
  Reduce Motion, it holds its loop at its most whole: the head just round.

**Removed (2026-09-30):**
- thinking-orbs' nine states and the vendored kit;
- the By-action switching and the Orb detail control;
- Aura;
- the other forms made for Fovea, and with them the Orb menu:
  - Iris: dotted iris rings round a pupil that looked toward the agent's pointer;
  - Retina: a cone mosaic with signal ripples;
  - Focus: a cloud of dots hunting, then locking into a ring;
  - Saccade: a point jumping between fixations as eyes read;
  - Orbit: three referent cards carried round a core;
  - Sphere: the first dotted sphere;
- the Lasso's eight variations:
  - Pen: a pressure stroke;
  - Echo: a fainter loop a beat behind;
  - Re-circle: quick overlapping turns;
  - Snap: hand loop to true circle;
  - Spiral: tightening to a pin;
  - Marching ants;
  - Comet: dots lapping a faint loop;
  - Capture: cinching round a referent card.

**The agent's actions** (decided 2026-09-30: more of them, after the computer-use agents'
vocabularies).
- **Sources:** the actions come from the vocabularies of:
  - Anthropic's computer-use tool: screenshot, zoom, the clicks, drag, mouse move, type, key,
    scroll, wait;
  - OpenAI's computer use;
  - Gemini's computer use (navigate, search, go back, key combinations, drag and drop);
  - Browser Use's browser actions (search, navigate, extract, find text, switch tab, upload, done).
- **Wording:** each line is how these products narrate: the verb in -ing and the thing it acts on
  ("Clicking “Journal”"), and the past tense once done ("Posted the comment").
- **Targets:** clicks bracket their target at the corners, after Browser Use's highlight: in over
  150 ms, held 1 s, faded over 300 ms, in the accent color.

| Action | Line | Symbol | On the mock screen |
|---|---|---|---|
| Plan | Planning the next steps | `checklist` | — |
| Think | Thinking | — | — |
| Open app | Opening Safari | `macwindow` | full-screen Safari, the agent's pointer |
| Search the web | Searching "snow on the high valleys" | `magnifyingglass` | a click in the address field, the query typed, ↩ |
| Open a URL | Opening notes.example.com | `globe` | the URL typed, ↩, the notes open |
| Read | Reading the article | `doc.text.magnifyingglass` | the pointer follows the headline and the first lines |
| Find on page | Finding "pass" | `text.magnifyingglass` | ⌘F, a "1 of 3" toast, the match in yellow |
| Scroll | Scrolling to On the pass | `arrow.down` | the article scrolls |
| Click | Clicking "Journal" | `cursorarrow.click` | brackets, a click ring |
| ⌘-click (new tab) | Opening "Journal" in a new tab | `plus.square.on.square` | ⌘ held, the click, a "new tab" toast |
| Double-click | Selecting "Snow" | `cursorarrow.click.2` | two rings, the word selected |
| Triple-click (select) | Selecting the paragraph | `character.cursor.ibeam` | three rings, the paragraph selected |
| Copy | Copying the paragraph | `doc.on.doc` | ⌘C |
| Switch tab | Switching to Design notes | `square.on.square` | a click on the tab |
| Paste | Pasting into the comment | `doc.on.clipboard` | a click in the box, ⌘V, the text in it |
| Type | Typing a comment | `keyboard` | the box fills a character at a time |
| Press a key | Pressing Return | `return` | ↩ |
| Right-click | Opening the photo's menu | `contextualmenu.and.cursorarrow` | a context menu; the pointer walks to Copy Image |
| Download | Saving coast.jpg | `square.and.arrow.down` | the menu's Save Image As…, a download toast |
| Upload | Attaching mockup.png | `paperclip` | a click in the comment box, an "attached" toast |
| Drag | Dragging the photo into place | `hand.draw` | a ghost of the photo carried to another |
| Hover | Pointing at "Larch in the first frost" | `cursorarrow.motionlines` | the pointer rests on the photo |
| Zoom in | Zooming in on the caption | `plus.magnifyingglass` | the caption framed, the rest dimmed |
| Screenshot | Looking at the screen | `camera.viewfinder` | a white flash |
| Wait | Waiting for the page | `hourglass` | — |
| Go back | Going back to the article | `chevron.backward` | ⌘[ |
| Check code | Checking line 7 | `chevron.left.forwardslash.chevron.right` | the line highlighted |
| Run tests | Running the tests | `terminal` | ⌘U, the line, a "12 tests passed" toast |
| Needs you | Allow posting the comment? | `hand.raised` | the line in Needs you's amber, **Allow** in the app's place; the run waits |
| Complete | Posted the comment | `checkmark` | — |
| Failed | Couldn't find "Save" | `exclamationmark.triangle` (Failed's red) | the pointer shakes once |

**The full run** chains a research task, about 2 s per step, then the island rests:
- plan, open Safari, search, read, scroll;
- select and copy a paragraph;
- switch to the notes, paste, type a comment;
- look at the screen;
- ask (Needs you: Allow);
- press Return, posted.

**One action:** the panel's Action menu plays any single action on a loop, from the screen it
needs.

**The pointer** is the agent's own and is only drawn. It is the arrow inverted, white with a dark
edge, so it never passes for the person's. Esc stops the agent at once, and everything it drew
goes with it; fn starts Voiceflow.

## Motion

- The voice bars open on Voiceflow's spring. The glow fades in over the bar's content crossfade,
  and its driver starts from silence each time.
- Thinking opens on a 0.3 s spring and closes on a 0.22 s one, both without bounce.
- Content arrives 0.10 s behind the shape, with the bar's crossfade: opacity, a light blur, and
  a small scale from the top.
- Every drawn style is one Canvas in a timeline that pauses while the bar is hidden.
- Under Reduce Motion, and in snapshots, each style holds one frame.

## Seeing it

- **Panel:** Notch › Dispatch (Silent notch, Voice input) and Notch › Quick actions (Silent
  notch, Voice input, Thinking). Quick actions also has:
  - an Action menu: the full run, or any one of the 31 actions on a loop;
  - an Activity control: Under or Beside.

  Esc, under the three groups, dismisses any of them.
- **Voice glow section:** Palette, Hue, Spread, Hue drift and the swatches.
- **Remembered:** the action, the layout, and the glow's choices.
- **Snapshots:** `--snapshot shots` renders:
  - `workbench-agent-voice` and `workbench-agent-voice-desktop`;
  - `workbench-glow-ocean` and `workbench-glow-custom`;
  - `workbench-lasso`, the Lasso at eight moments across one loop and, set apart, held still,
    enlarged;
  - `workbench-thinking` and `workbench-thinking-beside`;
  - `workbench-action-<action>` for each action, staged mid-way with what it draws.

## Oct 21 (Ryan: "simpler is better")

The aura keeps Ryan's palettes, Custom and the hue drift (still only when Customize asks for it), and it keeps following the voice: the inner light, the bloom and the lit edge. Removed from it: the band (the red, green and blue fringed ridge and its wide halo), the strips warped sideways under it, and the resting breath. Silent, the glow holds still at its idle and the colors stop flowing (the flow follows the level, not the idle). "Transcribing…" over it is still text, as "Thinking…" is (PROGRESS.md).
