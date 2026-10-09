# Agent panel (Dispatch)

After a request is sent, this is where the person sees it: the Agent tasks Fovea delivered. It is
the PRD's hover task list (AMENDMENTS: icon · Chat name · one line of activity · state; at most
five rows, then it scrolls).

Workbench prototype, Notch › Dispatch › **Agent panel**. It opens three ways:
- **The radio.** It stays open until Esc or another choice.
- **A rest on the notch.** It closes a beat after the pointer leaves.
- **Send, from Choose chat.** The new task is highlighted for 3.5 s, longer while the pointer is
  on the panel.

The **Panel** menu under Dispatch picks the row style: Ledger, Badge, Status or Live.

Code:
- `Prototypes/FoveaWorkbench/WorkbenchModel+Panel.swift`: hover, simulation, controls, keys.
- `AgentBoard.swift`: the sample tasks, their projects and scripts.
- `MockDesktop/AgentPanel.swift`: `PanelStyle`, `PanelLayout`, the rows.
- `WorkbenchTokens.Panel`: every number below.

Checks: `--smoke` runs 31 of them. Shots: `workbench-agent-panel-ledger`, `-badge`, `-status`,
`-live`, `-live-more`, `-sent`.

## The redesign (2026-10-01)

The first version was too crowded. It had a progress hairline, a 52×34 animated miniature, a
"+86 −12" change stat and the state word, all on every row. The feedback:
- The hairline's meaning was unclear.
- The full board was tiring to look at.
- The +/− numbers said nothing.
- Keep the agent's icon and the session's name, grouped by project.
- Show what the agent is doing realistically, or find something better than an abstract
  animation.
- "What a user needs … is the current state of that agent … the agent itself, and its state."

So every row now carries three things, in this order:
1. **Which agent:** its own app icon, and the session's name.
2. **Its state.**
3. **One line** of what it is doing, asks, did, or why it failed.

There is no hairline, no stat and no miniature, and the rows are grouped under their project's
name. This follows Uber's Live Activity ranking (one P0, one P1, at most one P2) and Claude Code's
Agent View, which has four attributes per row at most.

## Groups

- **Project headers:** the name in 11 semibold, white 0.4. They stick while the project's rows
  scroll under them. They never carry a count.
- **Group order:** the project holding the most pressing task comes first.
- **Row order inside a project:** the hover list's order, Needs you, Complete, Working, Failed
  (PRD §8). Within a state, the latest to reach it comes first. The order changes only when a
  state changes, never on each new activity line; users of Conductor reported rows "jumping
  unpredictably".
- **Rows are named by session**, never by project ("Paste not found countdown", "Snapshot
  tests"). Several agents can share a project; in the sample, app-ui-v1 holds Claude Code, Codex
  and Cursor.

## The styles

| Style | Row | State | What it is doing | Borrowed from |
|---|---|---|---|---|
| **Ledger** | One line, 30 pt: state glyph · icon · session · line (dim) · time | The glyph, in a fixed slot at the left, so it forms one column to scan | Dim, after the session, truncating. A task that needs you takes a second line for its question and answers (52 pt). | Claude Code Agent View; the Codex proposal for a fixed status slot |
| **Badge** | Two lines, 42 pt: icon with a badge · session over line · time | The glyph as a badge on the icon's corner, with no word. A line that asks turns amber; a line that failed turns red. | The line | Warp's vertical tabs |
| **Status** | Two lines, 42 pt: icon · session over line · glyph, word and time at the right | Glyph and word in the state's color, with how long, quietly | The line | The hover list's anatomy; Linear's status marks |
| **Live** | Two lines, 42 pt: icon · session over the real thing · glyph and word | Glyph and word | The file, command or page it is on, with its kind's glyph, then the line it is producing, typed in as it arrives in monospace ("ShortcutRecorder.swift  recorder.onChange { … }", "swift test  ✓ PayloadTests.ordersReferentsByDrawOrder"). A failure shows the compiler's error. | Devin's "Follow"; Cursor's file chips; Uber's "state plus one concrete fact" |

**The state glyph**, shared by all four styles, follows Linear and GitHub:
- **Working:** a quarter ring going round, slowly. It is the only state that moves; motion is the
  strongest pre-attentive cue, so it is kept for "alive".
- **Gone quiet:** after 5 minutes with no new activity, the ring stops and goes dashed, and the
  line says "No activity for 7m". A mark that keeps turning on a stall reads as broken.
- **Needs you:** amber, with "!".
- **Complete:** white, with a check.
- **Failed:** red, with ×.
- **Stopped:** a gray square.

Color is used only for Needs you and Failed. Done stays white, in the Island's ink. In every
style the glyph has a word beside it, or the line says the state, so the state never rests on
color alone.

**Time in state** ("4m", "1h") shows in Ledger, Badge and Status, and not under a minute. It is
the signal users ask for most in agent lists. It is not an efficiency metric.

**What the line says by state:**
- **Working:** a phase verb and its object ("Editing ShortcutRecorder.swift", "Running swift
  test", "Reading linear.app/method"). Flavour verbs are avoided: Claude Code's "Perambulating…"
  misled users.
- **Needs you:** the question or the command itself.
- **Complete:** what it did ("Fixed the two flaky snapshot tests"), not "Ready to review".
- **Failed:** why.

## Size

The panel is 440 pt wide, Choose chat's width with the same expanded corners (19 / 24). Going
from Choose chat to the panel after Send, only the height changes.

- **Room:** the list has the same room in every style: five two-line rows and two projects'
  names, 260 pt.
- **Visible rows:** at most five, ending on a whole row, never mid-row.
- **Scrolling:** past that, the list scrolls, and Send scrolls to its new task.
- **Island height:** 306 pt on the reference display, or 290 pt in Ledger, whose rows are shorter.

## Control, in place

| State | Control | When it shows |
|---|---|---|
| Needs you, a command | Deny · **Allow** (Allow is white, the primary) | Always. The line is the command itself. |
| Needs you, a question | Its answers ("Keep" · "Remove") | Always. The line is the question. |
| Working | Stop | On hover or keyboard focus |
| Failed | Retry | On hover or keyboard focus |
| Complete | Open | On hover or keyboard focus |

Other behaviour:
- **Click** a row to open its session in its own app; the island goes back to rest.
- **Keys:** ↑↓ move the highlight (never animated), Return opens, Esc closes.
- **Stop** reads as "Stopped", quietly, not as a failure.
- **Click guard:** for 0.5 s after the panel opens, its controls ignore clicks, so a click meant
  for what was under the pointer can never allow a command.
- **Highlights:** the pointer's and the keyboard's row fills at white 0.07 at once. The task Send
  just created holds white 0.12 and fades over 0.24 s when it lets go.

## The hover

The enter zone is the physical notch only: never the chin, the ears or the slack, and never below
the notch, where browser tabs sit.

| | Value | Why |
|---|---|---|
| Dwell | At least 120 ms on the notch, then the first moment the pointer is still (under 6 pt over 50 ms, checked every 20 ms). At 300 ms it opens anyway. | A deliberate aim lands at about 120–170 ms. A sweep along the menu bar never rests, even though it spends longer than the dwell on a 200 pt notch. |
| Wobble | Off the notch for under 80 ms keeps the dwell running. | The notch's bottom edge is where pointers wobble. |
| Stays open | While the pointer is on the panel, or within 8 pt of it on the sides and below. | |
| Closes | 100 ms after the pointer leaves. | |
| Reopen | Back on the notch within 300 ms of a hover close: it opens at once, with no dwell. | The person meant it. |
| Re-arm | After a close, the pointer must leave the notch before it can open again. | Growth under a parked pointer never opens it. |
| Empty | Never opens with no tasks. | |

### Motion

| | Value |
|---|---|
| Open | `.interpolatingSpring(duration: 0.26, bounce: 0)`. Width, height and both corners move together on the animatable outline. 90% at about 160 ms, settled at about 275 ms. |
| Rows in | Laid out at full size from the first frame, so the descending edge uncovers them. They fade in 50 ms after the shape over 0.16 s on ease-out-quint (opacity, blur 4 → 0, scale 0.97 from the top). Fully in when the shape is at about 95%. No stagger. |
| Close | `.interpolatingSpring(duration: 0.2, bounce: 0)`. The content goes out on the same spring with no delay, clipped by the outline. |
| A task changing | Its line, state and place in the order move on `.interpolatingSpring(duration: 0.35, bounce: 0)`. |

Why not `.smooth`: it hands the outline about 85% of a change on its first frame and then creeps
(VOICE_BAR.md). On a 250 pt drop that is a jump. The interpolating spring moves through the whole
range, peaking at about 37 pt per frame at 60 Hz instead of 53.

## Against the rules

The panel stays inside "never a task count, execution steps or logs; one line of current
activity per task":
- **No logs or step lists:** no terminal output, tool logs, "last 3 tools" or to-do checklists.
- **No counts:** no "×3" or "2 agents running", and no counts on project headers.
- **No usage figures:** no tokens, cost, context % or model names.
- **No decoration:** no mascots, carousels or sounds.

One judgment call: **Live's second line** is one line of what the agent is producing (a line of
code, a test that passed, a page's title). It is replaced, never appended to, so it stays one
line of current activity, not a log. If that reads too close to "rendering an agent's output",
Live is the style to drop.

Where the prototype differs from the app today:
- The app's list is 520 pt wide, with 46 pt rows (`IslandLayoutSpec.listWidth`,
  `Tokens.listRowHeight`).
- The app's dwell is a flat 100 ms, against the amendment's ~150 ms.
- The app's exit grace is 90 ms.
- The app opens and closes on `.smooth(duration: 0.18)`.
- The app's row hover fill animates.

## Research

**Agent control panels** (sources are 2025–2026 unless marked):
- Claude Code Agent View: one model-written status line per session, an age that freezes when
  done, Needs input grouped first, and Space to peek and reply without leaving the list.
- The Claude desktop and web apps: a +/− diff indicator, Allow / Deny cards, and filters by state.
  Users asked for whose turn it is and how long it has been in that state (anthropics/claude-code
  #96510, #94374).
- Codex: thread states with waiting-on-approval and waiting-on-input, and lines changed.
- Cursor 3's Agents Window: a Needs Attention group.
- Devin: Working / Ready / Blocked, with live shell, browser and desktop panes.
- Warp: the agent's icon with a status badge, plus a diff badge, and a hover card that doesn't
  take focus.
- Linear's agent sessions: thoughts and actions that are replaced when the next one arrives, plus
  a plan checklist.
- Manus and ChatGPT agent: a live view of the agent's computer.

**Notch apps for agents** (Vibe Island, Claude Island / Vibe Notch, CodeIsland, ClaudeNotch,
Claude Pulse, DevIsland):
- They expand on their own only for approvals and questions.
- Allow / Deny is always in the row, with keys.
- They jump to the exact terminal.
- Several add counts, costs, logs or mascots, which Fovea's rules exclude.

**Minimal status rows** (the second round):
- Claude Code Agent View: glyph, name, summary and age, the practical ceiling.
- Warp: a state badge on the agent's icon.
- Linear: one 14 px status mark per row, a ring that fills.
- Vercel's StatusDot: it moves only while building; a word only when the dot stands alone.
- GitHub Actions: a spinning dot, a check, an ×.
- Codex issue #49984: a fixed leading status slot for one scan line.
- Uber's Live Activity: ranked information, looked at briefly.
- Raycast: drop the accessories once there is detail.
- macOS: 24 pt table rows; HIG sidebars: two levels at most, with succinct labels.
- Tufte: erase redundant ink.
- Colin Ware: color, form and motion are pre-attentive; motion is the strongest and the most
  distracting.

**Glanceability:**
- Peripheral displays should be abstract and simple (Matthews, Berkeley).
- Motion is noticed in the periphery more than color or shape, but it distracts (Bartram, Ware &
  Calvert 2003). So only working rows move, slowly.
- Progress bars that pause read as slower (Harrison, UIST 2007).
- Long waits need a determinate signal (NN/g).
- ParallelPilot (2026): an ambient board with completion, clarification, error and
  unexpected-delay signals raised throughput in a 16-person study.

**Hover timing:**
- boring.notch, Atoll: 0.3 s dwell, 100 ms close grace.
- NotchKit: 0.15 s open delay with a 0.1 s cancel grace.
- Alcove: the enter zone is exactly the physical notch.
- NN/g: show feedback within 0.1 s.
- Radix NavigationMenu: a 300 ms skip-delay.
- Floating UI: `restMs` (open on rest, not on entry).
- WWDC23 "Animate with springs": duration is the perceived duration; bounce 0 by default.

## Not built (to decide)

- **Reply by voice to a working task:** hold fn over its row. None of the panels or notch apps
  above offers this, and it fits Fovea.
- **An entry nudge:** the notch drops 3 pt as the pointer arrives, for feedback within 100 ms.
  This is not in the spec.
- **Peek:** a question or a command's diff expands its own row, for more than one line.
- **Hover-open over a full-screen app:** whether it should happen at all. Alcove's users asked to
  turn it off there.
