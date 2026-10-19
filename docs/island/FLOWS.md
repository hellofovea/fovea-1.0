# The workbench's two flows: Voiceflow and Dispatch Version 2

For a coding agent changing either flow in the Notch Workbench (`Prototypes/FoveaWorkbench`).
- Run: `cd Prototypes && swift run FoveaWorkbench`.
- Build only this target: `swift build --product FoveaWorkbench`.
- Check: `--smoke`. Pixel checks read the window, so the screen must be unlocked.
- Shots: `--snapshot shots [--only v2]`.

**Two designs.** Every state is drawn in Original or Native (`model.design`,
`docs/island/NATIVE.md`).
- **One set of views.** A change to a flow shows in both. Colors come from tokens that follow the
  design (`WorkbenchTokens.skin`, `ink`).
- **A new panel** (anything that drops below the island) needs:
  - its top padding to include `Native.panelGap` (8 pt when Native's panels float, else 0);
  - `.panelScheme()` on its content;
  - a case in `notchSurface`.
- **Native's island is glass,** so anything drawn on it reads `ink` or the display's scheme, never
  a fixed white.

## The model in one paragraph

`WorkbenchModel.notchState` (a `NotchState`) is the island. Assigning it runs
`setNotchState`, which:
- picks the spring;
- stops the leaving state's timers;
- opens or closes the microphone;
- ends capture mode off a voice bar.

Each state has a `flow`, `.voiceflow` or `.dispatchV2`.

Referents (`referents`; the visible ones are `liveReferents`):
- are taken only on a voice bar (`NotchState.collects`: `.voiceFlow`, `.v2Voice`);
- survive into Dispatch Version 2's Transcribing and Choose chat (`keepsReferents`).

The panel's radios stage any state (`voiceflowSelection`, `v2Selection`), and the flow runs live
from there. The **Feedback · Oct 6** tabs at the top stage the dev team's points and their
variations (`Feedback/*.swift`, `stageFeedback`; docs/island/FEEDBACK_2026-10-06.md).

## Keys

All are wired in `WorkbenchModel.init`; the monitors are in `KeyMonitors.swift`.

**Oct 15 (the dev team's review, ST-03.1):** Voiceflow, Dispatch, the region and the highlighter
can be recorded in Settings › Shortcuts. The keys below are their defaults; the live island answers
to `FoveaKeys.chord(id, prefs)` through `ShortcutMonitor` (modifiers alone, or modifiers with a key
such as ⌥ Space through `KeyboardTap.shortcutHandler`), and a cleared shortcut does nothing. Each
press opens the island on the display with the pointer and it stays there until the session rests
(IS05).

**Oct 17 (Ryan), Fovea 1.0:** ⌥ (either side) takes the screen instead of ⌘, which Codex uses: once
for a region, held while held, twice for the whole screen; ⌥ used with another key is never a press,
and ⌘ does nothing special. There is no highlighter key: while Fovea listens, words selected in any
app (a drag, a double or triple click) and a file clicked in Finder or on the desktop are taken by
themselves (`startSelectionWatch` → `autoTake`), the press reaching the app as always; in Voiceflow a
selection inside the field the words paste into stays there. A dictation pastes the words, then what
was taken, in order (`pastePieces`). The Workbench's mock keeps ⌘ and left ⌥ below.

**Oct 17, round 2 (Ryan):** ⌥ is one press only: twice is the Claude app's shortcut, so a second
press only turns capture off, never takes the whole screen. Files are dragged onto the notch (a drop
target over the island while a file drag is under way, `FileDropView`, "Drop to take it"; on Choose
chat too), never taken by a click; taken words keep an accent highlight over their lines until the
session ends or the referent leaves the stack.

**Oct 19 (Ryan):** ⌘ (either side) takes the screen again, as before Oct 17: once a region, held while held (a region per drag), twice the whole screen of the pointer's display (capture off, nothing else taken); ⌘ with a key (⌘C, ⌘V) or another modifier is never a press, and ⌥ does nothing. The region stays recordable; ⌘ twice stays fixed.

| Key | Where | Does | Code |
|---|---|---|---|
| fn | at rest, or on Voiceflow | Voiceflow: start, then transcribe | `toggleVoiceFlow` |
| fn⌃ | anywhere | Dispatch Version 2: start; on its voice bar, end (Transcribing, then Choose chat); on Choose chat, send | `v2FunctionKey` |
| fn | on Dispatch Version 2's expanded chat or board, focused on one of your sessions | ask more in that session | `v2FunctionKey` → `startV2Voice(continuing:)` |
| ⌘ (either side), press | on either voice bar | capture mode on for one region (a drag takes it and capture ends); another press, off | `regionDown` / `regionUp(click:)`, `finishSelection` |
| ⌘, held | on either voice bar | capture mode while held, a region per drag; with a key (⌘C), off at once | `regionDown` / `regionUp(click:)`, `regionInterrupted` |
| ⌘, pressed twice (fixed) | on either voice bar | the whole screen of the pointer's display as a referent | `captureWholeScreen` |
| No key (Fovea 1.0, Oct 17); left Option in the Workbench | on either voice bar | words selected and a file clicked are taken (1.0); the Workbench's highlighter: a drag marks words, a click a paragraph or a file | `autoTake`; Workbench: `optionDown` / `optionUp(click:)`, `highlightDrag`, `finishHighlight` |
| Left ⌃ alone | Choose chat | every chat, and folded again | `toggleV2Browse` |
| ↑↓ / Return | Choose chat; board | step the pill / send; move focus / open | `v2Key` |
| Esc | anywhere | steps out one level | `escape()` |
| ⌘Z | Cancelled | undo | `undoCancel()` |

The Option and ⌃ keys are the **left** ones only, told apart by their device flags; ⌘ is either.
A press of the key is under 0.3 s with nothing pressed or clicked during it; two presses are two
within 0.35 s (`WorkbenchTokens.Capture`).

## Voiceflow (fn)

The main path:
1. **Silent**, then fn: **Voice flow**, the waveform bar.
2. **Capture:** press ⌘ to turn capture mode on, for one region. Holding it instead keeps capture
   mode on only while held.
   - A drag takes a region, and capture mode ends: `finishSelection` → `capture(rect)`.
   - **The highlighter (left Option):** the pointer becomes a marker in the accent color (`accent`,
     `HighlighterCursor`).
     - A drag across the article's words marks them line by line (`highlightRuns`).
     - A click marks a paragraph or a desktop file (`finishHighlight` → `markText` / `markFile`).
     - The marks stay drawn (`highlights`, `HighlightMarks`) until the session ends.
     - What was marked joins the stack as a card (`AttachmentCards`).
   - A double click of left Option takes the whole screen, with Fovea's own surfaces hidden
     while it is taken (`takeWholeScreen`, `hidingOwnSurfaces`).
   - Every referent goes through `add(image:from:animated:kind:)` into the stack.
3. **fn again: Transcribing.** "Thinking" sits over a filling line for 2.4 s while the words
   arrive (`startTranscribing`).
4. **Paste:** the words land in the notes tab's comment box, or in Split View in the app under
   the pointer (`deliverTranscript` → `landTranscript`). The field lights up as they land
   (`LandingText`), and the bar rests 0.45 s later.
   - In the last minute of ten, the bar counts down at its right (`RecordingCountdown`,
     `startRecordingClock`); at the limit it transcribes by itself.
   - Errors show in place of the bar (`.voiceError`, `VoiceErrorContent`), or inside it while
     it listens (`barNotice`).

**Esc** on the bar or on Transcribing gives **Cancelled** (`cancel()`). Undo is open for 2 s,
by the pill or ⌘Z, and the pointer on the bar holds that time. While capturing, Esc ends only
capture mode.

Two fallbacks, off the main path:
- **No speech detected.** A session under 0.5 s transcribes briefly, then says so for 2 s and
  rests (`showNoSpeech`).
- **Paste not found.** There is no input box on screen (`inputBoxOnScreen` is false: the
  desktop, or any tab but the notes). The island grows to hold the transcript to copy, with a
  5 s ring, then rests (`WorkbenchModel+Paste.swift`).

## Dispatch Version 2 (fn⌃)

The main path:
1. **Voice input** (`.v2Voice`, `startV2Voice`).
   - The bar is **the aura**: `AgentEdgeLayer` in `MockDesktop/AgentThinking.swift`, drawn by
     `VoiceGlow`.
   - The panel's Voice glow section sets its colors (`glowPalette`, `glowHue`, `glowSpread`,
     `glowDrift`).
   - Capture works as in Voiceflow.
2. **fn⌃ again: Transcribing** (`.v2Transcribing`, `finishV2Voice`). The aura fills the bar's
   edge as a progress bar for 1.4 s (`v2TranscribeProgress`).
3. **Choose chat** (`.v2Send`, `showV2Send`) shows:
   - the request and its referents;
   - the chat in a pill (`v2Pick`, first suggestion by default);
   - the send button;
   - suggestion chips (`chooseV2`);
   - left ⌃ for every chat by agent, then project, then chat (`toggleV2Browse`, `pickV2Browse`).

   **It never sends by itself.** The send button, Return or fn⌃ runs `sendV2Now()`, which logs a
   routing label to `v2Labels`, then `makeV2Session` and `run` (the scripted beats in
   `V2Requests.swift`).
   - Its referents sit as one stack (`V2ReferentPile`). The model and effort pill
     (`V2ModelPill`) opens `V2ModelSheet` under the row.
   - With **Review the words first** off (`v2ReviewBeforeSend`), there is no Choose chat:
     - the voice bar keeps the notch's width, with the chosen chat's agent icon at its right
       (`V2RouteButton`);
     - a click opens `V2RouteSheet` under it: the suggestions, Dispatch's rail of every chat, the
       model and effort;
     - `finishV2Voice` sends at once (`sendWithoutReview`).
4. **Control board** (`.v2Board`, `showBoardAfterSend`) for 3 s, then the island rests.
   - Every session on the Mac (`Feedback/V2Board.swift`, `v2BoardSections`), in sections: Needs
     you (questions, then failures), Done, Running, then Status unavailable (`statusUnknown`).
   - Each row (`V2BoardRow`) is two lines led by the agent's icon (`V2BoardIcon`):
     - the title;
     - `v2BoardLine`: the question, why it failed, the answer's first sentence, or the project;
     - at the right: Allow and Deny, the ring and time, or how long since it finished.
   - `boardStyle` picks the design: `.sections` heads each part with `V2SectionHeader`; `.badges`
     puts the state on the icon's corner and parts the list with hairlines. No focus pane, no counts.
   - An answer back within 8 s pops open as its **expanded chat** (`.v2Chat`, `showV2Chat`).

**The hover.** The data flows `PointerMonitor` → `pointerMoved(toScreen:)` →
`displayPoint(fromScreen:)` → `panelPointer(_:)`.
- It works whichever app is in front.
- Near the notch (`Panel.hoverReach`, 14 pt) after a short dwell: `showAgentPanel`.
- 0.1 s after the pointer leaves the board: it closes, if `hoverHolds`. That covers a hover board
  and a session opened from it.
- A board pinned from the panel stays until Esc.
- It never opens empty.

**Sessions:**
- A click on one opens it (`openV2`).
- Its grab bar pulls it out into a window: `dragOutV2` / `endDragOutV2`, drawn by
  `V2DetachedLayer`.
- A window drags anywhere, and docks to a side and back: `moveDetachedV2`,
  `endMoveDetachedV2`, `undockV2`.
- A window scales from its bottom-right corner or a pinch (`scaleDetachedV2`, 70–160 %).
- A window lists every exchange (`v2Turns`, kept in `v2History` by `askMoreV2`). With
  follow-ups, `V2TurnRail` at its right edge marks the one in view and, hovered, lists the
  questions to jump to.
- A window's box asks more, whenever: done or still at work, the session takes the new
  message at once (`askMoreV2(id, text:, inWindow: true)`). fn asks more by voice the same way.
- Its ✕ closes it; a working session goes back on the board and keeps working (Oct 15 review,
  QA21/QA23: closing never stops; only Stop does): `closeDetachedV2`.

**What a session shows** (Oct 6 feedback, `Feedback/V2Board.swift`, `V2FeedbackViews.swift`):
- **At work:** one line: the ring, Working, the time (`V2WorkingLine`).
- **Done:** the agent's commentary folded (`V2StepsFold`, `v2Commentary`), the answer as Markdown
  (`MarkdownView`), **Open …** buttons (`V2ArtifactsRow`).
- **The bar** (`V2SessionBar`): Open in the agent's app; Answer again (`V2ReanswerMenu`) or Stop.
- **The box to ask more** (`V2FollowUpField`) sits under the bar. A message sent while it works
  waits (`v2Queue`, `V2QueueSection`); **Send now** takes it in at once.
- **Titles:** named from the request a moment after it goes (`nameV2`, `v2Titles`).

**Simulated:** the suggestions, the agents' work, their plans, files and answers. The sample
requests are in `V2Requests.swift`, and their answers in `V2Feedback.swift`.

**The agent's steps** (`Feedback/V2Steps.swift`):
- `V2StepLine` shows `v2LiveStep(task)`, a session's current step from `v2LiveSequence`.
- The sequence comes from `V2Request.liveSteps`, or from `AgentBoard.liveSteps` for the samples.
- `v2LiveTick` moves every step on.

**The board's designs** (`boardStyle`):
- `V2BoardContent` draws Sections and Badges as `V2BoardList`.
- Focus, Wings and Split are `V2FocusBoard`, `V2WingsBoard` and `V2SplitBoard`
  (`Feedback/V2BoardVariants.swift`). All three share `V2SessionCard`.
- Capsules is `V2CapsuleBoard`, drawn over the screen. The island stays the notch, and
  `V2BoardLayout.hoverSize` tells the hover where the capsules are.

**Expanding an answer** (`toggleV2Expanded`, `v2Expanded`): the session's header button, left ⌃,
or a Done row's expand button on the board. `V2ChatLayout` then widens to `V2.readingMaxWidth`
and lets the body grow to the display's foot. Esc steps back first.

## When you change them

- Keep every number, colour and duration in `WorkbenchTokens` (`V2`, `Panel`, `Progress`,
  `Capture`, `VoiceGlow`). Follow the island rules: white at an opacity on black, no gradients,
  no counts or logs, never an empty board.
- An open panel's size follows the Density switch. Write its tokens as `pick(compact, spacious)`
  (`Density.swift`). Compact stays as it was; Spacious follows `SPACIOUS.md`. The voice bar and
  the resting notch have one value in both.
- Add a smoke check for each behaviour change. The sections are in `WorkbenchSmoke.swift`:
  `screenshots` and `pasteNotFound` for Voiceflow; `voiceGlow`, `dispatchV2` and `v2Hover` for
  Version 2.
- The specs:
  - Voiceflow: `VOICE_BAR.md`, `REFERENT_STACK.md`, `PROGRESS.md`, `PASTE_NOT_FOUND.md`.
  - Dispatch Version 2: `DISPATCH_V2.md`, plus AMENDMENTS.md (Dispatch Version 2), which wins.
- Dormant code: the old Dispatch states (Choose chat, the Agent panel) and Quick actions
  (Thinking) are still in the code, because Version 2 builds on their pieces. Nothing in the
  panel or the keys reaches them; don't route to them.
