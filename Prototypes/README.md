# Fovea Lab

Running prototypes of four front-page directions (Paper, Studio, Spaces, Threads) behind one
control panel. Separate package; nothing here ships. Shared files under `FoveaLab/Shared` are
copies of their shipping counterparts and are allowed to drift.

```bash
cd Prototypes
swift run FoveaLab                      # opens docked under the notch, palette alongside
swift run FoveaLab --direction threads  # paper | studio | spaces | threads
swift run FoveaLab --undocked
swift run FoveaLab --snapshot shots     # renders every direction to PNG and exits
swift run FoveaLab --smoke              # drives every palette action on the live window, logs, exits 0 on pass
```

Set `FOVEA_LAB_LOG=1` to print the dock geometry on open. The palette sits beside the window when
the display has room and tucks into the bottom-right corner when it does not (a 13-inch display).

Palette: `⌘1`–`⌘4` switch direction, `⌘⇧L` shows or hides the palette, `⌘K` search where a
direction has one, `Esc` closes whatever is open.

# Notch Workbench

A mock macOS desktop (wallpaper, the menu bar with the notch cut out of it, the Dock) with a
control panel beside it, for testing notch designs. The panel is a real sidebar column: drag its
edge to resize, drag past the minimum or click the toolbar button (⌃⌘S) to collapse; the choice
is remembered. The panel holds the notch's state and the display's controls. Notch: one
disclosure group per flow, two flows (`docs/island/FLOWS.md` teaches both to a coding agent).
**Voiceflow**: Silent notch, the notch at rest with nothing shown; Voice flow, the Listening
Flowing Bar (`docs/island/VOICE_BAR.md` has the numbers and why); Add screenshot, Transcribing and
Cancelled; and its two fallbacks, No speech detected and Paste not found. **Dispatch Version 2**
(Dispatch and Quick actions as one connected flow): fn⌃ opens the aura, a press of ⌘ takes a screenshot
(pressed twice, the whole screen), left Option is the highlighter for text and files,
fn⌃ again ends it: Transcribing (the aura filling as a progress bar), then Choose chat (Dispatch's
pill and send button; suggested chats as chips; left ⌃ opens every chat by agent and project;
nothing sends until you do); sent, the Control board shows a moment (the focus's progress, from what the agent reports;
Ready for review on top, then Running: seven or eight) and the island rests; a quick answer opens
by itself as its Expanded chat (the request, the response beside the agent's screen); any session
opens to it; its grab bar pulls it out into a window (drag anywhere, tuck into a side; a box to
ask more, whenever, even while it works; its corner or a pinch scales it; with follow-ups, a rail
at its right edge, after Notion's outline, shows which question is in view and lists them on
hover; ✕ closes it, stopping a session still at work). The pointer near the notch opens the
Control board, and leaving closes it. A Request menu and Play; `docs/island/DISPATCH_V2.md`. The
aura is libraries.dev/voice ported and fitted to the notch in its Wide style; the panel's Voice
glow section picks its colors (the package's palettes or a custom fan of hues, a hue spectrum
slider, the spread, hue drift, and swatches), opening the aura when the notch is at rest
(`docs/island/AGENT_VOICE_AND_THINKING.md` has the study). The earlier Dispatch and Quick actions
tabs are gone from the panel; their code stays, since Version 2 builds on it. One list at a time
shows the choice; Esc, under the groups, serves both. Pressing fn toggles
Voice flow, one press on and the next off, while the workbench is the active app (other apps too
once the process is trusted for Accessibility); if the Globe key opens the emoji picker, set
System Settings › Keyboard › "Press 🌐 key to" to Do Nothing while testing. Screen (the desktop, or a Safari tab
taken full screen, where the menu bar and the Dock are gone and the band beside the notch is
black), Appearance (System, Light or Dark for
the mock display; the window itself follows the system) and Background (your desktop picture,
the six bundled photos, slate, black, white, or Choose Image… for any picture on disk). Both
are remembered; Background applies to the desktop only.

```bash
cd Prototypes
swift run FoveaWorkbench                        # the window; closing it quits (a tool, not the product)
swift run FoveaWorkbench --snapshot shots       # workbench-light, -dark and -collapsed PNGs, then exits
swift run FoveaWorkbench --snapshot shots --only chat   # just the shots whose names contain "chat"
swift run FoveaWorkbench --smoke                # checks the toggle, ⌃⌘S, divider limits, material and stage on the live window; exits 0 on pass
FOVEA_NO_ACTIVATE=1 swift run FoveaWorkbench    # stays behind the terminal (for agents driving it)
swift run FoveaWorkbench --play-demo            # plays the screenshot walkthrough once launched
swift run FoveaWorkbench --record demo.mp4       # records the walkthrough into a movie and exits
```

The screen is a 13-inch MacBook display (1470×956 points, the 200×32 notch) scaled to fit the
column and never above 1:1, so its proportions do not change with the window or the panel; the
black bezel around it is the lid, and the notch is part of it.

The wallpaper is your own desktop picture when it is a still image (an aerial shows its still),
else the bundled mountain photo. Snapshots always use the photo and a fixed clock.

Screenshots: on a voice bar, press ⌘ (or choose Add screenshot in the panel's Notch list) for
capture mode, for one region: drag to capture it, and capture mode ends (press ⌘ again, or Esc, to
stop without one; hold it for capture only while held). Press ⌘ twice for the whole screen.
Left Option is the highlighter, in the accent color chosen under Fovea accent: drag across words to
mark them, or click a paragraph or a desktop file; the marks stay while the session lasts.
(Fovea's own surfaces are hidden while the whole screen is taken.) Other
clicks, the scroll wheel and ⌃Tab still reach Safari, so pages scroll and tabs switch mid-capture
(Screen: Full-Screen App shows four tabs).
Captures stack at the left of the bar; hover fans them, a click shows them all. There, a click on
one looks closer, hovering one shows its ✕ to remove it, and esc steps back one level.
`docs/island/REFERENT_STACK.md` has the research behind the shapes and the motion.

Transcribing and cancelling: fn's second press transcribes ("Thinking" and its ellipsis over a
4 pt line that fills), then the bar closes. While capturing, Esc only ends capture mode (the bar
and the captures stay), as it ends ⌘⇧4's. Otherwise Esc (or the panel's Esc) on the bar cancels the
request, with 2 s to Undo (the pill or ⌘Z) while a 4 pt line drains; resting the pointer on the
bar holds the time. When nothing was said (fn pressed twice quickly, since the workbench has no
microphone) the bar reads "No speech detected" for 2 s, then rests. `docs/island/PROGRESS.md` has
the research behind the choice.

Paste not found: when the transcription ends on a page with no input box (the desktop, or any
tab but the design notes, whose comment box takes the words), the island grows to hold the
transcript: two lines cut at the tail, ✕ inside a ring counting a straight 5 s down to rest (it
keeps going while the transcript is open and under the pointer; only Copy stops it), a chevron
that opens the whole transcript, and Copy. `docs/island/PASTE_NOT_FOUND.md` has the research.

Feedback · Oct 6: the panel's first group holds the dev team's review of the notch, one tab per
point that has something to see. Each tab stages the mock display, and the flow runs live from
there. Where Yulun asked for variations, the tab has a picker to compare them.

| Tab | What it shows |
|---|---|
| 1 | Choose chat with its referents as one stack, and the model and effort pill and sheet |
| 2 | Every voice error on the island, in English |
| 3, 8 | The highlighter (Option) on words and on a file; ⌘ taking screenshots |
| 4 | The last minute of ten, counting down at the bar's right |
| 6 | Split View: the caret in the accent color shows where the words go (Screen › Split View; Play) |
| 7 | The words landing in the field, then the notch leaving |
| 9–10, 17 | The control board: every session on the Mac, in eleven designs (Sections, Badges, Focus, Capsules, Wings, Split, and the pet in Wings, List, Capsules, Desk and Lanes) |
| 11–13 | A session: working, and done (its work folded, the answer, Open buttons, the bar, the box) |
| 15 | A new chat named from its request |
| 16 | The agent's steps, one at a time, in the session and on the board |
| 19 | Skipping the words' review: a settings icon on the bar opens the chat, model and effort |
| 23 | Answer again and Stop, in the bar |
| 24 | The queue, waiting and held |

`swift run FoveaWorkbench --stage=<tab>[:<stage>]` opens on a tab (for example `--stage=countdown:lastSeconds`);
`--trace=<tab>` prints the island's state over time.
`docs/island/FEEDBACK_2026-10-06.md` has every decision, the research (14, line counts, coucou). `swift run FoveaWorkbench --snapshot shots --only fb-` renders every tab.

**Density** is the Compact | Spacious switch at the top right of the window's toolbar (View ›
Compact Panels ⌘1, Spacious Panels ⌘2). Compact is the open panels as they were through Oct 6;
Spacious, the default, gives them the Mac's own sizes and more room (`docs/island/SPACIOUS.md`).
The resting notch and the voice bar are the same in both. `--density=compact|spacious` sets it for
one run, for example `swift run FoveaWorkbench --snapshot shots-compact --density=compact`.

**Original · Native** (`docs/island/NATIVE.md`): the toolbar's tabs, View › Original Design (⌥⌘1)
and Native Design (⌥⌘2), or `--design=native`.
- **Native** draws every state in the app's and the onboarding's language: the island and what
  drops below it Liquid Glass in the display's appearance, only the notch black; the accent and
  the system's state colors.
- **Native panels** (the sidebar, in Native): Attached, one glass shape hanging from the top edge
  as Original's island does (the default), or Floating, a panel under the notch.
  `--native-panels=floating` sets it for one run.
- **The content is Original's,** but an approval's Allow, which says what it does (Run Tests).
- **Shots:**
  - `--snapshot shots --only native-` gives `native-light-…` and `native-dark-…`, plus
    `native-floating-…` and `native-desktop-…`. The screen must be unlocked, since only a window
    capture draws glass.
  - `shots/native/native-compare.png` puts the two side by side; `native-panels.png` puts
    Attached beside Floating.
  - `--render-native=<dir>` draws off screen.
- **Motion and checks:** `--record-native native.mp4` records both flows; `--smoke --only-native`
  runs Native's checks.

**The pet** (`docs/island/CREATURES.md`): Fovea's Lasso with two eyes, drawn as far as its agent
has got through its plan, in five of the board's designs (Pets · List, Capsules, Desk, Lanes, and
round one's Wings), and at rest beside the notch (the Board tab's switch). `--stage=progress:petLanes`
opens on one; `swift run FoveaWorkbench --record-pets pets.mp4` records the pet through the designs
(`--record-creatures` records Wings); `--render-pets=<dir>` draws the designs side by side and
`--render-creatures=<dir>` every pose.

**Expanding a session** (`docs/island/WHOLE_SESSION.md`): the button beside ✕ (or left ⌃) opens
the whole session. It shows every request, oldest first, in one centred column, as tall as it is
down to the display's foot, 880 pt wide. Each answer has what the agent did folded above it
("Worked for 1 m 12 s · Edited 2 files ›"); opened, it shows the tools, the files and their lines,
and the agent's words between them. From two requests up, an outline of the requests sits at the
right, after Notion's: hover it for the list, click one to go there.
- **Esc** comes back to the usual size, then closes.
- **‹ at the header's left** goes to the control board, however the session was opened.
- **On the board,** a Done row's expand button opens a session this way.
- **The answer tab** has a "Session expanded" switch.
- **`--v2=whole|wholeLong`** opens on a session of four requests, or of twelve.

# Window Bench

The app window for the notch, page by page (Onboarding, Projects, Settings, Run detail, Search,
Captures, Polish), with every open design choice on a control panel beside it: 38 decisions, each
switchable live, and every motion replayable from its start at full or reduced speed. The window
binds no keys and has no sidebar; state is drawn by shape (● ! ○ ◌, dashed for can't see). A lab
notch at the real notch drops the receipt card and flies it into the window. `FoveaWindowBench/README.md`
has the rules, the panel and the layout; the research and scores are in `~/Desktop/fovea-app-refs/v2/`.

```bash
cd Prototypes
swift run FoveaWindowBench                       # the window, the panel, the lab notch
swift run FoveaWindowBench --snapshot shots      # every state to PNG, then quit
swift run FoveaWindowBench --record x.gif --play drill   # one Play scenario to GIF + mp4 + contact sheet
swift run FoveaWindowBench --smoke               # exit 0 when every rule holds on the live windows
swift test --filter WindowBenchCoreTests
zsh scripts/windowbench-grep.sh
```

# Fovea Onboarding

Fovea's first run, taught at the notch of a mock MacBook display (Oct 9):
- hello, and make it yours: the accent, and the aura the Dispatch bar glows with;
- Grant Fovea Access: both lists in one step, dragged from the notch into a mock System Settings; the microphone, with a line to say;
- your coding agents connected, and a say in which comes next;
- two real tasks with the real keys: the weekly update, gathered from a chat and three browser tabs (the whole screen, then a part from each tab), and your packing list (words and a file), sent to the Claude Code on this Mac;
- dictation into two windows, real words from the app bundle;
- your words brought in from Wispr Flow or VoiceOS with one click, then the real Home from Fovea Captures.

It's calm: captions in the Island, typed out, and procedural sound, no voice or video. The design and its
decisions: `docs/onboarding/ONBOARDING.md`.

```bash
cd Prototypes
swift run FoveaOnboarding                          # the first run, a control panel at its left
swift run FoveaOnboarding --step=weeklyUpdate      # start at any step
swift run FoveaOnboarding --play                   # the whole run, played by itself (Play it all, in the panel)
swift run FoveaOnboarding --play-from=pointAndSay  # …from a stage (the panel's Stages bookmarks do the same)
swift run FoveaOnboarding --practice-agent         # never call the real Claude Code
swift run FoveaOnboarding --no-typing              # lines shown whole, not typed out
swift run FoveaOnboarding --snapshot shots/onboarding [--only 14]   # every step's moments to PNG
swift run FoveaOnboarding --smoke                  # the whole run on synthetic key presses: SMOKE PASS
swift run FoveaOnboarding --mute
scripts/onboarding-app.sh                          # build/FoveaOnboarding.app: dictation's real words
swift test --filter OnboardingCoreTests
```

So the onboarding can open its Home, Fovea Captures is now a library (`CapturesUI`, the
`FoveaCaptures/` folder) plus a one-line app (`FoveaCapturesApp/main.swift`).
`swift run FoveaCaptures` is unchanged.
