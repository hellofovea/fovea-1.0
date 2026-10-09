# Paste not found

A research note for the Notch Workbench (2026-09-28). The transcription finished, but the page
has no input box to paste into. The island keeps the words:

- the transcript's first lines, cut at the tail;
- ✕ at the bottom left, inside a ring that drains over 5 s, after which the island rests;
- the chevron in the middle, and a gray **Copy** with white words at the right.

The chevron opens the island downward to the whole transcript. Sources were read on 2026-09-28.
Nothing here changes the product.

## What others do

- **Wispr Flow.** A failed paste leaves the transcript on the clipboard and shows a notice with a
  copy action. ⌃⌘V pastes the last transcript.
  ([docs](https://docs.wisprflow.ai/articles/7971211038-fix-text-not-pasting-after-dictation))
- **Superwhisper.** With no target, the text stays on the clipboard and in History. It
  auto-closes only after a paste that succeeded.
  ([docs](https://superwhisper.com/docs/common-issues/pasting-issues),
  [changelog](https://superwhisper.com/changelog))
- **VoiceInk.** It never checks focus. After 2 s it restores the old clipboard, so with no field
  the words are simply gone ([source](https://github.com/Beingpax/VoiceInk)).
- **HyperWhisper.** It checks the focused element's accessibility role (text field, text area,
  combo box, search field, or a web area whose value is settable). Its "copied" dialog is undone
  by a clipboard restore 10 s later
  ([bug](https://github.com/ray-amjad/hyperwhisper-app/issues/1034)).
- **Apple Dictation.** The insertion point comes first, and there is no fallback.

The lesson: the words must never be lost. They stay in the island until the person copies or
dismisses them, and nothing restores the clipboard behind them.

## Decisions

**Size.**
- The island is 400 pt wide, ears included, which leaves 330 pt of text. That is about 55
  characters of 13.5 pt SF Pro per line, inside a readable measure.
- The corners are the Island's expanded ones, 19 and 24 pt.
- Closed, the text area is a fixed two lines, so Copy is always in the same place.
- Opened, it shows the whole transcript up to 200 pt (about 11 lines), and scrolls past that.
  Apple's typography guidance: don't truncate inside a scrolling region.

**Truncation.**
- The tail is cut with an ellipsis, SwiftUI's own truncation.
- The chevron shows only when there is more to see. Apple's disclosure control points down when
  the content is hidden and up when it is shown.

**Color.** Every neutral is white at one of macOS's dark label opacities, measured on this Mac
through NSColor.

| Element | White opacity | Why |
|---|---|---|
| Transcript | 0.85 | `labelColor` |
| ✕ glyph and chevron | 0.55 | `secondaryLabelColor` |
| ✕ disc, under the pointer only | 0.12 | the quietest control |
| Copy fill | 0.17 → 0.23 hover → 0.29 pressed | Apple's dark `systemFill` as it lands on black; dark controls lighten when pressed, and the HIG asks for a press state |
| Copy label | 1.0 (white), 12 pt semibold | the Undo pill's face; the Live Activities HIG asks for medium-or-heavier text on the black island |

**The countdown.**
- 5 s, about how long a macOS banner or the screenshot thumbnail stays.
- It is a ring around ✕ (chosen 2026-09-28, replacing a 4 pt line under the controls). The time
  left drains around the control that would end it sooner, which ties the time to the action.
- The ring is 24 pt across and 2 pt thick. That is a download ring's weight around a control this
  size; the lines' 4 pt would crowd the glyph.
- It uses the lines' white 0.85 on a white 0.14 track, with round caps. The time left runs
  clockwise from twelve o'clock, and its end draws back toward twelve as it drains: the undo
  line's drain, bent round.
- Under the pointer, a white 0.12 disc lifts inside the ring.
- With the line gone, the island ends 12 pt under the controls.
- It runs a straight 5 s from the moment the island appears (decided 2026-09-28). Opening the
  transcript doesn't stop it, and the ring keeps draining around ✕ while the transcript is open.
  The pointer on the island doesn't hold it either. Clicking the chevron leaves the pointer there,
  and a hold is what made the time run long.
- Only Copy stops it: the ring holds where it was while "Copied" shows, then the island rests.
- This drops the research's advice (Sonner and the screenshot thumbnail hold under the pointer; a
  surface being read usually waits). WCAG 2.2.1 accepts a fixed limit when the words can be had
  another way. The product should keep the transcript reachable after the island rests, e.g. in
  History or with a "paste last transcript" shortcut.

**Copy.**
- The transcript goes onto the pasteboard.
- The label becomes a checkmark with "Copied" (a crossfade, and the capsule grows to fit).
- After 1 s the island rests. Geist shows its checkmark for 1000 ms, VoiceInk for 1.5 s,
  shadcn for 2 s.

**Motion.** Critically damped springs throughout; WWDC23 "Animate with springs" says to use
bounce 0 when unsure.
- The island opens in 0.30 s from the Thinking bar and closes in 0.22 s.
- Opening the transcript takes 0.32 s, closing it 0.26 s.
- The words arrive 0.10 s behind the shape, on the bar's crossfade: opacity, a light blur and a
  small scale from the top.
- Opening, the text stays top-anchored and is uncovered by the growing island, so no line moves.
  Only the last line's ellipsis dissolves into the rest, over 0.18 s.
- The chevron turns 180° on the island's own spring.
- There is no fade mask (that would be a gradient, which the Island doesn't use).
- Under Reduce Motion, all of this is a 0.12 s crossfade.

## Not done here

- **Copying automatically when the state appears.** Wispr and Superwhisper do this. The design
  keeps it as an explicit Copy, so the clipboard is not overwritten unasked.
- **A "paste last transcript" shortcut** (⌃⌘V in Wispr and Aqua).

## Seeing it

- **Paste not found** is in the panel's Notch list.
- On a page with no input box (the desktop, or any Safari tab but the design notes), fn, speak,
  then fn again ends there.
- The design notes page has a comment box, the one input box on the mock pages: there, the
  transcript is pasted into it and the bar closes.
- Esc closes the opened transcript first, then dismisses.
- `--snapshot shots` renders `workbench-paste-not-found`, `workbench-paste-expanded` and
  `workbench-paste-desktop`.
