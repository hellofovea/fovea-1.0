# The control board in four drafts (Oct 27)

> **Removed from 1.0, Oct 27.** Ryan: "a lot of the previous designs of the agent control board is
> still here. Delete those. Only have the latest version that I approved." Today's board is the one
> board. The drafts, their Board Design menu and the older styles are gone. What follows is the
> research and the drafts as they were.

Ryan, Oct 27, after Arne Strickmann's post on Personal Agent Proxy ("Do we actually have the access
to see such detailed actions of the agents tho?"):

- **The pain:** you can't see what the agents actually do, but you don't want every trivial thing
  either, only the important ones.
- **The limit:** the notch mustn't get big. He picked Wings (`BAR_DESIGNS.md`) because it's seamless
  and small.
- **The ask:** "mac-os native, fits the wing design, elegant, minimalist, and dont take too much
  space … do some research of the design, ux, power user needs, and agent control board experience,
  then provide new drafts of the agent control board."

These four replace the Oct 26 designs (List, Horizon, Gallery, Index), which were "ambient, classy,
artsy" but didn't show what an agent did. Switch them from the menu bar icon's **Board Design** (it
shows a sample board a moment). Today's board stays the default.

## What the research found

**Personal Agent Proxy** (Arne's post, Oct 26; its docs and source):
- An agent calls `start_task(title, goal, parent?)` and gets an id. Every tool call has to carry that
  id, or it's refused. `finish_task(task, outcome)` closes it; sub-agents start sub-tasks, so one job
  forms a tree.
- Reads (marked read-only) are kept apart from runs (which change something or reach people), and
  each request is logged as succeeded, denied or failed.
- So a board can show the agent's own headline and goal, its requests grouped by intent, and blocked
  or failed marks.
- **Its limits:** it sees only what goes through the proxy, and replies to the post warn that a stated
  reason is written after the decision: log what was actually done beside it.

**Fovea already has the task.** It writes the request (the words and the referents) and names the
chat before the agent starts. What's left is attaching the agent's events to that session, and both
agents report them today without a proxy:
- **Claude Code:** hooks (`PreToolUse` / `PostToolUse` with the tool's input and result, Bash's own
  `description` as the "why", `PermissionRequest` to allow or deny at once, `Stop` with the last
  message, `SubagentStop`), and the transcript's edits with their +/− lines.
- **Codex:** hooks for Bash, `apply_patch` and `update_plan`; its rollout files type each command as
  `read`, `search` or other, with its exit code, and mark MCP tools `readOnlyHint`.

**The rule that comes out of it:** a side effect or a verdict is a **milestone**; anything read-only is
**noise**. In this repo's own largest transcript, reading alone is about 30% of the tool calls, edits
about 16%.
- **Milestones:** an edit or a new file (with its lines), a command run, a build or tests passing or
  failing, a plan, a subagent sent; and the session's own turn (what it asks, why it failed, what came
  back).
- **Noise:** reading, searching, listing, the web, pages, read-only tools, thinking, writing the
  answer.

**What other boards do:**
- **Claude Code's agent view:** one row a session (a state icon, the name, one summary line, an age),
  grouped by state; a blocked row's line is the question itself.
- **VS Code's Agents window:** the title over where it runs, +148 −6 and the age.
- **Linear:** "Searching" becomes "Searched" once it has a result, and an activity is replaced when
  the next arrives.
- **Xcode 26:** each edit a file card (+44 −1), and "Build Succeeded".
- **Apple's HIG for Live Activities:** update "only when new content is available", alert "only for
  essential updates", at most one interactive control.

**What power users need:** to scan many sessions, one row each, in an order that changes only when a
state does (already Fovea's rule); to approve in place; to jump to the session; the last meaningful
change and when it happened; and the keyboard (↑↓, Return).

## The drafts

All four share the same frame:
- **The bar's look.** Wings' black, hung from the notch on its 10 pt shoulders, SF Pro in white at its
  opacities.
- **The board's own wings.** "Hello, Ryan." (in the bar's word face) and the search sit beside the
  notch, at the menu bar's height. The sessions start right under the notch, with no header row.
  Where the name doesn't fit beside the notch, it's "Hello.".
- **No glow.** Nothing lights the board's foot (Oct 27, Ryan: "dont have the two small glows").
- **The pinned chats** are a strip of chips at the foot.
- **What a click, ↑↓ and Return do** is unchanged. The search, opened, is today's.

| Draft | What it is | Why | Costs |
|---|---|---|---|
| **Milestones** | Each session is a light, its title, and its **latest milestone** under it ("✎ Edited ShortcutRecorder.swift +12 −3", "✓ Tests passed", the question in amber). The **first in line** (what needs you most) shows its **last three**. Deny and Allow, or the time, at the right. 400 pt wide, five sessions in view | The research's pick. It changes only what a row's line means: from the step it's on to the last thing that mattered. Scans many, works from the keyboard | The first row is taller. The research had the hovered row grow instead; that moves the rows under the pointer, so the first in line grows and stays |
| **Ticker** | A line a session, as a menu: the light, the title, its latest milestone in a word or two (the glyph says the verb: "✓ Build passed", "✎ hero.md") and the time. A question is an **amber "Allow?"** that opens to Deny and Allow in place. 360 pt wide, six in view | The smallest: barely wider than the listening bar. The research's ticker idea kept as the question waiting in amber | Least said per session. With no milestone yet, it shows the time alone |
| **Threads** | Under each title, **what it did as marks along a thread**: an edit a tick as tall as its lines, a verdict a dot (green, red), a question an amber ring, a plan a small diamond; while it works, a breathing light at the thread's end. Its latest in words after it. 420 pt wide | The shape of the work at a glance, the most distinctive. You can tell a session that's edited a lot and tested from one still reading | Marks are small (the research asks for 8 pt targets if they become clickable). Draws how much it did, past the one line of activity the rules allow |
| **Focus** | **One session large:** its title and time, the agent and project, its last three milestones, its buttons (Allow, Stop, Retry, Open) and Open in its agent. The others are **chips** under it; resting on one brings it into focus. 400 × about 160 pt, within the HIG's 408 × 160 | The clearest view of one agent, and the most like a Mac's own expanded activity | Scanning many means moving along the chips |

## Departures

- **More than one line of activity.** Milestones' first row, Focus's three lines and Threads' marks
  go past AGENTS.md's "one line of current activity per task". Each needs an amendment if it ships.
- **The greeting's face.** "Hello, Ryan." is in the bar's word face, the system's (`BAR_DESIGNS.md`).

## Running them

- **Pictures:** `--design-shots notch <dir> --only board-` (each draft: the board with sessions and
  pins, pins only, nothing; Dark and Light), drawn off the screen.
- **Checked:** `--smoke`:
  - the milestone rule (an edit and two verdicts kept, the reading, the search and the thinking
    dropped);
  - each draft's width and black, and the sessions starting under the notch;
  - Milestones' first row up to three lines;
  - Focus following the pointer;
  - the search falling back to today's.
- **Code:** `FoveaV1/Sources/FoveaIsland/Feedback/BoardDesigns.swift`
  (`AgentLiveStep.milestone`, `WorkbenchModel.boardMilestones`); tokens in
  `WorkbenchTokens+Bar.swift` (`Boards`). The milestones come from the steps a session reports
  (`v2LiveSequence`, `v2Work`), the same that fold under an answer (`WHOLE_SESSION.md`).

## Sources

- [Arne Strickmann's post](https://x.com/arnestrickmann/status/2114787885589430730), Oct 26, and
  [Personal Agent Proxy](https://github.com/personalagentproxy/proxy)
  (`packages/docs/content/agents/mcp.mdx`, `api/src/mcp/tools.ts`)
- [Claude Code hooks](https://code.claude.com/docs/en/hooks), [Codex hooks](https://developers.openai.com/codex/hooks)
- [Apple HIG: Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities),
  [Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications)
- Claude Code's agent view, VS Code's Agents window, Linear's agent sessions, Warp, Xcode 26.3
