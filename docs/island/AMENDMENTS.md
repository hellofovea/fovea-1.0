# Dynamic Island — PRD amendments (2026-09-08)

These decisions were made after using the running Island and override the corresponding
lines in `FOVEA_DYNAMIC_ISLAND_PRD.md`. The PRD's own precedence rule ("behavior,
hierarchy, copy, state logic" over mockups) still holds for everything not listed here.

## §8 Hover list — rows and count
- Each row shows, left to right: **destination icon · Chat name (primary) · one line of
  current activity (secondary) · state label (right)**, with a small accent dot on
  `Working`. The activity line is a single human summary ("Editing the folder picker",
  "Build failed · 2 errors"), never steps or logs.
- Show **up to five rows**; more scroll within the panel (was four).

## §8 Hover intent (new)
- Hovering opens the list only after a short **dwell (~150 ms)** on the notch itself.
  Brushing across, or approaching from below and stopping near the island, must not open
  it. Chin growth under a still pointer must not open it. After a collapse the pointer
  must leave the notch before another hover can open the list. (Implemented as an explicit
  pointer-zone tracker measured against the island's target geometry.)

## §10 Transcribing — the "didn't catch that" state
- When nothing was recognized, the Flowing Bar shows a single **Retry** and a two-second
  bar draining along its bottom edge. When it empties, the Island rests. Retry starts a
  **new listening session** with the same referents (it does not replay silence).
- Voice states (Listening, Transcribing, this state) are **exactly the notch's width** and
  grow only downward.

## §11 Attachments — no `+N`
- Every referent is shown; rows **wrap** when one is full (no `+N` chip). Hovering a
  referent grows a **larger preview downward beneath the stack**.

## §11 Chat selector — a browsable flow
- Opening the pill shows **Recent · Last 24 hours** (up to ten Chats across every
  destination, with relative times), plus **New Chat** and **Search Chats**.
  - New Chat → choose an AI (Claude Code recommended, Codex, Cursor) → choose a context
    folder (No Folder, then a scrollable list of `~/…` folders, five visible).
  - Search Chats → choose an AI → a search field whose results are **scoped to that one
    destination** (title, folder, "Active 9h ago").
  - Choosing anything returns to the recent panel with the pill updated, so the choice can
    be double-checked; the panel stays open until Send. Back / Esc step out one level.
- This replaces "Opening the selector shows only Recommended / Original / two recent / New
  Chat" and "Do not expose the user's full Chat history." Search is still bounded: it lists
  one destination at a time and never dumps everything.

## §11 Send — acknowledge in the Agent list
- On Send, show the **Agent list with the new task highlighted for about 3.5 seconds**
  (longer while the pointer or focus is inside), then collapse. This replaces "collapse the
  Island on send."

## §14 Motion
- The whole Island morphs on **critically damped springs (no bounce)**; content crossfades
  with opacity + a light blur + a small scale from the top, on the same path in and out.
  The expanded→resting collapse is one continuous morph (the key hand-back is deferred
  until the morph finishes, so the panel is never hidden and re-shown mid-animation). This
  follows the master build prompt §10 and the project's "no bounce, anywhere" rule; the
  animations.dev course notes (`docs/motion/NOTES.md`) agree that a daily-driver surface
  should not overshoot.

## Input — the fn shortcut and the emoji picker
- VoiceFlow is `fn`, Quick Answer is `fn ⌃`, press-to-toggle. While Fovea runs, a bare fn
  tap is swallowed by an event tap so macOS does not open the emoji picker; fn used as a
  modifier for another key (fn+←, fn+F5) is unaffected. If the tap cannot be installed, the
  Shortcuts page offers to set "Press 🌐 key to → Do Nothing" instead.

## Dispatch Version 2 — one flow for Dispatch and Quick actions (2026-10-03, workbench prototype)
Agreed in discussion; prototyped in the Notch Workbench (`docs/island/DISPATCH_V2.md`). Until
it ships, it overrides nothing above; these lines say which rules it changes.
- **One flow.** Dispatch and Quick Answer become one request flow with no mode: the result's
  shape (an answer, a draft, data, a finished task) comes from what the agent returns, not
  from the key pressed. Every request is a session on the control board; the default agent's
  sessions are its Quick answers, titled by the question.
- **Keys.** **fn⌃** starts a new request, always (and, pressed again, forwards it on). **fn**
  asks more in the session whose result is on screen; everywhere else fn stays Voiceflow's
  dictation. Pressed again, either key ends the session: Voiceflow transcribes and pastes;
  fn⌃ transcribes, then goes to Choose chat. **Left Option**, clicked, turns capture on in
  the voice bar (clicked again, off; held, on while held): a drag takes a region, a click a
  passage's text, a click a file; **clicked twice**, it takes the whole screen. The voice bar is the aura, as Dispatch's and Quick
  actions'; **Transcribing** is the same aura filling the bar's edge as a progress bar.
- **Where it goes.** Until routing exists, the island suggests up to three chats with a plain
  reason each (chips under Dispatch's chat pill), the first in the pill. **Nothing sends by
  itself**: a chip or ↑↓ changes the pill, the send button, Return or fn⌃ sends, and left ⌃
  opens every chat by agent and project, as Dispatch's expanded view. Each
  outcome is kept **raw** as a routing label (kept the first, picked another, went to the
  list), opt-in, with the request's screenshots and words. A model that learns one person's
  habits from these would be an inferred profile, which AGENTS.md forbids: that needs its own
  decision.
- **What the agent is producing.** A session may show **its screen**: the app it works in, as
  it looks (the file it edits with the change marked, the command and the line that matters,
  the page and the passage it reads, the draft being written, the calendar it checks), live
  while it works and holding its result once done. Replaced as it moves on: never a log,
  never its steps.
- **Results in the Island.** Every session's result may show in the Island, rewritten short
  to be read at a glance: the outcome in one sentence first, then what fits it (a few
  points, the terms of what was asked about, rows of data, a draft, what it made) and what
  needs the person's eyes; the full reply stays in the agent's app. This widens the Quick
  Answer exception to "a remote control, not a display".
- **After Send.** The control board shows a moment (about 3 s), then the island rests. The
  board holds only sessions running or done and not yet opened (Ready for review, on top). An
  answer that comes quickly (within about 8 s) opens by itself as the session's expanded chat;
  slower work waits on the board. Any session opens to its expanded chat (the request, the
  response, its screen); a grab bar pulls a chat out of the notch into a window that can go
  anywhere or tuck into a side of the screen. A pulled-out chat has a box to ask more in that
  session, whenever (it need not wait for the session to finish), and only ✕ in its corner: it closes the window, stopping the session if it is still
  at work.
- **The hover.** The pointer near the notch (on it, or a little beside or below it) opens the
  control board; leaving it closes it, and closes a session opened from it. This widens "a
  dwell on the notch itself".
- **Shape.** Its open shapes are 660 pt wide, stretching to both sides of the notch, content
  16 pt inside the island's body. At rest, nothing beside the notch.
- **Provider icons.** Quick answers carry Fovea's own mark, never a provider's.

## Oct 6 feedback (2026-10-06)

The dev team's review and Yulun's answers, in three rounds the same day. `FEEDBACK_2026-10-06.md`
has each point, what the devs proposed and why; the Notch Workbench shows each under
**Feedback · Oct 6**. These win over the PRD and over the Dispatch Version 2 lines above.

- **Model and thinking effort.** Choose chat has a pill beside the chat pill: "Auto", or the model
  and effort chosen ("Sonnet 5 · High"). It opens a sheet under the row with the chat's agent's
  models, then the efforts the model takes; Auto is first in each and stays the default. This
  replaces PRD §12's "not exposed as a recurring Island control", and §13's and AGENTS.md's "no
  model in Quick Answer". Provider icons stay out of quick answers.
- **One stack in Choose chat.** The referents sit as one stack, as on the voice bar. Under the
  pointer it fans into a row; a click looks closer.
- **Errors on the island, in English.** Every voice error shows on the island, never in a toast.
  There are three moments:
  - as the bar opens: the microphone;
  - inside the listening bar, which keeps listening: Screen Recording off, an image over 20 MB;
  - after the words went: everything else.
  
  The notice has a glyph in its tone's color, a title, one line, at most one action, and ✕ in the
  ring of the time left: 2.5 s for information, 4 s for a warning, 8 s with an action, paused under
  the pointer.
- **The keys on a voice bar.**
  - **Option** is the highlighter, in the accent color the person chose in Fovea. The pointer
    itself turns that color (an arrow, nothing drawn above it). A drag across text marks the words;
    a click marks a paragraph or a file. The marks stay on the screen while
    the session lasts, and what was marked joins the stack. One press, one highlight.
  - **⌘** takes screenshots: one press, one region; two presses, the whole screen.
  - Text, files and screenshots share one stack.
- **The recording limit.** Ten minutes. In the last minute the bar grows a few points and settles
  (no bounce), and counts down at its right. The last ten seconds are amber. At the limit it stops
  as fn would.
- **Where the words go.** The notch follows the pointer across displays, and the words go to the
  window under the pointer; Voiceflow and Dispatch keep the same rule. While dictating, the field
  they'll go to shows a blinking caret in the accent color. There is no box round it.
- **After pasting.** No "Delivered" badge. The words land in the field on the selection's blue,
  which fades, and the notch leaves 0.45 s later.
- **The control board lists every session on the Mac** (round three).
  - It is 400 pt wide, with two-line rows led by the agent's icon. The title is semibold; the line
    under it is what the agent reports: the question (amber), why it failed, the answer's first
    sentence, the project, or when it was last active.
  - On the right: Allow and Deny in place, the turning ring and the time (Stop under the pointer),
    or how long ago it finished.
  - Rows are parted by state, in the hover list's order: Needs you (questions, then failures), Done,
    Running, Status unavailable. The last is dimmed: a gray icon, nothing moving.
  - Two designs are under comparison: **Sections**, with a glyph and a word heading each part, and
    **Badges**, with the state on each icon's corner. Sections is recommended.
  - No counts, chips, model names, focus pane, agent screens, activity line or progress card.
  - This replaces "What the agent is producing", the board's focus and its thumbnails above.
- **A session opened.**
  - **While it works:** its request, then one line: the ring, Working, and the time it has run.
  - **Done:** the agent's commentary folded into "Worked for 11 s ›", the answer as written
    (Markdown, no layout laid over it), and **Open …** buttons for what it made.
  - **Under it, the bar:** Open in the agent's app, and Answer again (its menu picks another
    model), or Stop while it works.
  - **Under the bar:** a box to ask more.
  
  There is no state word, time, model label or key hint in the session. This replaces "Results in
  the Island" above, and applies to the pulled-out window too.
- **Titles.** A new chat or quick answer is named by a small model from its first request. A chosen
  chat keeps its name.
- **Reviewing the words is a setting** (Settings › Voice & Capture), on by default. When it is off:
  - the voice bar keeps the notch's width, with a plain settings icon at its right (not an
    agent's mark);
  - a click opens under it, at Dispatch's width, the suggestions, every chat (Dispatch's rail),
    then the model and effort; the bar's stack moves to the left and the icon to the right;
  - the request goes when the voice stops, and the board shows it on its way.
- **The queue.** A message sent while a session works waits under its response, with **Send now**
  and ✕, and holds (**Resume**) while the session waits on the person or has failed. This replaces
  "the session takes the new message at once" above.

## The agent's steps (2026-10-07)

While a session works, its working line, and the board's line for it, shows one step at a time:
the step and its object as Claude Code and Codex report them. Each new step replaces the last. When
a step ends, an edit shows its lines (+N −M) and a command shows passed or failed. There is no
streamed text, no thinking text, and no command output while it runs. This replaces #16's "kind of
step only" (`FEEDBACK_2026-10-06.md`), and fits AGENTS.md's "one line of current activity per
task".

## The control board, round four (2026-10-06, under comparison)

The board can be drawn in six designs: Sections, Badges, Focus, Capsules, Wings and Split.
`FEEDBACK_2026-10-06.md` describes each and the apps it comes from. Until one is chosen, the rules
above (sections, two-line rows) describe Sections, the default.

## The Native design (2026-10-09, under comparison)

A second tab in the Workbench, Original · Native, draws every Voiceflow and Dispatch state in the
app's and the onboarding's language. `NATIVE.md` has the reasons and how it's built; the research
behind it is in `research/apple-native/`.

**What it amends, in its tab only:**
- **PRD §2.7 and §6** (a black surface, no glassmorphism), and the Oct 6 decision that the island
  is black:
  - the island is Liquid Glass in the Mac's appearance: the bars, the bands, the pet at rest, and
    what drops below;
  - only the hardware notch stays black, and, when an app is full screen, the band the island
    hangs from;
  - what drops below is attached (one glass shape hanging from the top edge, Original's outline;
    the default) or floating (a panel 8 pt under the notch), by the sidebar's switch.
- **"Every Island neutral is white at an opacity on black":** the glass uses the system's ink.
- **Colors:**
  - the Fovea accent for primary actions, the chosen chip, progress and links;
  - systemOrange, systemRed and systemGreen for needs you, failed and done;
  - Voiceflow's waveform and progress white, never a color (the glass's ink on light glass).
- **One word:** an approval's Allow becomes the action's own verb (Run Tests; Run where there's
  little room), approved by Yulun on Oct 9.

**Everything else holds:** every state's words, controls and order are the same as in Original;
no gradients; SF Pro; no counts.

## The control board's pet (2026-10-08, under comparison)

Five designs share one pet: Pets · List, Pets · Capsules, Pets · Desk, Pets · Lanes, and round
one's Pets · Wings. `CREATURES.md` has the reasons, the research and the sources.

**What it amends:**
- **AGENT_PANEL.md's "No decoration: no mascots":** it stands for every other design. The pet is
  the exception, because it *is* the session's state glyph.
- **Round three's rules** ("Illustration only where it carries state"; "Only running moves; color
  only for action") still hold.
- **PRD §8, Resting** ("one subtle breathing point"): in the designs with pets, the point grows into
  the pet of the session most in need, in a small black circle at the notch's right. Still no
  count and no task details; it breathes, and Reduce Motion holds it still; its colour is the
  pet's, not the accent palette. A prototype behind a switch, for the team's decision.

**The pet:**
- **Fovea's Lasso with two eyes:** the hand-drawn loop drawn as far as its agent has got through
  the plan it reported, closed once done; the pen at its tip is its agent's working glyph.
- **Waiting on the person:** whole, amber, a little larger.
- **Failed:** coral where it stopped, with no eyes. **Asleep** (its state can't be read): dashed,
  eyes closed, a "z".
- **No counts:** the loop is the only measure; with no plan reported it shows a little and never
  claims more.

**It stays calm:**
- **At rest:** only the agent's spinner and a breath under a point, one rhythm for all.
- **Events:** each a single gesture of half a second (a new step, finishing, failing).
- **Waiting on you:** the pet calls once, then holds still.
- **When ignored:** nothing escalates or suffers.
- **Hidden:** nothing moves while its design is closed; Reduce Motion gives still poses.

**The designs:** every session at once, its agent's icon, its title and what it is doing beside its
pet; nothing behind a hover.
- **List:** the board's rows, each led by its pet; the parts parted by a seam.
- **Capsules:** each session its own small island under the notch, its pet at the front.
- **Desk:** four to a row, each pet at its desk with its name under it; ↑↓ a row, ←→ one along.
- **Lanes:** each pet on its own track as far as its plan has got, at the finish once done; with no
  plan reported, at the start of a dotted track.
- **Wings** (round one): the pets in the notch's wings, the one under the pointer on a stage.

## Your words and the agent's (2026-10-08)

In the expanded session, the person's request sits on a quiet band after a prompt chevron, the
column's full width, as the agents' command lines print what was typed. It is never a bubble or
off to one side. The agent's answer stays open on the black, its pet in the margin where it
starts. This replaces the request as a 20 pt title (`WHOLE_SESSION.md`).

## Expanding an answer (2026-10-06)

Every session's answer can grow to the shipping app's reading size. The shipping app's answer
surface has three sizes: summary, full and reading (`QuickAnswerIslandDensity`, readingMaxWidth
960, side margin 40). The Workbench maps them onto the board, the session and the expanded
answer.
- **The board** shows each answer's first sentence: the summary.
- **The session** is the full panel, its answer scrolling past its height.
- **Expanded,** the panel is as wide as 960 pt, staying 40 pt from the display's sides, and as
  tall as the answer needs, down to the display's foot. A long answer reads without scrolling;
  its question may take 4 lines.

There are three ways in:
- **The expand button** in the session's header, beside ✕. It is shown once there is an answer.
- **Left ⌃** on a session: the shipping app's expand key.
- **On the board,** a Done row under the pointer shows the expand button where its time was, and
  opens that answer expanded straight away.

Esc steps back to the usual size first, then closes.

## Expanding a session (2026-10-07, workbench prototype)

Expanding a session shows the whole session. This replaces "Expanding an answer" above.
`WHOLE_SESSION.md` has the numbers, the reasons and the sources.
- **Sizes:** two, usual and expanded. The expand button (or left ⌃) switches; Esc comes back,
  then closes. The board's expand button opens a session this way.
- **The way out to the board:** expanded, ‹ at the header's left goes to the control board however
  the session was opened. The board stays until the person leaves it. With nothing left on the
  board, the island rests.
- **Expanded:**
  - **Width:** 880 pt wide (840 Compact), 40 pt from the display's sides at the least: narrower
    than the shipping app's 960.
  - **Height:** as tall as the session, down to the display's foot. Past that it scrolls, opened on
    the current exchange.
  - **The words** keep one centred column of about 90 characters (620 pt, 560 Compact), with
    130–140 pt on each side.
- **Every exchange,** oldest first: its request as a title, what the agent did (folded), its answer
  as written.
- **The outline,** after Notion's, sits in the right margin from two requests up. It lists the
  person's requests only.
  - At rest: a line per request, the one in view bright.
  - Hovered: a card of the requests; a click goes there.
  - No counts.
- **The edges:** rules above and below the history. What scrolls passes under them; no
  gradients.

## What the agent did, folded under each answer (2026-10-07)

This amends AGENTS.md's "never shows execution steps or logs" for this folded section, and
replaces #11's fold of commentary alone.
- **Folded:** each answer has one line, "Worked for 1 m 12 s · Edited 2 files ›".
- **Opened:** the agent's steps in order. Each step shows:
  - the tool, as a verb;
  - what it acted on;
  - what came of it: an edit's lines, a command passing or failing, a search's matches.
- **Between the steps:** what the agent said along the way.
- **Folded until the person opens it,** in every exchange.
- **Only what the agents report** (Claude Code's `tool_use` and its results; Codex's items): no
  command output, no thinking text, no streamed text.
- **Fovea's progress contract** has to keep each step's object and an edit's line counts (#16, still
  to settle with the dev team).

## Spacious (2026-10-06, a prototype under comparison)

The open panels get more room and the Mac's own sizes. `SPACIOUS.md` has the numbers, the reasons
and the sources; the Workbench's Density switch compares it with Compact.
- **Text and controls:**
  - text 13 pt and up (11 at the least); the answer at 15 on 5 pt line spacing;
  - controls 28 pt; ✕ and back in 28 pt circles.
- **Space:** a 22 pt margin inside the island's body; 16 pt between blocks.
- **Corners:** concentric. Space parts the session's blocks instead of rules.
- **Widths:** the control board, the notice and Paste not found are 460 pt wide (from 400).
  Dispatch's panels keep 660.
- **Unchanged:** the resting notch and the voice bar.
