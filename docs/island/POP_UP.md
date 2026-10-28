# A session pops up (Oct 26)

Ryan, Oct 26: "vibe island pops up when the agent needs approval/work is done. do that for ours as
well." Vibe Island's notch expands with Allow and Deny when Claude Code asks for permission
(Deny ⌘N, Allow ⌘Y, a diff of what it would change), and a session's row says "Done — click to
jump" when it finishes.

## What it does

- **When.** A session pops out of the notch by itself in three cases:
  - it stops to ask (an approval or a question);
  - it fails;
  - it finishes, and took longer than a quick answer. A quick answer still opens itself whole,
    as before.
- **What it shows:**
  - a line in the state's color: "Claude Code needs you", "Codex is done", "Claude Code couldn't
    finish";
  - under it, the session's row as the board draws it: the icon, the title, what it asks (Allow
    and Deny, or the action's own verb, in place) or its answer's first line;
- **Its look.** The board's glass, as wide as the board, attached or floating as the panels are
  (Oct 27, Ryan: "they should also suit the new notch design"; it was Wings' black). No glow at its
  foot.
- **How long it stays:**
  - done: 6 s;
  - needing you: 18 s;
  - neither goes while the pointer is on it;
  - once answered (Allowed, Denied), it goes 1.2 s later.
- **What a click, Esc or a pinned chat does:**
  - A click on the row opens the session.
  - Esc puts it away; the session stays on the board, Ready for review.
- **When it doesn't pop up:**
  - while the notch is in use (listening, Choose chat, the board, a session);
  - in the first run;
  - with "Show answers when they come back" off.

## Running it

- **Staged:** `--demo alert:needsYou|done|failed`.
- **Pictures:** `--design-shots notch <dir> --only alert`.
- **Checked:** `--smoke` (8 checks: each kind pops up, Allow then gone, Esc, a click opens it,
  never while in use).
- **Code:** `FoveaV1/Sources/FoveaIsland/Feedback/V2Alert.swift`; the `v2Alert` state.
