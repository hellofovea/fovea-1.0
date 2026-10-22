# Expanding a session: the whole session, what the agent did, and an outline of the requests

**What prompted this.** Two rounds of Yulun's feedback on Oct 7, about the expanded session in the
Notch Workbench.

- **Round one** asked for:
  - more space on both sides;
  - a size that holds the whole session's history;
  - at the right, a small bar like Notion's that marks every request, to jump between them;
  - space on both sides however many requests there are;
  - research on making it look more refined (高级).
- **Round two** changed it:
  - the expand button goes straight to that size;
  - the bar on the right lists only the person's requests;
  - the answers were too brief, with no evidence of what the agent did, so each exchange gets a
    section showing the tools it used and the files it edited, collapsed until opened;
  - the side margins were too large, so the panel is narrower and the answer's column a little
    wider.

**In the Notch Workbench** a session has two sizes, usual and expanded. Expanded is the whole
session.
- **The expand button** in the session's header, or **left ⌃**, switches between the two.
- **‹ at the header's left** (expanded) goes to the control board, every session on the Mac,
  however the session was opened. Yulun asked for this exit later on Oct 7.
- **Esc** comes back to the usual size, then closes.
- **The panel's Answer tab** has a "Session expanded" toggle.
- **Staged states:** "Session expanded" (four requests) and "Session expanded, many requests"
  (twelve). `--v2=whole` and `--v2=wholeLong` open on them.
- **Shots** (`Prototypes/shots`):
  - `workbench-v2-expanded`: one exchange;
  - `-expanded-session`: four exchanges;
  - `-expanded-work`: what the agent did, opened;
  - `-expanded-long`: twelve exchanges;
  - `-expanded-outline`: the outline's card.
  - `-expanded-exit`: ‹ pressed, the control board.

## Width: a narrower panel, a wider column

The words keep one centred column. The room left over goes to both sides, the way a page's text
column keeps its width in a wider window. The header (the agent, the title, the buttons) and its
rule keep the panel's edges.

| | Compact | Spacious |
|---|---|---|
| The panel (`V2.expandedWidth`) | 840 | 880 |
| The column (`V2.readingMeasure`) | 560 | 620 |
| Room each side | 140 | 130 |
| Characters a line, at the answer's size | about 89 (13.5 pt) | about 90 (15 pt) |

**Limits.** The panel keeps the shipping app's reading margins: at least 40 pt from the display's
sides and 16 pt above its foot.

**Round one compared with round two:**
- **Round one** used the shipping app's 960 pt panel with a 560 pt column: about 81 characters, and
  200 pt each side. Yulun found the sides too empty.
- **Round two** narrows the panel to 880 pt and widens the column to 620 pt. That is 90
  characters, the long end of Practical Typography's 45–90 (measured: SF Pro sets 6.9 pt a
  character at 15 pt, 6.3 at 13.5).
- The long end suits answers full of paths, symbols and code.

**The right margin** still holds the outline, about 60 pt clear of the words.

## The way out

Expanded, the header has three ways out:
- **‹ at its left goes to the control board.** This is the agents' panel, with every session on the
  Mac. It works however the session was opened: from the board, popped up by itself, or from a
  shortcut.
  - It is the board's own back button (from the board, at the usual size, it was already there),
    drawn as the header's other buttons are: a 28 pt circle with a quiet plate.
  - **The board stays open** until the person leaves it, as when it is opened with a click. The
    pointer is likely outside the board, where the expanded session was.
  - **The session they were reading drops off the board's Done:** read, it is no longer waiting for
    review, as when it is closed from the board.
  - **If nothing is left on the board,** the island rests instead. The Island never opens an empty
    panel.
- **The collapse button** (or Esc) comes back to the usual size.
- **✕** closes. From the board, it goes back to the board; otherwise the island rests.

## Height: as tall as the session

The panel is as tall as the whole session, down to the display's foot. Past that, the session
scrolls.
- **One exchange** expands to just its own height.
- **A long session** reaches the foot.

**From the top down:**
1. the header and its rule;
2. the history: every exchange, oldest first;
3. a rule like the header's;
4. what waits, the bar (Open in its app; Answer again or Stop) and the follow-up box;
5. the grab bar.

**Each exchange** is the request, what the agent did (folded), and the answer as the agent wrote it.
The current exchange also has its Open buttons for the files its answer links.

**Your words and the agent's** (Oct 8, `CREATURES.md`):
- **The request** sits on a quiet band (white 0.075, radius 12, the column's width) after a prompt
  chevron ›, as Claude Code and Codex print what you typed. It is never a bubble or off to one
  side.
- **The answer** stays open on the black, the agent's pet in the margin where it starts.

| | Compact | Spacious |
|---|---|---|
| A request (medium), on its band | 14.5 | 16 |
| A heading in an answer (semibold) | 14 | 16 |
| The answer | 13.5 | 15 |
| Between a request and its answer | 12 | 16 |
| Between exchanges (space, no rules) | 32 | 44 |

**It opens on the current exchange.** Like a conversation, it opens at the foot, with the earlier
exchanges above. If the current one alone is taller than the room, its request is brought to the
top. A new follow-up scrolls its request into view.

**The edges.** Scrolled, the words pass under the two rules, never into blank space. The HIG
(Scroll views) keeps scroll edge effects for content behind floating bars. A bar that doesn't float
gets a hard edge: a 0.5 pt rule, white at 0.12, the same as the header's. There are no gradients
(AGENTS.md).

## What the agent did, folded under each answer

**Folded,** above each answer, is one line: "Worked for 1 m 12 s · Edited 2 files ›". It names the
file when there is one ("· Edited NotchGeometryTests.swift"), and drops the part about files when
nothing was edited. Every exchange starts folded. Opening one leaves the others as they are.

**Opened,** behind a 1 pt rule (white 0.12), it shows the agent's steps in order, with what it said
between them. Each step is a row:
- **The glyph:** a document for a read, a magnifier for a search, a pencil for an edit, a hammer
  for a build, a seal for a test, a terminal for a command.
- **The tool, as a verb:** Read, Searched for, Edited, Created, Ran, Built with, Tested with, Used.
- **What it acted on:** a file in the text face; a command or a search pattern in code.
- **At the right, what came of it:**
  - an edit's lines, only the non-zero ones (+9, or +3 −1);
  - a command passing, or failing in red;
  - a search's matches ("3 files").

**What it said between steps** sits in its own rows (white 0.62), brighter than the verbs (0.55)
and dimmer than the answer (0.88). These are Claude's words before a `tool_use` and Codex's
`commentary` phase.

**Where it comes from.** Everything here is something the agents report, as the Oct 7 research
found (`FEEDBACK_2026-10-06.md`, #16):
- **Claude Code** (stream-json): each `tool_use` with its input. An edit's result carries
  `structuredPatch` and `gitDiff` line counts; a command's result carries `is_error`.
- **Codex** (app-server):
  - `commandExecution` items with their `commandActions` (read, search, listFiles) and exit codes;
  - `fileChange` diffs;
  - the commentary phase.
- **Sessions the person started elsewhere** need the hooks they agree to install (#17).

**Not shown:** a command's output, Claude's thinking, streamed text.

**The rules this changes.**
- **AGENTS.md** said the Island never shows "execution steps or logs", only one line of current
  activity and the agent's commentary folded under its answer. Yulun decided on Oct 7 that what the
  agent did may sit folded under each answer, steps included. AGENTS.md and AMENDMENTS.md now say
  so.
- **The dev team's rows** (灵动岛UI反馈.xlsx):
  - **Row 14** (the files edited): the devs said Claude Code doesn't report them while answering.
    For sessions Fovea starts it does, in each `tool_use`.
  - **Row 17** (the step's object): settled on Oct 7, one step at a time.
- **Still to settle with the devs:** Fovea's progress contract (`QuickAnswerProgress.swift`) drops
  each step's object and the edit's line counts today. It has to keep them.

**The samples answer more fully.** Each says what changed, where (with the files linked) and what
was checked. The session's twelve exchanges each have their own work: reads, searches, edits with
their lines, builds and tests.

## The outline: the person's requests only

This follows Notion's page-level table of contents: on the right of a page with two or more
headings, it follows the scroll. Hovered, it expands to every heading; a click goes to that heading.
Here the entries are the person's requests, never the headings in the agent's answers.

**At rest:**
- **Lines:** one 18 pt line per request, 2 pt thick, at most 8 pt apart, in the right margin
  12 pt in from the content's edge, vertically centred.
- **In view:** the request whose top has passed a line 96 pt under the rule is bright (white 0.92);
  the rest are 0.22.
- **Read to the end,** the last request that shows counts, because the last ones never reach the
  line.
- **When it shows:** from two requests up. A one-exchange session has none.

**Hovered**, it opens to a card listing every request; the one in view is semibold.
- **The card:** 280 pt wide, white 0.12 on the black, a 0.5 pt border, a soft shadow. It is
  concentric: a 14 pt radius with 6 pt padding, rows rounded 8.
- **Long requests** end in an ellipsis, and the whole request shows on hover.
- **A click** scrolls there with the resize spring. The request lands a margin below the rule.

**Many requests.**
- **The column keeps its width,** so the space on both sides stays.
- **The lines close up,** down to a point apart.
- **The card scrolls.**

**Kept from the Island's rules:**
- white at opacities on black, no gradients;
- no task counts;
- no model label in the session.

## Sources

- **Notion Help Center, "Columns, headings & dividers" → Table of contents.** The page-level
  setting appears on the right with two or more headings, follows the scroll, expands on hover to
  every heading, and a click goes to it.
- **Apple HIG, Scroll views → Scroll edge effects.** Use them only behind floating interface
  elements; they are not decorative.
- **Apple HIG, Live Activities.** Consistent, concentric margins. The island's height fits what is
  in it.
- **Practical Typography, "Line length".** 45–90 characters per line, including spaces.
- **What the agents report:** `FEEDBACK_2026-10-06.md` #16 ("Oct 7: what a session can show of its
  steps"), from code.claude.com/docs (headless, hooks, agent-sdk) and openai/codex
  `app-server-protocol`.
- **`SPACIOUS.md`.** The Spacious sizes the session already uses.

## Not done

- **The pulled-out window:** its current exchange has the new fold (it draws the same answer), but
  its earlier exchanges show only their answers.
- **The shipping app** (`Sources/Fovea`) is unchanged. This is the Workbench's prototype.

## Oct 21 (Ryan: "simpler is better")

No creature in the margin beside each answer. The margin stays; the answer is the only thing there.
