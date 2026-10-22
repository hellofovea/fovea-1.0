# "Thinking…", the transcribing line, and the undo line

A research note for the Notch Workbench (2026-09-27). Decided: **a line for both** the
transcribing progress and the undo countdown, and while transcribing the bar shows only
**"Thinking…"**, never the transcript.

**Chosen (2026-09-27): Ellipsis, Fill, Drain, 4 pt.** "Thinking" with SF Symbols' ellipsis
lighting its dots in turn, over a 4 pt line filling leading to trailing; the undo window a 4 pt
line draining toward the start over 2 s (chosen 2026-09-27), held while the pointer is on the bar. In the product the
fill should follow the recognizer's real progress (Apple: prefer determinate), sweeping on the
same line only until that is known. The other variations have been removed from the workbench;
the tables below stay as the record of what was compared and why. The workbench draws variations of each to test; nothing
here changes the product. Sources were read on 2026-09-27 and are linked where used.

## The states

- **Transcribing.** fn's second press, as in the product. The bar keeps the Listening size
  (PRD §10) and shows "Thinking…" over the line; the transcript is kept, never shown. Then the
  bar closes (the product opens the review; the workbench has none yet).
- **Cancelled.** Esc on the bar (Voice flow or Transcribing) cancels the request: "Cancelled"
  and **Undo** for 2 s over the undo line.
  - While capturing (Add screenshot), Esc first ends capture mode only, as Esc ends ⌘⇧4's. The bar
    and the captures stay, and a drag under way captures nothing. A second Esc cancels (decided
    2026-09-28).
  - Undo or ⌘Z brings back what was cancelled, captures included. A cancel made while capturing
    (the panel's Cancelled) comes back to capture mode.
  - Resting the pointer on the bar holds the clock.
  - The panel's **Esc** does what the key does.
- **No speech detected.** The transcription found nothing: "Thinking…" briefly, then one line,
  "No speech detected" (Apple's own wording for the empty recognition), in SF Pro centered in
  the bar for 2 s, then the bar rests (amendment §10's two seconds). Esc dismisses it at once;
  fn starts a new listening session. The workbench has no microphone, so a session shorter than
  half a second stands for "nothing said": fn pressed twice quickly. The product's Retry and
  draining line are not drawn here.

## What the research says

| Source | Finding | Here |
|---|---|---|
| Apple HIG, [Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators) | Prefer determinate; start indeterminate and switch once the length is known; don't switch between circle and bar; keep it moving evenly. | Fill driven by real progress, Sweep or Relay until it is known, all on one line. |
| Apple, [Writing Tools](https://developer.apple.com/videos/play/wwdc2024/10168/) ([`TextAnimation`](https://developer.apple.com/documentation/appkit/nswritingtoolscoordinator/textanimation)); Mac [Dictation](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac) | Apple animates the text being worked on (a glow flowing through it) and pulses Dictation's cursor. No timing is published. | Apple animates the words themselves; Letter wave and Band do that without a gradient. |
| Apple HIG, [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols) | Variable color (layer by layer, macOS 14) and Pulse are for ongoing activity; Breathe (macOS 15) for things like recording. | **Ellipsis**: `ellipsis` with `.variableColor.iterative.dimInactiveLayers`, Apple's own "working". |
| Apple HIG, [Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai) | Prefer specific status over a vague "Processing…". | A reason to reconsider the word later ("Transcribing…", "Writing it down…"); "Thinking…" is the chosen copy. |
| OpenAI Apps SDK [`ShimmerText`](https://github.com/openai/apps-sdk-ui/blob/main/src/components/ShimmerText/ShimmerText.module.css); Vercel [AI Elements Reasoning](https://github.com/vercel/ai-elements/blob/main/packages/elements/src/reasoning.tsx) | A shimmer on "Thinking": OpenAI a 3 s cycle, sweeping in 70 % of it, then resting, the band half the word; Vercel a 1 s shimmer. | **Band** and **Shimmer** on OpenAI's timing. |
| motion-primitives [`TextShimmer`](https://github.com/ibelick/motion-primitives/blob/main/components/core/text-shimmer.tsx) / [`TextShimmerWave`](https://github.com/ibelick/motion-primitives/blob/main/components/core/text-shimmer-wave.tsx), Magic UI, prompt-kit, transitions.dev | Nearly every web shimmer is a moving `linear-gradient` clipped to the glyphs; the one alternative is a per-letter wave (1 s per letter, staggered). | Shimmer breaks PRD §6 (no gradients). Letter wave and Band give the same feeling with solid whites. |
| [Jim Nielsen, "The AI aesthetic"](https://blog.jim-nielsen.com/2026/ai-aesthetic/) | Shimmering text has become a tell of AI products. | Another reason to prefer the quieter treatments. |
| Vercel [Geist loading dots](https://vercel.com/geist/loading-dots) | Three dots blinking: 1.4 s, 0.2 s apart, opacity 0.2 → 1 at 20 % → 0.2. | **Blink**. |
| Material 3 [linear progress](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/ProgressIndicator.kt), [wavy](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/WavyProgressIndicator.kt) | Indeterminate: two segments over 1.75 s (heads and tails staggered, easing 0.3, 0, 0.8, 0.15). A 4 dp gap before the track and a 4 dp stop dot. Wavy: 3 dp amplitude, 20–40 dp wavelength, one wavelength a second, flat below 10 % and above 95 %. | **Relay**, **Gap and stop**, **Wave** (amplitude halved to 1.5 pt for a 44 pt bar), **Deadline**. |
| [Sonner](https://github.com/emilkowalski/sonner/blob/main/src/index.tsx), react-toastify, Gmail, Apple Mail | Undo toasts: 4–5 s, paused on hover; Gmail 5 s, Apple Mail 10 s by default. | 2 s (chosen, shorter than the norm since a voice request is quick to redo), held while the pointer is on the bar. |
| WCAG 2.2 [2.3.3](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html), [2.2.2](https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html); Apple HIG [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | Opacity changes are not "motion"; a moving band arguably is. Moving content over 5 s needs a way to stop it. Under Reduce Motion, cut repeating animation. | Transcribing lasts a few seconds. Under Reduce Motion every label is still and the indeterminate lines hold still. |

## The variations (compared, now removed)

White on the island's black, no gradients except the one labelled Shimmer; the line's fill and
track are the shipping Island's (white 85 % on white 14 %). **Line weight** compared both lines
between 2 pt (the shipping value), 3 pt and 4 pt (Material's; WWDC23 asks for "thicker shapes").

**"Thinking…"**

| Variation | What it does | Timing |
|---|---|---|
| Still | Nothing moves | — |
| Ellipsis | "Thinking" and SF Symbols' `ellipsis`, its dots lighting in turn | Apple's variable color, repeating |
| Blink | "Thinking" and three dots blinking in turn | 1.4 s, 0.2 s apart (Geist) |
| Breathe | The word fades between 45 % and 95 % white | 1.8 s |
| Letter wave | A crest of brightness crosses the letters, each letter one solid white | 1.6 s, then 0.4 s rest |
| Band | A hard-edged band of full white crosses the word, masked, no gradient | 3 s: sweep 70 %, rest (OpenAI) |
| Shimmer | The same sweep as a soft gradient highlight: the AI products' look, breaking PRD §6 | 3 s (OpenAI) |

**Transcribing line**

| Variation | What it does | Shows how far |
|---|---|---|
| Fill | Fills leading to trailing | yes |
| Sweep | A third of the line glides across, 1.4 s a pass (the shipping bar) | no |
| Relay | Two segments chase on Material's 1.75 s rhythm | no |
| From center | Grows from the middle out, symmetric with the notch | yes |
| Gap and stop | A gap before the track and a dot where it ends (Material) | yes |
| Wave | The filled part waves like the voice did, one wavelength a second, flat at the start and end | yes |

**Undo line**

| Variation | What it does |
|---|---|
| Drain | Shortens toward the start |
| Deadline | Drains toward a dot that marks the end of the window |
| To center | Closes in on the middle |
| Steps | Five segments, one a second, the current one draining |
| Under Undo | A short line under the pill only, tying the time to the action |

## Recommendation (before the choice)

- **"Thinking…": Ellipsis**, Apple's own SF Symbols effect for ongoing activity, native to the
  Mac and calm. **Letter wave** if it should feel more alive: the words themselves move, as
  Apple's Writing Tools do, with solid whites and only opacity changing.
- **Transcribing line: Fill**, driven by the recognizer's real progress, with **Sweep** until
  that is known: Apple's rules, on the shipping geometry. **Wave** is the one with character:
  the voice's own shape carrying on, flattening as it finishes.
- **Undo line: Drain**, 5 s, held on hover: the familiar toast countdown. **Deadline** makes the
  end explicit, if a line that just shortens reads too softly.
- **Weight: 3 pt** is worth a look: 2 pt is the product today and reads thin on the Mac.

## Seeing it

Transcribing, Cancelled and No speech detected are in the panel's Notch list (and reached with
fn, Esc, Undo and ⌘Z; a quick double fn gives No speech detected). `--snapshot shots` renders
`workbench-transcribing`, `workbench-cancelled` and `workbench-no-speech`.

## Oct 21 (Ryan: "simpler is better")

"Thinking…" and Dispatch's "Transcribing…" hold still: the ellipsis no longer lights its dots in turn. The line under the words already shows the progress, so one moving thing is enough. The countdown ring, the fill and the drain are unchanged.
