# Fovea's first run: the onboarding

> **Oct 17 (Ryan), in Fovea 1.0:** screenshots are taken with ⌥ (once: part of the screen; twice: the
> whole screen) instead of ⌘, and words and files need no key while Fovea listens (select the words,
> click the file). The tour teaches it so, and dictation now has a beat where something is taken
> while speaking and lands after the words. Details: docs/v1/REVIEW_2026-10-15.md.

Fovea's onboarding as an interactive prototype: `Prototypes/FoveaOnboarding`, over the pure step machine in `Prototypes/OnboardingCore`. What a real Mac allows, and the flow that follows from it, is in [REAL_MAC.md](REAL_MAC.md).

**Run it:**
```
cd Prototypes && swift run FoveaOnboarding
swift run FoveaOnboarding --play                        # the whole run, played by itself
swift run FoveaOnboarding --play-from=pointAndSay       # …from a stage: arrive turnOn agents pointAndSay dictation home
swift run FoveaOnboarding --step=weeklyUpdate           # start at a step
swift run FoveaOnboarding --practice-agent              # never call the real agent
swift run FoveaOnboarding --no-typing                   # lines whole, not typed out
swift run FoveaOnboarding --snapshot shots/onboarding   # every moment as PNGs
swift run FoveaOnboarding --smoke                       # the whole run on synthetic keys: SMOKE PASS
scripts/onboarding-app.sh                               # the app bundle, for dictation's real words
swift test --filter OnboardingCoreTests
```

## What it is

A mock MacBook display with the black Island at its notch. Fovea teaches itself there, on a practice desktop:
- **Real keys:** fn ⌃, ⌘ (twice: the whole screen), left ⌥, fn, Return, Esc and space.
- **Real pages:** the browser's tabs are local pages in web views (analytics, GitHub, support, a trail report).
- **Real files:** the weekly update, on the desktop once the agent writes it; a packing list and a trail map, there for the task that uses them.
- **Real sends:** to the Claude Code on this Mac, which really writes the update and edits the list.
- **Real words:** dictation's speech recognition, from the app bundle.
- **Real dictionaries:** Connect reads Wispr Flow's or VoiceOS's own words on this Mac.
- **The real Home:** Fovea Captures' Home appears at the end, with your words in its dictionary.

**The panel at the left:**
- **Stages**, one bookmark each: click to go there as things are; **Start here** begins a fresh run from it; **▶** plays from there.
- **Back and Next** step through; **Start over** begins at hello; **Play it all** plays the whole run.
- Every step, the keys without a keyboard, shortcuts through a step, the real-agent switch.
- **Feel:** letter by letter on or off, the keyboard, sound, Reduce Motion, pace.
- **Now:** the step, what it waits for, who answers, the agents asked for next.

## The decisions it follows

- **Oct 6–7:** capture first, then dispatch, then dictation (skippable whole); Make it yours at the start; calm, with captions and sound; it ends in the real Home.
- **Oct 8:** the first send is real; practice files, cleared at the end; every step has a way past; the microphone test needs your voice; drift is a dial.
- **Oct 9, round one:** the Stage design only; no logo animations; English and Chinese, More… typed; both permissions in one step, the notch's caption the thing to drag; a line to say for the microphone; the agents right after the permissions; two purposeful tasks; the keyboard in the bar, the keys for now lit in turn; instructions typed out; dictation in two windows; bring your words.
- **Oct 9, round two:**
  1. **Make it yours:** the title stays white; a real gap between the accent and the light, not a line.
  2. **The keyboard only where keys are taught.** Pressing a key elsewhere brings nothing up.
  3. **Grant Fovea Access:** the two lists named, nothing more.
  4. **The microphone:** "Say this out loud" and the line. Nothing else to read.
  5. **The agents:** Claude Code and Codex, a say in which comes next, and no sign-in: connected is connected. The sign-in step is gone.
  6. **No demo.** You learn by doing.
  7. **The first task is work: gathering from different tabs.** The weekly update, from a chat and three tabs. The notch says "Dispatch from anywhere."
  8. **The board for a task:** one caption saying where you are, the instruction for now, the line to say, set apart from "Not working?".
  9. **The feedback window suggests what to talk about:** the flow, how it looks, the hotkeys, settings and making it yours.
  10. **Bring your words with one click:** Connect for the apps that keep their words on this Mac.
  11. **The end:** "You're set", then two things, spread out: next time, start from the notch; eye tracking is in beta, ask for access.
- **Oct 9, round three:**
  1. **Nothing on the screen before it's used.** At the start only the notch and the bar (and System Settings while it's asked for). The browser and the team chat come with the weekly update, the update's file once it's written, the trip's two files with the packing list, dictation's two windows with dictation; once the tasks are done they go. The menu bar names the app in front: Finder, System Settings, Safari, Fovea.
  2. **The buttons work.** The review card's send arrow is lit the moment the card opens (the card was drawn a beat before the task was ready, and its dim arrow was disabled). No button is disabled by its view any more: a click always reaches the model, which decides. A first click on the stage works even with the window behind another app's (macOS 15 and later).

## The stages

| # | Stage | Steps | What it does | Time | Way past |
|---|---|---|---|---|---|
| 0 | Hello | hello, makeItYours | **Hello:** "Hi. I live up here." typed in the notch; one line; English, Chinese, More…. **Make it yours:** the accent, then, well apart, the light: palette, hue, drift. | ~40 s | — |
| 1 | Turn things on | permissions, microphone | **Grant Fovea Access:** drag the notch's line into Device Control and Data Access, then Screen & System Audio Recording; Quit & Reopen once. **Say this out loud:** "Hey Fovea, can you hear me?" | 1–2 min | Skip for now |
| 2 | Your agents | agents | Claude Code and Codex, on when they're on this Mac; the ones to come, and which you want next. | ~20 s | Skip for now |
| 3 | Point and send | weeklyUpdate, hover, packList, followUp | **The weekly update** (below), **watched from the notch** while the agent writes it, **the packing list**, and a **follow-up** by voice. | 3–4 min | Do it for me · Open it for me · Put it together for me · Skip the follow-up |
| 4 | Dictation | dictationIntro, dictation | Feedback into Fovea's window (with what to talk about), a reply into Messages: the words go to the window under the pointer. Send when it reads right. | ~1 min | Skip dictation (all of it) |
| 5 | Finish | dictionary, home | **Bring your words:** Connect, or paste. **You're set** → Done → Home. | ~30 s | Not now |

**Total:** about 7 minutes, or about 6 with dictation skipped. These are estimates.

## The two tasks, and why these

Work means gathering: numbers in one tab, a list in another, the ask in a chat, and a lot of switching between them. Fovea keeps one request open while you go from window to window and tab to tab, taking what you need.

**The weekly update** (work). Maya asks in the team chat for this week's update before noon. The numbers are in three tabs: Analytics, GitHub, Support.
1. fn ⌃: the aura bar opens. The keyboard lights fn and ⌃.
2. **⌘ twice:** the whole screen, with Maya's ask and the signups chart. The keyboard shows ⌘ with **×2**.
3. **Click the GitHub tab** (it glows), **⌘ once, and drag** over the merged pull requests.
4. **Click the Support tab**, **⌘ once, and drag** over the open tickets.
5. Say *"Draft this week's update from these."*, then fn ⌃: the review card, three referents.
6. Return sends. Watch from the notch while the agent works; **weekly-update.md** appears on the desktop and opens.

**Pack for the snow** (everyday). The trail report says snow came early.
1. fn ⌃; **hold ⌥ and drag** across the line about the snow; **tap ⌥ and click** Packing list.txt.
2. Say *"Add what I'll need for this to my packing list."*, fn ⌃, Return. The list opens with its new lines.
3. **Follow-up:** fn in the open answer, *"Now sort it into clothes and gear."*, fn.

The things to take come in any order. A drag that misses the pull requests or the tickets, or the wrong file, is said on the board and not taken.

## The board

- **Reading steps** (hello, Make it yours, your agents, dictation's start, your words, You're set): the desktop frosted and dark, a large serif line in white, the parts rising in.
- **Doing steps:** the glass bar at the bottom. Its left: **one caption** saying where you are, **the instruction for now**, typed out, and **the line to say**, in serif after Fovea's quote mark. Below them, small, "Not working?", the way past and the button. Its right: **the whole keyboard**, the keys for now lit in the accent (×2 on ⌘ for the whole screen).
- **The keys, in turn:** fn ⌃ → ⌘ ×2 → (click a tab) → ⌘ → (drag) → … → fn ⌃ → return; ⌥ for words and files; fn for dictation and follow-ups.
- **Typed out:** about 45 letters a second, a beat after a sentence, never more than about 2 s a line; laid out whole first, so nothing moves; a click shows it all; Reduce Motion and VoiceOver get it whole.
- **In Fovea 1.0 (Oct 21, Ryan, "simpler is better"):** lines show whole, and a hint stays for its reading time (`OT.Reading`); a page fades in whole (0.25 s) and the bar fades in (0.2 s), with no rise, blur or stagger; the keys and the tab to press are ringed in the accent, still; a held key has no glow; windows, files and sent messages fade (no scale or slide); the frost comes in in 0.3 s and still lifts slowly (1.6 s); the end fades in 0.3 s. What Fovea remembers and You're set are words alone, and Clear my screen's card keeps the accent on its button only. This prototype still types and pulses.
- **In Fovea 1.0 (Oct 23, Ryan, "include all"): the first run teaches what you do with a session, in the steps it has (still 16).**
  - **Watching the update:** open it from the board ("Click the update to open it."), drag it down out of the notch, drop it at a side of the screen, where it waits as a tab, and click the tab to bring it back ("When the tab shows a check…"). The answer may come at any point. The update's Quick Look waits until it's back, so it doesn't cover the tab. Past the opening, the way past is "Do it for me": each beat done for you.
  - **The packing list:**
    - Choose chat offers a new chat (picked) and the weekly update's ("Fovea picked the chat. ⌃ shows all your chats; return sends it here."). Picked, the weekly update's chat takes the request into that session, and asking more happens there.
    - The agent reads, then asks to edit Packing list.txt: the session needs you (the island's own Deny / Allow with the file), and the menu bar's icon says so. The bar: "… asks before it edits your list. Move to the notch and Allow it. The icon in your menu bar shows it too." Deny: "In practice, Allow it so the list gets made.", and it asks again. Sent, the way past allows it for you.
  - **Asking more:** once the sorted list is back, "Press ⌃ to see the whole session." (the expand button counts too), then "Esc steps back." with Continue.
  - **Dictation, Messages:** fn, say something, esc throws it away, ⌘Z brings it back, then fn lands the answer to Lin. esc and ⌘ Z light in turn. Words landed before esc: "Landed. This time…", and Messages' try starts again (the feedback stays done). The undo let go by: "Too late to bring it back…".
  - **You're all set:** one more line, with Fovea's menu bar mark: "The icon in your menu bar shows when Fovea listens, works or needs you."
  - **More to try** (Settings › Getting Started, outside the first run's order, Home again after each), with the practice agent:
    - *Take a few things:* fn ⌃, hold ⌘ and drag over two parts, open the stack, look at one, take one out with its ✕, fn ⌃, return.
    - *While it works:* send a route request; while it works, type one more thing in the session's box (it waits its turn and goes after the answer); Answer again, with another model from its menu; Stop it ("Only Stop stops an agent; closing it never does.").
    - *Nowhere to type:* fn with the pointer on the desktop, talk, fn: the words wait at the notch; Copy them, or click into the feedback window and Paste.
- **In Fovea 1.0 (Oct 23, Ryan, late): Make it yours shows each choice at the notch, the moment it's made.**
  - **A light:** the notch pulls down as Dispatch's listening bar, glowing in that palette, and stays while the page is up. The light was faint once its chromatic ridge went (Oct 21), so the inner light and its bloom are stronger (`VoiceGlow.wide`: 0.8 and 1.1, from 0.47 and 0.89), for the bar to read in its palette.
  - **A look, or the accent:** the board pulls down in that look (glass, panels, size; the accent on its buttons and marks) for 3 s (`OT.Motion.lookShown`), then goes straight over to the light picked, or up if none was. It used to leave the notch empty for good: the board opening told the run the notch was the board, so the light was forgotten, and every light touched after that showed nothing.
  - **The buttons answer at once:** a choice moves on a quick ease-out (`OT.Motion.select`, 0.12 s); on the 0.2 s ease-in-out the button lagged the notch.
  - **The keyboard lights only the left ⌘**, as it does only the left ⌥.
  - **The progress line's part still to go is gray** (`OT.Board.progressTrack`), so how far along it is shows on any wallpaper; the board's hairline went unseen on a bright one.

## The real sends

- **How it runs:** Fovea runs Claude Code's command-line tool in the practice folder, allowed to edit files there (`--permission-mode acceptEdits`) and nothing else, with the words and what was pointed at: the pictures as PNG files in `.captures/` (each said where it's from), the words quoted, the files by path. It reads the tool's stream for one line of activity ("Looking at part-2.png").
- **Who answers:** connected is connected; there's nothing to sign in to. When Claude Code's command-line tool can't answer on this Mac (`claude auth status` says it isn't signed in, a failure, over 150 s), the practice agent writes the same update and makes the same edits. The panel's "Now" says who answers.

## Dictation

Two windows, Fovea's feedback and Messages. The feedback window suggests what to talk about. Point at one, press fn, talk, press fn: the words land there, cleaned (no ums, a capital, a full stop), with the accent caret where they go. Feedback first, then the reply. **Send** keeps the feedback in `~/Library/Application Support/Fovea Onboarding/feedback.txt` (the shipping app would post it to Fovea); nothing goes before the click.

**Real words** need the app bundle (`scripts/onboarding-app.sh`): macOS checks for the app's reasons before it will ask for the microphone and speech recognition, and asks the first time dictation listens. Run with `swift run`, a stand-in line lands, and the bar says why. The shipping Fovea won't ask for Speech Recognition (window feedback rows 3–5); that prompt is the prototype's.

## Bringing your words

- **Connect**, one click, for the apps that keep their words on this Mac, read there, read-only, only when Connect is clicked (as VoiceOS imports from Wispr Flow):
  - **Wispr Flow:** its `Dictionary` table (each phrase, and what it replaces; deleted entries and snippets left behind).
  - **VoiceOS:** its `dictionary` table (each word not deleted).
- **Paste** for the ones that keep their words online (Typeless) or in settings (Superwhisper).
- **Anything else:** a paste or a file (.csv one or two columns, .txt a word a line, .json words or find/replace pairs, the Mac's Text Replacements .plist).
- **Looked over first:** each word ticked, duplicates and words Fovea knows dropped, at most 1,000; **Add 24 words**; then into Home's dictionary, as words you added.
- **Found by name only:** the apps on this Mac, by bundle ID or name in /Applications. The smoke run and the snapshots read a stand-in list, never anyone's words.

## What's real and what's simulated

- **Real:** the keys and the pointer; the pages, their tabs and the agent's work; the files; the pictures of the screen; the sends, when Claude Code can answer; the microphone's level; dictation's words, from the app bundle; agent detection; the dictation apps found and their words, on Connect; Home.
- **Simulated:** permissions and System Settings (see [REAL_MAC.md](REAL_MAC.md) for the real ones); the words of the two tasks (the lines to say); sending the feedback (kept on this Mac).

## Code

- **`Prototypes/OnboardingCore`** (pure, tested): `Step`, `Stage`, `Beat`, `PracticeTab`, the any-order beats, every step's way past, `Flow`, `Copy` (with the instruction for each moment), `KeyMap` (with `presses(for:)`), `Language`, `Agent`, `DictationApp` (with where each keeps its words), `Typewriter`, `DictionaryImport`.
- **`Prototypes/FoveaOnboarding`:**
  - **Model:** `OnboardingModel` (+Keys, +Steps, +Real: the mic test, the agent, dictation, your words).
  - **Board:** `Boards.swift` (Stage), `BoardParts.swift`, `TypedText`, `KeyboardView`.
  - **Screen:** `IslandView`, `StageView`, `PracticeWindow` (the browser and its tabs, the team chat, the feedback window, Messages), `SystemSettingsMock`, `DragHint`, `Desktop`.
  - **Real work:** `PracticeSite` (a tab's web view), `ScreenCapture`, `AgentRunner`, `PracticeFiles`, `MicMeter`, `SpeechInput`, `DictationAppReader`.
  - **Run:** `Play`, `Harness` (snapshots, smoke), `ControlPanel`.
- **Copied, and may drift:** from the Workbench, `IslandShape.swift`, `KeyMonitors.swift`, `Pointer.swift`; from Fovea Captures, `AuraGlow.swift`; from the shipping app, the recognition in `SpeechInput.swift`.

## Open questions

1. **Real Claude Code answers** need its command-line tool signed in once on the test Mac (`claude` in Terminal); until then the practice agent answers, quietly.
2. **Fovea's own sign-in** is gone from the run. Where does it live: the first send, Settings › Account, or the website?
3. **The feedback, the agents asked for and the eye-tracking requests** are kept on this Mac in the prototype. Where should the shipping app send them?
4. **The languages typed under More…** are kept, to choose what comes after English and Chinese.
5. **Settings › Dictionary** in the shipping app has no import yet; `DictionaryImport` and the readers could move there.
6. **Settings › Shortcuts** in Fovea Captures still shows the round-one keys; the onboarding teaches round two.
