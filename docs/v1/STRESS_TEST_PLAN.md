# Stress-testing Fovea 1.0: the plan (Oct 18)

The goal: try every feature and edge case of the first run and the app, and make sure each works smoothly, recovers when something goes wrong, and never leaves the person stuck.

**Fovea 1.0 is a frontend demo.** The account, plan, updates, memory, agents' answers and sending are simulated. So the test isn't "is the answer right". It's three questions:

1. Does every state appear when it should, read right, and look right?
2. Can the person always get out?
3. Is what's real on the Mac really handled? The real parts are:
   - the keys, the microphone and speech;
   - permissions;
   - reading text through Accessibility, screen capture, paste, and file drops;
   - displays and Spaces;
   - the Dock and the menu bar;
   - files on disk;
   - the first run's changes to the desktop.

## How others do it, and what we take from each

| Practice | What it is | What we use |
|---|---|---|
| **Heuristic Test Strategy Model, SFDIPOT** (James Bach) | A checklist of what to *vary*: Structure, Function, Data, Interfaces, Platform, Operations, Time. | The axes of the matrices below. Platform, Operations and Time find most of Fovea's edge cases: displays, Spaces, sleep, a quit mid-flow. |
| **FEW HICCUPPS oracles** (Michael Bolton) | Ways to *judge* whether what you see is a problem: consistent with History, Image, Comparable products, Claims, User desires, the Product itself, Purpose, Statutes. | "Claims" are our docs (V1.md, REVIEW_2026-10-15.md, AGENTS.md): a state that contradicts a decision is a bug. "Comparable products": macOS's own behaviour (⌘⇧4, Notification Center, Spotlight). |
| **Attack lists** (Whittaker, *How to Break Software*; the Hendrickson/Lyndsay/Emery heuristics cheat sheet) | Inputs that break things: too small, too big, just right (Goldilocks: 0, 1, many, max, max+1); wrong types; long strings; repetition; interruption; doing things out of order; doing them fast. | A boundary column on every input: the name, email, languages, referents, captures, recording length, file size. Interruption and repetition on every flow. |
| **Session-based exploratory testing** | Time-boxed charters (45–90 min) with a mission, a scope and notes, rather than open-ended poking. Agents and people both drift to the happy path unless given a "saboteur" charter. | Twelve charters (below), each with a saboteur half. |
| **Model-based testing and "smart monkeys"** | Model the UI as states and transitions, then walk it, randomly but only by valid moves, with invariants checked after every step. A dumb monkey taps empty space; a smart one reaches deep states. | Fovea already has the models: the notch's `NotchState`, and the first run's `Step` with its beats. A seeded random walk over them (`--stress`), checked against invariants, is the automated core. |
| **Interruption and resume matrices** (mobile and onboarding testing) | Interrupt every step: background, quit, kill, sleep, lose the network, deny a permission. Then assert the exact state after resuming, not just "it opened". | A step × interruption table for the first run (below). |
| **Accessibility audits** (Apple's Accessibility Inspector and XCUITest's `performAccessibilityAudit`, Xcode 15+) | Check every element for a label, contrast, hit size and keyboard reach, in light and dark, with Reduce Motion and Increase Contrast on. | An AX walk of every window and the notch, plus a manual VoiceOver pass. |
| **Bug bash** | 90–120 minutes, everyone on the same build, written scope, a moderator, a notetaker, no fixing during the bash, findings logged right away. | The last phase, with the dev team, using the Review menu to reach every state. |

## Invariants: what "working smoothly" means

These must hold after any sequence of actions. The automated walk checks them after every step; testers keep them in mind.

1. **Always a way out.** Esc steps out one level from every notch state. Every window and sheet can be closed. Every first-run page has Back (except the first) and Exit tour.
2. **The notch comes back to rest.** After a session lands, is sent, cancelled or fails, the notch is silent within a few seconds. The display rule: it opens on the pointer's display and returns home afterwards.
3. **Nothing is lost.**
   - Words that couldn't paste stay held (Copy, Paste) and in Home.
   - A failed transcription keeps its recording and retries.
   - Closing a working chat never stops it.
   - A paused tour resumes where it was.
4. **Nothing left behind.** No highlight marks, drop targets, capture overlays or pulled-out windows outlive their session. Apps hidden by Clear my screen always come back: at the end, on Exit tour, on quit, and after a crash on the next launch.
5. **No doubles.** The same referent, file, session or capture is never added twice. One Fovea process, one notch.
6. **Keys behave.**
   - The recorded shortcuts work, and nothing else does.
   - ⌥ twice never does anything in Fovea, so the Claude app keeps its shortcut.
   - Fovea never blocks a key it doesn't own.
   - Recording a shortcut pauses the notch.
7. **The words match the decisions.**
   - Copy follows AGENTS.md's vocabulary (referent, never "attachment").
   - No usage stats, no streaming text, no marks.
   - The menu bar icon is always present.
8. **Budgets.**
   - Notch states appear within one animation (≤ 0.3 s).
   - Home opens in under 0.5 s with 5,000 captures.
   - Idle CPU is under 1%.
   - Memory stays flat over a two-hour soak.
   - No dropped frames during the notch's springs on a 120 Hz display.

## The matrices

### Platform (vary each, on the flows marked)

| Axis | Values | Run on |
|---|---|---|
| Display | Built-in with notch · external only, lid closed · two displays, notch on one · display unplugged and plugged mid-session · scaled resolutions (More Space / Larger Text) · Mac without a notch | Every notch flow, pulled-out chats, highlights, the first run's stage |
| Spaces and full screen | Another Space · an app full screen (the notch's black band) · Mission Control open · Stage Manager on · menu bar auto-hidden | Voiceflow, Dispatch, the board, highlights (they must stay with their window) |
| Appearance | Light · Dark · switching live · each accent · Reduce Motion · Reduce Transparency · Increase Contrast | Window, notch (glass), first run |
| Keyboard | Built-in · external without fn/Globe · fn set to change input source or show emoji · two input sources (fn may switch them) · non-US layout (AZERTY, Chinese Pinyin) · Caps Lock remapped to fn | Shortcuts (default and recorded), the first run's key lessons |
| Language | English · Simplified Chinese (speech and system) · requested languages under More… | Dictation, Dispatch titles, Home search |
| Account state | Fresh macOS user with nothing granted · everything granted · a permission revoked while Fovea runs · signed out | First run, Getting Started, Settings |
| Power and lifecycle | Sleep and wake mid-recording · lock screen · log out and in · low battery / Low Power Mode · launched at login · a second copy launched (`open -n`) · killed (`kill -9`) at any point | Everything; the first run's Clear my screen especially |
| Agents on this Mac | None · Claude Code not signed in · both installed and signed in · CLI only on a non-standard PATH | Connectors, the first run's agents step, Dispatch |

### Data (the Goldilocks column)

| Input | Try |
|---|---|
| Name | empty · spaces only · 1 character · 80 characters · emoji · Chinese · RTL (Arabic) · a pasted name with a newline |
| Email | empty · "a@b" · 254 characters · uppercase · with + · invalid then fixed · Resend pressed during the countdown |
| Languages under More… | 0 · 1 · 12 · duplicates in different case · "English"/"Chinese" typed · emoji · 200 characters |
| Recording | under 0.3 s · silence for 10 s · 9:59 then 10:00 (the limit) · loud noise · two people · Chinese and English mixed |
| Referents in one session | 0 · 1 · 3 (no +N) · 4 (+1) · 25 (the row must swipe) · the same region twice · a tiny region (2×2 pt) · a region across two displays |
| Taken words | one word · one line · a whole page · a selection in a field that doesn't report frames · selecting in the field the words will paste into (not taken) · double- and triple-click |
| Dropped files | one · ten at once · a folder · a 25 MB image (the notice) · a file with no extension · a file on a network drive · text dragged instead of a file (nothing) · dropped just outside the notch (nothing) |
| Captures in Home | 0 · 1 · 5,000 over three years (calendar, search, scrolling) · captures with 20 referents · very long words |
| Dictionary | 0 words · 2,000 words · import of an empty, a malformed and a 5 MB file · a word with 10 spellings |
| Prefs and captures on disk | missing · empty · malformed JSON · from an older version · read-only folder · disk full (the window's four local-data errors) |

### Interruptions × the first run

For each first-run step, interrupt it in each of the ways in the first column, then reopen and check the resume state in the third.

| Interrupt | How | Expected on resume |
|---|---|---|
| Exit tour | the corner | Home with "Finish the tour"; resuming returns to that step; hidden apps back |
| Quit | ⌘Q, Dock, menu bar | Next launch returns to that step; apps back |
| Kill | `kill -9` | Same as quit; apps hidden by Clear my screen come back on the next launch |
| Back | ⌘[ or Back | The previous page as left; practice tasks start over cleanly |
| Screen Recording's Quit & Reopen | System Settings | Resumes on Grant Fovea Access with the new permission shown |
| Permission denied | "Don't Allow" | The page waits with Open Settings; never jumps; Skip for now works |
| Sleep and wake, lock | mid-step | The step is unchanged; the microphone recovers |
| Another app to the front, another Space | mid-step | The stage waits; returning shows it as left |
| Agent slow or failing | no agent / practice agent / agent killed | "Do it for me" and the practice agent finish the step |
| Practise again from Settings › Getting Started | after the tour | Only that task runs; Home at the end; the tour's state untouched |

## The automated part (built into the app, runnable any time)

The existing smoke runs already walk the notch (`--smoke`, about 140 checks) and the first run (`--smoke-first-run`). They become a stress suite:

1. **`--stress [--seed N] [--steps 2000]`: a smart monkey over the notch.**
   - From any state, it picks a valid move at random:
     - keys: the shortcuts, Esc, ⌥, left ⌃ and Return;
     - events: a drop, a selection, a click on the board, a hover in or out, dragging a chat out, Back, Close, Stop;
     - a Review stage.
   - After each move it checks invariants 1, 2, 4 and 5.
   - A failure prints the seed and the last 30 moves, so any run can be replayed.
2. **`--stress-first-run`: random walks over `Step`.** It moves forward, Back, exits and resumes, quits, kills and restarts across a scratch data folder. It checks the resume state against the table above, and that the hidden apps' record is empty at every exit.
3. **Soak.** Two hours of the notch walk while the app samples its own memory and CPU every minute. Fail if memory grows by more than 50 MB or idle CPU goes above 1%.
4. **Persistence fuzz.** Start the app over corrupted, partial, old-format, read-only and full-disk data folders. Expect the right window state (MW-02b's four errors, or a clean start) and no crash.
5. **Pictures.** `--design-shots window` and `notch` in Light and Dark, both densities, both panel styles. Each set is compared against the last accepted set; a change is either intended or a bug.
6. **Accessibility walk.**
   - Walk every window, sheet and notch state through the Accessibility API.
   - Every control has a label and a role, nothing important is unreachable by keyboard, and text contrast clears 4.5:1 in both appearances.
   - Accessibility Inspector's audit is run by hand on the window.

What the automation can't do: real keys on real keyboards, a real microphone, real text selection in other apps, real Finder drags, real display plugging. Those are the manual charters.

## The manual charters (on real hardware)

Each charter is 45–90 minutes, in two halves: first the happy path, then the saboteur.

1. **First run, a fresh macOS user, nothing granted.** Every step, every Back, every Skip, a denial for each permission, Quit & Reopen. *Saboteur:* kill the app during Clear my screen; unplug the display on the agents step; type a 200-character name.
2. **First run, everything already granted, agents installed.** Check nothing jumps, and the practice tasks run with the real agent. *Saboteur:* sign Claude Code out mid-task; take the wrong part of the screen; drag the wrong file; drop the file just beside the notch.
3. **Voiceflow in ten real apps:**
   - TextEdit, Notes, Mail, Messages, Slack, Chrome (a textarea and a rich editor), VS Code, Terminal, a password field, the Spotlight field.
   - Check that the words land, that referents follow (pictures where the app takes them), and what happens with no field focused.
   - *Saboteur:* switch apps mid-sentence; dictate for 10 minutes; take 25 referents; press fn 20 times fast.
4. **Taking words with no key:**
   - Selection in TextEdit, Safari, Chrome, Notes, Xcode, Slack (Electron), a PDF in Preview, a canvas (Figma), the Claude app.
   - Check the highlight follows the cursor while dragging, lands on the lines, and stays on that window's screen.
   - *Saboteur:* scroll the page, switch Space, move the window, select on the other display.
5. **⌥ and file drops:**
   - ⌥ once and drag; ⌥ held for several; ⌥ twice (nothing in Fovea; Claude opens).
   - ⌥ used in typing (⌥E é) while listening: no capture.
   - Drag from Finder, the desktop, Mail and a browser's download bar.
   - *Saboteur:* drop a folder, a 25 MB image, ten files, a file during Choose chat.
6. **Dispatch from start to answer, many sessions.**
   - Ten sessions at once; the board's sections; Needs you, approvals and a form; the queue, Stop, close never stopping.
   - Pull out three chats, tuck them into side tabs, move between displays, resize; expand a whole session; edit a request; Answer again; Open in its agent.
   - *Saboteur:* close a working chat; stop during Sending; Esc everywhere; hover in and out quickly.
7. **Every failure, via the Review menu.** Walk Review › Notch, Home, Settings, First Run and Menu Bar. For each state, check the words, the way out, and that it clears.
8. **Home at volume.** Load 5,000 captures. Check the calendar across years, search in Chinese and English, the tag filter, Open in Notch, Send Again, Save to a read-only folder, Delete and Undo.
9. **Settings, every pane.**
   - Record shortcuts: clashes, Clear all, a key without fn on an external keyboard.
   - The Memory browser in bulk; dictionary import; Connectors with nothing installed.
   - Plan, About and Account (sign out, sign in); Show in Dock off.
   - *Saboteur:* close the window mid-record; switch appearance live.
10. **Menu bar and the Mac.**
    - Each status icon state; every menu item; Show in Dock off with the window closed.
    - Move to Applications from Downloads and from a disk image; Open at login.
    - Two copies launched; sleep, wake and log out with a session open.
11. **Accessibility.** VoiceOver through the first run, Home and Settings, and the notch's notices. Keyboard only. Then Increase Contrast, Reduce Motion and Reduce Transparency, in both appearances.
12. **Long day.** Use Fovea for real for two hours: dictation, dispatches, Home. Note every hitch, delay or moment of doubt (an oracle of "User desires").

## Logging and triage

Each finding gets a one-line title and the build, then:

- **Where:** the step, state or pane.
- **Steps to reproduce:** the seed, for automated runs.
- **Expected vs seen:** with the oracle it breaks (an invariant, or a decision in the docs).
- **Evidence:** a screen recording, or the app's log: `log stream --predicate 'process == "Fovea"'`.

Severity:

- **Blocker:** stuck, data lost, apps left hidden, crash.
- **Major:** wrong state, or a way out missing.
- **Minor:** wrong words, a misplaced mark, a slow beat.
- **Polish.**

Blockers and majors are fixed before the bug bash. Each fix gets an automated check where the smoke can reach it.

## Order of work

1. **Build the automated suite** (the stress walk, the first-run walk, the soak, the persistence fuzz, the pictures, the accessibility walk). Run it, fix what it finds, and repeat until clean.
2. **Run the manual charters on this Mac.** That's charters 2–12 with what's here; charter 1 needs a fresh macOS user account. Some of them require taking over the screen.
3. **Run the platform matrix rows this Mac can't cover** on the machines that can: an external display, a Mac without a notch, an external keyboard.
4. **Hold the bug bash with the dev team:** 90 minutes on one build, the Review menu, these charters split between people, no fixing during it.
5. **Triage and fix, re-run the suite, and publish the results** (what passed, what was fixed, what's open).

## Sources

- James Bach, Heuristic Test Strategy Model (SFDIPOT); summaries at [tessl.io](https://tessl.io/registry/testland/sfdpot-exploratory-heuristic) and [tessl.io](https://tessl.io/registry/testland/heuristic-test-design-reference)
- Michael Bolton, FEW HICCUPPS consistency oracles: [developsense.com](https://developsense.com/resource/Oracles.pdf), [Ministry of Testing](https://club.ministryoftesting.com/t/test-bash-manchester-2018-workshop-et-101-resources/18871/3)
- Exploratory testing heuristics and the Goldilocks, Flood and Interruptions heuristics: [qaskills.sh](https://qaskills.sh/blog/exploratory-testing-heuristics-cheatsheet), [XMind template](https://templates.xmind.com/templates/heuristics-xfc6)
- James Whittaker, *How to Break Software* (user interface attacks): [O'Reilly](https://www.oreilly.com/library/view/how-to-break/9780321657497/ch03.html), [19 Attacks](https://origin2.cdn.componentsource.com/sites/default/files/resources/security-innovation/547201/19-attacks.pdf)
- Model-based testing and monkey testing: [arXiv 2608.00236](https://arxiv.org/pdf/2608.00236), [arXiv 1606.00503](https://arxiv.org/pdf/1606.00503), [Aalborg MBT notes](https://homes.cs.aau.dk/~li/NDP07/MBT1.pdf), [appsierra](https://www.appsierra.com/blog/monkey-testing)
- Interruptions and resume in onboarding and mobile flows: [macmyths.com](https://macmyths.com/best-mobile-app-testing-scenarios-to-cover/), [NVIDIA NemoClaw PR](https://github.com/NVIDIA/NemoClaw/pull/8000), [Incode SDK](https://developer.incode.com/docs/flutter-common-implementation-patterns)
- Accessibility audits: [WWDC23 session 10035](https://developer.apple.com/wwdc23/10035), [Create with Swift](https://createwithswift.com/testing-your-apps-accessibility-ui-tests)
- macOS checklists: [Setapp UX checklist](https://docs.setapp.com/docs/ux-checklist); keys and the Globe key: [Apple](https://support.apple.com/en-ca/HT201236), [Apple Developer Forums](https://developer.apple.com/forums/thread/766200), [Chrysalis issue](https://github.com/keyboardio/Chrysalis/issues/1310)
- Bug bashes: [Atomic Object](https://spin.atomicobject.com/bug-bash-guide/), [BrowserStack](https://www.browserstack.com/guide/run-bug-bash), [Jam](https://jam.dev/blog/how-to-run-a-bug-bash/), [Scott Berkun](https://scottberkun.com/2008/09)
