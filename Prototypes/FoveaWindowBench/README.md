# Fovea Window Bench

The app window for the notch, with every open design choice on a panel. It covers seven pages: Onboarding, Projects, Settings, Run detail, Search, Captures, and Polish (Memory, the notch's Today settings, correcting an inference, Brief). Nothing here ships.

```bash
cd Prototypes
swift run FoveaWindowBench                          # the window, the control panel, the lab notch
swift run FoveaWindowBench --route run/r-bullets    # projects/<id> · run/<id> · captures · capture/<id>
swift run FoveaWindowBench --fixture heavy          # typical · heavy · empty · longNames · errors
swift run FoveaWindowBench --source mac             # real history: folder listings and dates only
swift run FoveaWindowBench --set drill=push --set surface=paper   # any decision=option
swift run FoveaWindowBench --reduce-motion --speed 0.25
swift run FoveaWindowBench --snapshot shots [--only 02b]          # every state to PNG, then quit
swift run FoveaWindowBench --record drill.gif --play drill        # a Play scenario to GIF + mp4 + contact sheet
swift run FoveaWindowBench --smoke                  # drives the rules on the live windows, exit 0 on pass
swift run FoveaWindowBench --dump-menus             # the menu bar and its key equivalents
swift test --filter WindowBenchCoreTests            # grouping, lines, search, history, diffs, variants
zsh scripts/windowbench-grep.sh                     # the rules as greps
```

`FOVEA_NO_ACTIVATE=1` keeps the bench from taking focus (snapshots then show inactive window chrome).

## The window's rules

These are built in, and smoke or the grep script checks each one.

- **GUI only.** The window binds no keys. The menu keeps only the system's own key equivalents (⌘Q ⌘H ⌥⌘H ⌘W ⌥⌘W ⌘M and Edit). `Settings…` has no ⌘,. Dictation, Emoji & Symbols and Full Screen are turned off.
- **Hover only reveals.** Every action shown on hover is also on the page it leads to, and hover never moves the row's text.
- **No sidebar.** The window is an archive; you drill in place and go back by the crumbs.
- **State by shape:** ● waiting · ! failed · ○ finished, unseen · ◌ running · nothing for seen · dashed for can't see.
- **Sans for what a person said, mono for what a machine computed.** Fovea writes no prose; a Brief is signed by the agent that wrote it.
- **Springs, from one place.** `Tokens/Motion.swift`, with the notch's values. Reduce Motion is respected (and simulated on the panel).
- Closing the window doesn't quit.

## The control panel

A floating panel beside the window. It never takes focus and takes the first click.

- **Go to:** every state of every page, without motion.
- **Play:** each motion from its start. Each sets its before-state, then makes the change through the Motion layer. "Record each Play as a GIF" saves to `~/Desktop/fovea-app-refs/v2/bench-saves`.
- **Design:** one control per open decision (38), each with a line on where it comes from. They are generated from `WindowBenchCore/Variants.swift`. To add a decision, add an enum there and read it where it's drawn.
- **Motion:** the spring system (notch, spec v1, motion notes), speed (1×, ½×, ¼×, ⅒×), the reveal's stagger, the highlight's length, simulated Reduce Motion.
- **Data:** fixtures or this Mac, the fixture set, appearance, window size, the lab notch, and simulated states: another notch app, Calendar access, fn starting Dictation, Screen Recording allowed (a result in another app shows a live thumbnail).
- **Compare:** the notch's own rows beside the window, logos hidden.

Choices persist in UserDefaults (`windowbench.state.v1`) through FoveaCore's `PersistentStore`. Snapshots use an in-memory store, smoke a throwaway suite.

## Layout

| Folder | What |
|---|---|
| `../WindowBenchCore` | Foundation only: the model, fixtures, grouping, computed lines, search, history aggregation, diff pairing, the variant registry. Unit tested. |
| `App/` | The AppKit app and its hand-built menu, the model, options, snapshots, smoke, the recorder. |
| `Tokens/` | Every color, size and duration (`BenchTokens`), and the Motion layer. |
| `Shell/` | The window, toolbar, breadcrumb, the level stack (drill in place, the ghost transitions), search field, status bar. |
| `Pages/` | Onboarding, the project list and page, the run, search results, captures. |
| `Components/` | State glyphs, folds, tickers, the receipt, the inference link and its correction. |
| `Settings/` | The settings window (toolbar tabs) and its four pages. |
| `Notch/` | The lab notch at the real notch, and the flight between it and the window. |
| `Panel/` | The control panel. |
| `Platform/` | The read-only history scan and agent detection. |

## Safety

- **Real history:** the This Mac source lists the agents' history folders and reads modification dates. It never opens a session file, and snapshots always use fixtures.
- **Hooks:** Install and Remove hooks are simulated. The bench never writes an agent's settings file.

The research, references, scores and open questions per page are in `~/Desktop/fovea-app-refs/v2/` (start at `INDEX.md`).
