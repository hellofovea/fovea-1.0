# Choose chat (Dispatch)

Before a request goes, the island shows it: the words, the referents, and the chat Fovea's routing
picked, with Send. The person may change the chat and never has to.

## Oct 27, in 1.0: one list of chats, the words editable, and the model in two lines

Ryan: "we can't see which folder a chat belongs to … if there are more than five, they must scroll
up and down", and "there should be a much easier way to pick the reasoning effort. Currently, it
takes three lines … we could apply this slider only to the thinking effort, while keeping the model
and approval settings on a single line. Generally, simplify the interface."

**Every chat is one list.**
- A two-column version (folders beside chats) was built first. Then Ryan: "we cant access the folder
  information and what chats are contained in the folder … we can only access all the chats, but
  nothing about the folder."
- So the browser (Choose chat's, and the route sheet's) shows a New chat, then the agent's chats,
  the latest first, four at a time, then "Show more". That fits six rows without scrolling.
- A search looks in the titles.
- There's no level to go back from, so Esc closes it.
- This replaces "An agent's icon shows its projects" and "A project shows its chats" below.

**The words are editable on the notch** (Ryan, Oct 27):
- A click puts the caret in Choose chat's words. The notch takes the keys without taking the app
  in front.
- Under the pointer a field shows round them, and while editing a field with the accent's ring.
  Both sit outside the words' box, so the words don't move.
- Return sends what's there, ⌥Return starts a new line, and Esc stops editing.
- The words are what the session asks (`editV2Request`, `V2RequestEditor`).

**The model sheet is two lines**, not three:
- **The model and the approvals on one line**, each a pop-up button that opens the Mac's own menu:
  Auto, then the models, with one that can't be picked dimmed and saying why ("GPT-5 Pro — Not in
  your plan").
- **How hard it thinks: a slider** over the model's efforts, least to most. The model's default
  is ticked under its stop, and the value reads "High default". Picking the default goes back to
  Auto, so it follows the model. A model with no efforts (Haiku) says so instead.
- **Why not one slider for the model and the effort, as ChatGPT's:**
  - Claude Code and Codex take them separately (`--model` and `--effort`, or
    `model_reasoning_effort`), and Claude Code's own `/model` puts an effort slider under the model
    list.
  - Anthropic's guidance treats them as two different fixes: a larger model for a hard problem,
    more effort when it skipped steps.
  - The models' efforts differ (Haiku has none, GPT-5 Codex has Extra High), so one scale would
    have to hide which model runs.
- **Code:** `V2ChatBrowser` and `V2RequestEditor` (`MockDesktop/DispatchV2.swift`);
  `V2ModelSheet`, `V2SheetMenu` and `V2EffortSlider` (`Feedback/V2FeedbackViews.swift`).

**Claude Code's chats from the Claude app** (fovea-mac, Oct 27):
- In the dev team's app, only the chat Fovea itself started (with `claude -p --session-id`) can be
  picked.
- Every Claude Code session read from `~/.claude/projects` is marked owner unknown, and the
  default Available list keeps only sessions that can be picked. That hides the Claude app's chats
  and the terminal's alike.
- 1.0's chats are samples, so there is nothing to fix here. The cause and the fix are in
  `docs/v1/V1.md`.

Opening it shows a **rail**: the agents' icons, with the active agent's **projects** under them.
A project opens to **all its chats**, scrolling, with a New chat first. The decisions so far:
- The rail was chosen over Sections, Columns and Stacks (2026-09-30).
- The selection is shown the way a macOS menu shows it, not with the Lasso: "just use the
  normal emphasize or highlight".
- The icons are each agent's own app icon.
- Each agent has about twenty chats, organized into projects: "if you click on the app's icon …
  projects; when they click on a project … all of the chats".
- Edge cases from fovea-mac's picker and Claude Code are staged.

This is a workbench prototype, Notch › Dispatch. Three radios open it:
- **Choose chat**: closed.
- **Expanded view of chats**: the rail and the projects.
- **Chats in a project**: one project's chats.

An **Edge case** menu stages the cases below: fifteen of them, covering every fovea-mac
workbench scenario that touches choosing a chat or sending to it.

Left ⌃, pressed alone, opens and closes the rail; that is the product's key, which the radios
stand in for.

Code:
- `Prototypes/FoveaWorkbench/WorkbenchModel+Chat.swift`: levels, choosing, keys.
- `ChatBook.swift`: the sample chats, projects and edge cases.
- `MockDesktop/ChooseChat.swift`: `ChatLayout` and the views.
- `Resources/Agents`: the icons and where they came from.
- Numbers: `WorkbenchTokens.Chat`.

## What the specs already decide (followed)

From PRD §11–12, AMENDMENTS and Core's `ChatRoute`:
- **The row:** the request, then the referents, then a compact pill (destination icon · chat name
  · chevron), then a small round Send.
- **The prediction:** shown at once. Changing it is optional and never blocks sending. When
  confidence is low, routing falls back to a New Chat.
- **While routing resolves:** the pill keeps its width and breathes "Choosing chat", every
  0.9 s down to 0.45. The answer then crossfades in place.
- **Esc:** steps out one level.
- **Motion:** critically damped springs. Highlights that keys or the pointer move never animate.
- **Destination icons** may keep their brand colors (§2), and must be official artwork (§6).

**Where this goes further, at the user's request:**
- **Grouping:** the amendment's selector is one flat "Recent · Last 24 hours" list. Here the
  chats are grouped by agent on a rail.
- **Volume:** an agent has about twenty chats, and opening "All" scrolls through every one of
  them.

## The highlight

**Research** (sources at the end): almost every picker marks two things differently.
- **The current value** (here, the chat the request goes to) gets a glyph, usually a
  checkmark:
  - macOS menus, Claude Desktop ("The entry in use has a check mark next to it");
  - Radix `ItemIndicator`, the shadcn combobox, Linear.
- **The cursor** (the row the keyboard or the pointer is on) gets a fill. It moves at once,
  starting on the current value. When the pointer enters a row it moves there (cmdk, Radix).
- **HIG:** option lists "highlight a row only briefly before adding a visual indicator (such as
  a checkmark)".
- **On pure black a fill can't carry state alone:**
  - white 0.12 on #000 is 1.27:1;
  - WCAG 1.4.11 asks 3:1 for a selected state's indicator;
  - the first white that passes is 0.35.
  - So the fill is the cursor, and the chosen chat's mark is a checkmark at 0.85: 12:1 on the
    fill.

**Treatment ("menu grammar")**
- **The chosen chat:** a 10 pt semibold checkmark at white 0.85, in a 14 pt leading column that
  every row keeps, as in a macOS menu. The row's text never changes weight; that would reflow it.
- **The cursor:** a 7 pt-radius fill at white 0.12 under the keyboard's or the pointer's row. It
  never animates, starts on the chosen chat when the rail opens, and stays when the pointer leaves.
- **The active agent:** a 30×24 tab at white 0.12 behind its icon, as a segmented control's
  selected segment.
  - It slides to the next agent on a 0.22 s spring with no bounce (a 0.1 s fade under Reduce
    Motion).
  - The other icons rest at 0.6 opacity, 0.85 under the pointer, with a fainter tab (0.06).
- **Viewing another agent:** a 3 pt dot at 0.85 under the agent whose chat is chosen, so it's
  clear where the request will go.
- **Fovea's pick:** no label by default; the checkmark is Fovea's pick until the person moves it.
  Once they choose another chat, the predicted row says "Suggested" (11.5 at 0.4).
  - This follows Apple's "useful default selection" and Linear's care "not to blur the line"
    between a suggestion and the person's own choice.
  - No sparkle and no colored badge.
- **Increase Contrast:** the fills step up to 0.2 with a 1 pt keyline at 0.4 (3.66:1), and idle
  icons rise to 0.8.

**Removed (2026-09-30):**
- The Lasso as the selection mark: the loop round the chosen chat and round the active agent.
- The Lasso as routing's trace and its catch round the picked agent.
- The Sections, Columns and Stacks variations.

## The agents' icons

Each agent shows its own **app icon**, full color, never tinted, from `Resources/Agents`:

| Agent | Icon | Source |
|---|---|---|
| Claude Code | The Claude app icon: an ivory spark on terracotta | fovea-mac `Brand/icon-claude-256.png` (from the signed Claude app) |
| Codex | The Codex icon for dark surfaces: the blue blossom-cloud with `>_` on a dark tile | `icon-codex-dark-color.png` in the signed Codex app, `/Applications/ChatGPT.app` (`com.openai.codex`) |
| Cursor | The Cursor app icon: the cube on a dark tile | fovea-mac `Brand/icon-cursor-256.png` |
| Grok Bot | The Grok Bot app icon: a white bot face on a dark tile | `icon.icns` in the signed `/Applications/Grok Bot.app` (`com.anysphere.sand`) |

**Why the Codex icon looked wrong.** lobe-icons' `codex.svg` is a cloud with `>_` cut out,
written with compressed arcs that macOS's SVG renderer misreads. It came out as a lumpy blob, and
even drawn correctly a one-color Codex mark is a blob at 16 pt.

**What OpenAI ships.** The Codex app merged into ChatGPT on 2026-07-09:
- `ChatGPT.app` now has Codex's bundle id, and its default app icon is the OpenAI blossom.
- So the system's icon for it would be the blossom, which is the wrong icon here. The app's own
  Codex icon file is the right one.

**Why app icons, against one-color marks:**
- They are what each agent looks like in the Dock.
- fovea-mac made the same choice (its `Brand/README.md`).
- The PRD lets destination icons keep their colors.

The tension: the Island otherwise uses no gradients, and the Codex and Grok Bot icons have them.
One-color marks (the spark, the cube, the Grok slash) remain the alternative if that rule wins.

**Grok Bot**, not Grok: the agent on this Mac is Grok Bot, SpaceXAI and Cursor's desktop agent
(August 2026). The Grok chatbot's black-hole mark would be the wrong icon for it.

## Projects and chats

There are twenty chats per agent (`ChatBook.swift`). Each runs in a **project**, the folder its
agent works in, as Claude Code keeps sessions by working directory. The projects are this one
(`app-ui-v1`, where the referents come from) and others (fovea-mac, FoveaGaze, Futuro,
hellofovea).

**An agent's icon shows its projects.**
- **Order:** this project first, then by their latest chat.
- **A project's row:**
  - a dot in the check column if the chosen chat is in it;
  - its name, and "this project" for the referents';
  - on the right: "Needs you" in amber if one of its chats waits on the person, then how many
    chats, how long ago the latest was active, and a chevron;
  - its help text is its path.
- **Where it starts:** the cursor starts on the chosen chat's project. Clicking an agent's icon
  always shows its projects, even from a project's chats.

**A project shows its chats** under a row back to the projects. The row back carries the
project's name and path; a click on it, or Esc, steps back.
- **New chat first:** a New chat in that project and agent. The pill then reads "New chat ·
  app-ui-v1".
- **Then the chats,** most recent first, scrolling in up to eight rows.

**What a chat's row says.** These fields come from fovea-mac's destination picker (its
availability states) and from Claude Code's session list (name, time, branch):
- a checkmark if it is the chosen chat;
- its title (an untitled chat shows its first words, in italics);
- on the right: "Suggested" on Fovea's pick once another is chosen, its branch when not the main
  one, then its state, or how long ago it was active.

**States** (fovea-mac's availability, in Fovea's words):

| State | Row | Can be chosen | What sending does |
|---|---|---|---|
| Open | its age | yes | goes in at once |
| Working | a dot and "Working", white 0.62 | yes | runs after the current turn (it queues) |
| Ready | its age | yes | resumes the chat, then runs |
| Needs you | "Needs you" in the Island's amber; the title at 0.4 | no | it waits on a permission prompt, a question or a plan to approve; answer it there first |
| Unavailable | the reason, e.g. "Worktree removed", "Runs on the web", "In use in another window"; the title at 0.4 | no | Fovea can't deliver to it from this Mac |
| Can't continue here | "Can't continue here" and ↗, which opens it in its own app (the island rests) | no | Fovea can't confirm it may write to it (it lives in another app's window, e.g. Claude's Code tab); fovea-mac's `externalOwnerUnknown` |

A row that can't be chosen still takes the cursor, and its help text says why. A click on it does
nothing.

## Claude Code's edge cases

From Claude Code's docs (sessions, CLI reference, Remote Control, deep links, Agent SDK) and
fovea-mac's picker. The sample has a row for each case the chooser must show.

| Case | What happens | In the sample |
|---|---|---|
| **Working (mid-turn)** | A message sent now waits for the turn to end | "Choose chat rail" |
| **Waiting on the person**: a permission prompt, an AskUserQuestion, a plan to approve | The message would sit behind it; nothing runs until it is answered where the session runs | "Paste not found countdown", Needs you |
| **Closed** | It resumes (`claude --resume <id>`) when the request is sent | most rows |
| **Another branch** | It works, but its context assumes that branch | "Island motion springs", feat/motion |
| **Its worktree removed** | Resuming works, but git and the files are gone | "Agent list rows", Worktree removed |
| **Another project** than the referents' | Paths in the request may not resolve | "fovea-mac", "FoveaGaze"… on the right |
| **Same title in two projects** | Two different sessions, told apart by project | "Notch ears match the menu bar" in app-ui-v1 and fovea-mac |
| **Same title in one project** (fovea-mac's `pickerSameName`) | Two sessions, told apart by branch and age; choosing one carries its own id | "Referent stack expansion": 1h on main, 2d on feat/stack |
| **Held by another app** (fovea-mac's `externalOwnerUnknown`, `noControl`) | Fovea can't confirm it may write; it offers to open it in its app | "Quick Answer layout" in Claude ↗; Codex's "CI cache keys", in use in another window |
| **Untitled** | The title is the first prompt | "why does the ear clip at 2x", italic |
| **Runs on the web** (claude.ai/code, cloud) | Not a local session; Fovea can't send to it from here | "Move CI to cloud runners" |

**Not listed:**
- Headless (`-p`), Agent SDK and `/loop` sessions: Claude Code's own picker hides them.
- Subagent sidechains: they end with their parent.

**Not modeled yet:**
- context nearly full (the next turn compacts it);
- very old sessions (cleaned up after 30 days by default);
- a session open in two places;
- sessions from another Mac.

## Edge cases (Dispatch › Edge case)

Anything that stands between the request and its chat is said in **one notice** under the request's
row: a glyph, a line or two, and at most two buttons (the island's gray capsules). It works like
the app's send-failure line with Retry (PRD §11):
- **Tones:** information is white 0.62, the person's turn is the Island's Needs you amber, and a
  failure is its Failed red.
- **Send:** dims, with its reason in its help, whenever there's no chat that can take the request.

**The menu stages each case**, grouped as fovea-mac's workbench groups its own:

| Group | Case | What the island does |
|---|---|---|
| Routing | **Usual** | Picks the open "Notch ears" chat in this project |
| | **Fovea isn't sure** | Picks nothing. It asks instead. |
| | | • The pill reads "Choose a chat" with a question mark. |
| | | • The notice reads "Fovea isn't sure where this goes. Is it one of these?" |
| | | • Under it, its guesses: the same title in two projects, Codex's geometry tests, and a New chat here, each with its agent's icon and where it is. |
| | | • ↑↓ and Return, or a click, take one, and Send can. ↓ past the last opens all the chats. |
| | **Routing failed** | "Choose a chat" with the Failed mark; the notice reads "Fovea couldn't pick a chat for this", with Try again and Choose another |
| The chosen chat | **Answering (queues)** | Send can; the notice says the agent is answering and the request goes in after this turn (fovea-mac's `queued`, `busySteerable`) |
| | **Waits for approval** | "Needs you" in the pill. The notice names the chat and the agent, with "Open Claude Code" (where the approval is) and Choose another. Send waits (`approval`, `approvalPending`) |
| | **Asked you a question** | The same, worded as a question (`userInput`) |
| | **Was closed** | A moment after routing picks it, the chat is closed in Claude Code. "Choose a chat"; the notice names it, with Choose another |
| | **Claude Desktop too old** | The chat is open in a Claude Desktop too old to take the request. Send waits; "Continue in Terminal" is offered, never taken silently (`handoffDesktopTooOld`). Once chosen, the pill adds "· Terminal" |
| The chats | **Still loading** | The other agents' chats are still being read: "Reading Codex's chats…" with a spinner for 1.6 s, then their projects. The pick's own agent is ready (`historyLoading`) |
| | **Change while open** | A second after the list opens, a new chat arrives at the top of this project and two chats change state. Rows keep their identities, so the highlight and the scroll stay put (`historyNewContent`, `historyRefresh`) |
| | **An agent isn't set up** | Fovea has no connection to Cursor: its connector is off, or (as on this Mac) Cursor isn't installed. Cursor's icon is faint; its projects give way to "Fovea isn't set up for Cursor. It can't see Cursor's chats or send to them yet. Set it up in Settings › Connectors." (`providerDisabled`) |
| The request | **Long request** | Past three lines it scrolls within them, so it never pushes the row down (`longQuestion`) |
| | **Many screenshots, one missing** | Seven referents wrap in rows before the pill (never "+N"). One couldn't be read: it shows as a card with ⚠ and won't be sent (`attachments`, `queueMessageMissing`) |
| | **Screenshots, no words** | A quiet line, "No words: the screenshots go on their own." Send can (`queueMessageImages`) |
| Sending | **Sending fails** | After Send, a spinner, then the notice "Couldn't send: Claude Code didn't open …", with Try again (it's sent once, never twice) and Choose another (`failed`, `handoffOpenFailed`) |
| | **Sent, not confirmed** | The notice reads "Sent …, not confirmed yet. Fovea won't send it twice", with Check again. Send waits (`unconfirmed`) |

**"Fovea isn't sure" goes against the PRD.** PRD §12 says that when confidence is low, routing should
pick a New Chat rather than make the person choose. The user asked for the opposite: Fovea should
ask, and say it isn't sure. The New chat stays among the guesses.

**Also handled, without a menu entry:**
- **The pointer and the highlight:** the highlight follows the pointer only when the pointer
  moves. Rows that move under a still pointer (a chat arriving, a list scrolling to the chosen
  chat, a refresh) don't take it (`historyRefresh`).
- **Late answers:** routing's late answer never replaces a chat the person already picked
  (`sessionSwitch`). It doesn't move the rail the person is browsing either.
- **Same titles:** Send carries the chosen chat's own id (`pickerSameName`).
- **Chats in the sample that can't be chosen** (`pickerBlocked`, `readOnly`, `noControl`):
  - "Read only" and "In use in another window";
  - "Can't continue here", with ↗ to open it in its own app;
  - "Worktree removed" and "Runs on the web".

**All of fovea-mac's workbench scenarios**, and where each went:

| Scenario | Here |
|---|---|
| `idle`, `preparing`, `streaming`, `completed` (an answer's life) | Not here. Dispatch never shows an answer (AGENTS.md: "a remote control, not a display"). After Send, the agent's progress is its Agent task (Working / Needs you / Complete / Failed) in the hover list. A chosen chat that is mid-answer is **Answering (queues)** |
| `queued` | **Answering (queues)**. Cancelling, jumping and pausing the queue come after sending, in the agent's own app |
| `approval` | **Waits for approval** |
| `userInput` | **Asked you a question** |
| `failed` | **Sending fails** |
| `unconfirmed` | **Sent, not confirmed** |
| `readOnly` | A "Read only" chat in the sample, which can't be chosen |
| `noControl` | An "In use in another window" chat in the sample, which can't be chosen |
| `queueMessageLong` | **Long request** |
| `queueMessageImages` | **Screenshots, no words** |
| `queueMessageMissing` | **Many screenshots, one missing** |
| `queueMessagePreview` | The row itself: the words and the screenshots, together, before Send |
| `longQuestion` | **Long request** |
| `longAnswer`, `multiTurn` | Not here: no answers or past turns are shown in Dispatch |
| `attachments` | **Many screenshots, one missing** |
| `historyLoading` | **Still loading** |
| `historyNewContent`, `historyRefresh` | **Change while open**, and the pointer rule |
| `pickerSameName` | The same-titled pair in the sample |
| `pickerBlocked` | The chats in the sample that can't be chosen, each saying why; **An agent isn't set up** |
| `sessionSwitch` | Routing's late answer never replaces the person's pick |
| `backendCard`, `backendCardStreaming` | Not here: Fovea's own one-turn answers belong to Quick Answer, not to sending to an agent |
| `handoff` | "Continue in Terminal" in **Claude Desktop too old**; choosing between Claude CLI and Desktop otherwise happens after sending |
| `handoffDesktopTooOld` | **Claude Desktop too old** |
| `handedOff` | Not here: a chat already handed to Claude Desktop is "Can't continue here", with ↗ |
| `handoffOpenFailed` | **Sending fails** (the chat didn't open; Try again is idempotent) |

**Delivery** (for the real thing):
- `claude -p --resume <id>` appends to that session.
- The Agent SDK's `resume` does the same, and takes image blocks.
- Claude Code's `claude-cli://open` deep link only prefills a new session; it can't resume one.
- Remote Control reaches a running session.
- Fovea should re-check a chat's state just before sending, as fovea-mac's picker does.

## The Sentence (Oct 27)

Ryan: "the design is just mediocre. not bad, but really boring and not innovative at all … go online and do some research on some creative, artsy, but useful ways of structuring the prompt, attachment, chat choosing button, effort choosing button, and send button. i think the suggested chats can go into the choose chat button."

**What was built.** Three designs went beside today's to compare: Sentence; Dial (how hard it thinks as a ring of stops round Send); and Ticket (a boarding pass, the chat and the effort on a stub at the right).

**Ryan's choice:** "i want sentence. delete others." Choose chat is now the Sentence (`MockDesktop/ChooseChatSentence.swift`).

- **Request:** set larger, at 17 pt regular, on up to three lines, still editable in place.
- **Sentence:** a hairline, then one line that reads as a sentence: *[what was taken] To [chat] · thinking [hard]*, then **Send ↵** in the accent. Its words are the controls, bold with a dotted rule in the accent.
  - **The chat** opens the suggestions as chips, then every chat by agent. The Suggested row under the panel is gone.
  - **The effort** opens the model, the approvals and the effort slider.
- **Effort words:** these say what you get rather than a level, because "Low" next to a model reads as low quality: briefly, it through, hard, harder, hardest. On Auto it reads **default** (Ryan: "dont have the default named \"as needed\", go with just \"default\"").
- **Keys:** ↑↓ still step through the suggestions, ⌃ opens every chat, and Return sends. After Send, where it's going (or why it didn't go) takes a row under the sentence.
- **Why it's useful:** you said a sentence, and it answers with one that can be read at a glance. The pills and the chip row are gone.
- **References:** Apple Shortcuts' parameter summaries; mad-libs forms.

**Considered, not built:**

- **Chat tabs** on the panel's top edge: attached, that edge is the notch.
- **An envelope and postmark.**
- **A console strip** of labelled controls.
- **A receipt** listing the payload.
- **Dragging Send onto a chat.**

## Keys and motion

- **Closed:**
  - Return sends; ↓ or left ⌃ opens; Esc lets the request go.
  - fn starts Voiceflow afresh, without these referents.
- **Opened:**
  - ↑↓ move the cursor through every row, the unchoosable ones and the row back included.
  - ←→ change agent, which shows its projects.
  - Return opens a project, or chooses a chat.
  - ⌘Return sends to the cursor's chat.
  - Esc steps back: from a project's chats to the projects, from the projects to closed.
- **Choosing:** the check moves at once; 0.25 s later the island closes with the chat in the pill,
  as a menu item blinks before its menu closes.
- **Springs, all critically damped:**
  - Choose chat opens on 0.3 s and closes on 0.22 s.
  - Each level grows on 0.32 s and folds on 0.26 s.
  - The rail's rows come in over 0.16 s once there is room.
- **Changing agent:** another agent's projects take the rows in place; nothing slides but the
  tab.
- **Send:** rests the island. The post-send Agent list (AMENDMENTS) is not built here.

## Seeing it

- **Panel:** Notch › Dispatch › Choose chat, Expanded view of chats, Chats in a project, and
  the Edge case menu.
- **Snapshots:** `--snapshot shots --only chat` renders:
  - `workbench-choose-chat`;
  - `workbench-chats-projects`, Claude Code's projects;
  - `workbench-chats-project`, app-ui-v1's chats;
  - `workbench-chats-projects-codex`, with the dot under Claude Code;
  - `workbench-chat-case-<case>`, one for each edge case.
- **Smoke:** `--smoke` covers:
  - every icon bundled;
  - routing's pick, the referents and the pill;
  - projects, this one first, the cursor on the chosen chat's;
  - a project's chats, a New chat first, the row back;
  - the same-titled pair, and the chats that can't be chosen;
  - choosing by click and by keys, → to Codex's projects, a New chat;
  - the icon always showing projects;
  - Esc a level at a time, left ⌃, Return to send;
  - each edge case, its notice, its buttons and Send;
  - referents carried from Voiceflow;
  - the waveform still centered.

## Sources

- **HIG:**
  [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables),
  [Menus](https://developer.apple.com/design/human-interface-guidelines/menus),
  [Pop-up buttons](https://developer.apple.com/design/human-interface-guidelines/pop-up-buttons),
  [Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls),
  [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- **WCAG:**
  [non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html),
  [focus appearance](https://www.w3.org/WAI/WCAG22/Understanding/focus-appearance.html)
- **Pickers:** [cmdk](https://github.com/pacocoursey/cmdk),
  [Radix Select](https://www.radix-ui.com/primitives/docs/components/select),
  [Claude Desktop models](https://claude.com/docs/government/desktop/models),
  [Linear Triage Intelligence](https://linear.app/now/how-we-built-triage-intelligence)
- **Motion:** [Emil Kowalski's animation standards](https://github.com/emilkowalski/skills/blob/main/skills/review-animations/STANDARDS.md)
- **Claude Code:** [sessions](https://code.claude.com/docs/en/sessions.md),
  [CLI reference](https://code.claude.com/docs/en/cli-reference.md),
  [Remote Control](https://code.claude.com/docs/en/remote-control.md),
  [deep links](https://code.claude.com/docs/en/deep-links.md),
  [Agent SDK sessions](https://code.claude.com/docs/en/agent-sdk/sessions.md)
- **Codex in ChatGPT:**
  [OpenAI community reply](https://community.openai.com/t/feedback-distinguish-the-codex-and-chatgpt-classic-icons-more-clearly/1393191/2)
- **Grok Bot:** [DataCamp](https://www.datacamp.com/blog/grok-bot)
- **Brand pages:** [Cursor brand](https://cursor.com/brand),
  [Anthropic press kit](https://www.anthropic.com/press-kit)
- **Reference:** fovea-mac's destination picker (`QuickAnswerDestinationAvailability`, `Brand/README.md`)
