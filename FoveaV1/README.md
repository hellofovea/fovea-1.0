# Fovea 1.0

The one app: the first run, the window (Home and Settings) and the notch, on the real desktop and
the real notch. It was built on Oct 9 from three prototypes: Fovea Onboarding, Fovea Captures and
the Notch Workbench (see PROVENANCE.md). The prototypes stay in `../Prototypes` for design work.
The decisions are in [`../docs/v1/V1.md`](../docs/v1/V1.md).

```bash
cd FoveaV1
scripts/bundle.sh            # build/Fovea.app (release); `scripts/bundle.sh debug` is quicker
open build/Fovea.app
swift build                  # just compile
swift test                   # FoveaKit, the store, CapturesCore, OnboardingCore
```

Run it as the app bundle (`build/Fovea.app`). macOS asks for the microphone, speech recognition,
Screen Recording and Accessibility only for a bundled app with its reasons in Info.plist. The
bundle is signed with your Apple Development identity, so the grants survive a rebuild.

## What you'll see

- **The first time,** the first run:
  1. "What should we call you?", then sign up with an email or Google. Hello greets you by name. Clear my screen is offered: it hides the other apps and covers the desktop's icons with Tahoe Day.
  2. Make it yours: the accent, the glow, and the notch's Glass, Panels and Size.
  3. Grant Fovea Access. Each list has an Allow button: macOS adds Fovea to it and System Settings opens there, for you to switch Fovea on. Accessibility is seen live; Screen Recording needs one Quit & Reopen, after which the run picks up where it was.
  4. The microphone, then speech recognition (macOS's own prompts), then "Say this out loud".
  5. Your agents.
  6. Two tasks sent to the Claude Code on this Mac, with the practice agent standing in if it can't answer: the weekly update, from a chat and three tabs, then the packing list.
  7. Dictation into two windows.
  8. Bring your words.
  9. You're all set, with "Open Fovea at login".
  10. Home.
- **Any time in the first run,** "Exit tour" (bottom right) puts it away, keeping the place: Home's "Finish the tour", or Fovea › Resume the Tour, picks it up.
- **After that,** Home ("Hello, Sam") and Settings. Closing the window doesn't quit; the Dock icon
  brings it back.
- **Always,** the notch:
  - **fn: Voiceflow.** Speak, press fn again, and the words go into the field you're typing in. When no field has the text cursor, they wait at the notch to copy (Paste not found).
  - **fn ⌃: Dispatch.** Speak, press again, and Choose chat appears. Return sends, and the Badges board shows the session.
  - **On either voice bar:**
    - ⌘ then a drag takes part of the screen;
    - ⌘ twice takes the whole screen;
    - left ⌥ is the highlighter: drag across words, or click a paragraph or a Finder file.
  - **Esc** steps back, and **⌘Z** undoes a cancel.
  - **Hover** at the notch to open the board.

## What's real and what's simulated

| Real | Simulated |
|---|---|
| The keys, from any app (with Accessibility) | Dispatch's agents: the sessions, their steps and answers are the Workbench's scripts. The words are real and pick the script that fits (`RequestMatcher`). |
| The microphone and on-device speech recognition | Signing in: the email is kept on this Mac; there's no account server yet |
| Pasting into the app in front, and Paste not found | Account, Plan and credits, Memory, Eye Tracking (Settings) |
| Pictures of the screen (ScreenCaptureKit), Fovea's own surfaces left out | |
| The highlighter's words, from Accessibility where the app gives them (a picture otherwise) | |
| The first run's sends to Claude Code (`claude -p`, in a practice folder) | |
| Home's captures, their pictures, the dictionary, the prefs: in `~/Library/Application Support/app.fovea/` | |
| System Settings, the permission prompts, Quit & Reopen, Clear my screen, Open at login | |

## Flags

| Flag | Does |
|---|---|
| `--reset-onboarding` | The first run again |
| `--reset-all` | Everything kept goes too (captures, pictures, words, settings) |
| `--skip-onboarding` | Mark the first run done |
| `--home`, `--settings <pane[:id]>` | Open the window there (`--settings notch`) |
| `--step=<step>` | Start the first run at a step (`name` … `home`) |
| `--practice-agent` | Never call the real Claude Code |
| `--mute` | No sound |
| `--review` | The Oct 15 review (docs/v1/REVIEW_2026-10-15.md): a Review menu that stages each state the review added. |
| `--demo <state>` | Stage a notch state, with the Workbench's sample sessions and no microphone. Every state the Workbench shows (Oct 11; the list is `IslandController.stageNames`): Voiceflow `voiceFlow`, `capture`, `stack:<n>[:open\|peek\|hover\|inspect]`, `highlight:text\|file\|stack\|opened`, `countdown:lastMinute\|lastSeconds`, `transcribing`, `cancelled`, `noSpeech`, `pasteNotFound[:expanded]`, `error:<VoiceError>`, `glow:<palette>`; Dispatch `v2Voice`, `v2Transcribing`, `v2Send[:mixed\|model\|browse]`, `route[:open]`, `titles`, `v2Board[:end\|open]`, `hello`, `steps:board\|session`, `v2Chat[:formula\|calendar\|draft\|code\|working\|steps\|expanded]`, `reanswer:working\|done`, `queue:queued\|paused`, `asksOver`, `whole[:work\|long\|outline\|exit]`, `pulled[:tucked\|resized]`, `preview:aura\|panel`; any of them over an app full screen, `fullScreen:<state>` |
| `--data-dir=<path>` | Keep everything there instead of Application Support (a test run of its own) |
| `--smoke` | The notch walked through its states and checked, then quit: Voiceflow, Dispatch, the board, a session (expanded, asking more, closed, pulled out), the prefs. Its window invisible, no keys or pointer watched, nothing reaching another app, a data folder of its own. Prints each check and `SMOKE PASS`. `--smoke-shots=<folder>` also pictures each state (its window then visible) |
| `--smoke-first-run` | The first run's teaching walked the same way, the practice agent answering, nothing about the Mac changed (no Dock, no login item, no apps hidden) |
| `--shot <file.png>` | A picture of Fovea's own windows a moment after launch (`--shot-after=<seconds>`), then quit; no Screen Recording needed. In a first run, `<file>.stage.png` too, drawn off screen |
| `--design-shots notch\|first-run\|window <dir>` | Pictures of every design for the dev team's handoff document, then quit. `notch`: every `--demo` state staged on the real island, in Light, and the main ones in Dark, Floating and Compact (`--only a,b` for some); `first-run`: the first run walked with the practice agent (`--practice-agent --mute`). Both are pictures of the real screen, so Fovea needs Screen Recording and has to be started with `open` (`open -n build/Fovea.app --args …`): under it, a clean desktop (Tahoe Day, a document and a file to take) on every Space, and each picture waits until that desktop is in front, so nothing of the person's is ever pictured. `window`: Home and every Settings pane from what the first run left in the same `--data-dir` |
| `FOVEA_NO_ACTIVATE=1` | Stay in the background |

Each permission prompt can be shown again: run `tccutil reset All app.fovea` (it resets every grant
for Fovea).

## Layout

Lower layers never import upper ones; the island and the window never import each other.

| Target | What |
|---|---|
| `FoveaKit` | Pure: the prefs (`FoveaPrefs`), the keys (`FoveaKeys`, `ModifierGesture`), the words (`TranscriptCleaner`, `TitleNamer`, `RequestMatcher`, `PasteTarget`), finding bundled files |
| `CapturesCore`, `OnboardingCore` | Pure: Home's model, search and lines; the first run's steps, beats and copy |
| `FoveaStore` | `prefs.json`, `captures.json` (+ `media/`), `dictionary.json`, `onboarding.json`, as `@Observable` stores |
| `FoveaPlatform` | The notch panel, voice input, Accessibility reads, the paster, screen capture, permissions, the keyboard tap, hiding apps, relaunch, login item |
| `FoveaLook` | The accent's colors, the glass's appearance |
| `FoveaIsland` | The Workbench's island, hosted at the real notch (`Live/`: `IslandController`, `IslandLive`, the first run's `IslandDirector`) |
| `FoveaWindow` | Fovea Captures' Home and Settings (`HomeWindowController`) |
| `FoveaOnboarding` | The first run (`OnboardingCoordinator`, `RealStage`) |
| `FoveaApp` | The composition root and the first-run gate |
