# Dispatch Version 2: one flow for Dispatch and Quick actions

Dispatch and Quick actions merged into one flow, every stage leading to the next. The entry is
the same for both. The result differs:
- an answer opens by itself;
- long work waits beside the notch until it is done.

What comes back is shown as **the agent's screen or what it made**, not as a list of text.

Workbench prototype, Notch › **Dispatch Version 2** (beside Voiceflow; the old Dispatch and
Quick actions tabs are gone from the panel). How both flows work, for a coding agent:
`FLOWS.md`.
- **Panel states:** Silent notch, Voice input, Transcribing, Choose chat, Control board,
  Expanded chat, Pulled out. Each is live from where it starts.
- **Request menu:** a formula in a paper, the calendar, an email draft, a code change.
- **Play:** runs the whole flow hands off.

The rules it changes are in `AMENDMENTS.md` ("Dispatch Version 2").

Code:
- `Prototypes/FoveaWorkbench/WorkbenchModel+DispatchV2.swift`: the flow, the sample requests and
  their scripts, the keys.
- `WorkbenchModel+Attach.swift`: capturing a passage's text and files, drawn as cards.
- `MockDesktop/DispatchV2.swift`: the layouts and views.
- `MockDesktop/AgentScreens.swift`: the agents' screens.
- `WorkbenchModel+Panel.swift`: the hover that opens the control board.
- `WorkbenchTokens.V2`: every number below.

Checks: `--smoke` walks the whole flow (`dispatchV2`), the aura (`voiceGlow`) and the hover
(`v2Hover`). Shots: `workbench-v2-*`, `workbench-glow-*`.

## The flow

The keys:

| Key | Does |
|---|---|
| **fn** | Voiceflow: press to start, again to stop; it transcribes and pastes. On an expanded chat, it asks more in that session. |
| **fn⌃** | A new request: press to start, again to end; it transcribes, then Choose chat. |
| **Left Option, click** | On a voice bar: capture mode on; another click, off. Elsewhere it is the app's. |
| **Left Option, held** | On a voice bar: capture mode while held. |
| **Left Option, double click** | On a voice bar: the whole screen, attached. |
| **Left ⌃** | On Choose chat: every chat, and folded again. |
| **Return** | On Choose chat: sends. |
| **Esc** | Steps out one level; on the voice bar or Transcribing it drops the request. |

**The pointer near the notch** (on it, or within 14 pt beside or below it) opens the control
board after a short dwell (0.12 s, then the first still moment, at most 0.3 s); a brush across
doesn't. It stays while the pointer is on the board or 8 pt round it, and **closes 0.1 s after
the pointer leaves**. A session opened from that board closes the same way. The board opened
from the panel's radio stays until Esc. The pointer is watched wherever the workbench is among
the apps, as a real notch is.

1. **fn⌃: voice input.** The bar is **the aura**, the same glow as Dispatch's and Quick actions'
   voice bars (not Voiceflow's waveform), with the referent stack beside it: its fly-in, fan,
   expand and look-closer.
2. **Left Option: capture.** A **click** of the key turns capture mode on, and it stays on
   until another click (or Esc). Holding the key instead keeps it on only while held. In
   capture mode:
   - a **drag** takes a region;
   - a **click on a passage** takes its text;
   - a **click on a file** on the desktop takes the file.

   All three ride the same stack. A **double click** of the key (two clicks, each under 0.3 s,
   the second within 0.35 s) takes the whole screen, **with nothing of Fovea on it**: the island,
   its pulled-out chats and capture mode's marks are hidden while it is taken, as a real capture
   leaves out its own app's windows.
3. **fn⌃ again: Transcribing.** The session ends and what was said is transcribed: the aura
   stays and fills the bar's edge from the left as a **progress bar**, with "Transcribing" over
   it. It takes 1.4 s here. What was taken is kept.
4. **Then Choose chat**, laid out as Dispatch has it (the old row of key hints under it is gone):
   - **The request.**
   - **What was taken:** click one to look closer.
   - **The chat in a pill:** the first suggestion, chosen.
   - **The send button:** a white disc with ↑.
   - **Suggested chats:** chips under the pill; a click puts one in the pill.
   - **Every chat:** left ⌃ or the pill's chevron opens them below, as Dispatch's expanded view
     does: the agents' rail, then projects, then a project's chats. A chat goes into the pill.

   **It waits for the person.** Nothing sends by itself and there is no countdown: the send
   button, fn⌃ or Return sends. (Play, in the panel, stands in for the person and sends after
   1.6 s.)
5. **Sent: the control board shows for 3 s**, longer while the pointer is on it. The new session
   is in focus, its screen live. Then the island rests. There is no resting state beside the
   notch: the wings didn't say anything worth their room.
6. **A quick answer opens by itself.** If it arrived within 8 s of sending, the person is likely
   still waiting, so its expanded chat pops up. It holds 12 s, longer while the pointer is on it.
   Slower work waits on the board, **Ready for review**, on top.
7. **fn on an expanded chat** asks more in that session (it transcribes, then sends there, no
   Choose chat); **fn⌃** is always a new request.

### The control board

The board keeps only what matters now: sessions **running** (or waiting on the person), and
sessions **done but not yet opened**. Opening a session takes it off the board once it is done.
The demo shows six sample sessions besides your own, so it holds seven or eight.

- **Left: the focus.** Agent, name, project and state, then **its screen at 16:10, live**. Under
  it, Stop, Answer or Retry, and Open or Review.
- **Right, two sections:**
  - **Ready for review** on top, with what each did;
  - **Running**, those that need the person first.
  - Each session has a small picture of its screen.
- **Hover and click:** resting on a session for 120 ms puts it in focus; a click opens its
  expanded chat.

### The expanded chat

Its layout follows the reference the owner gave, not its look:
- **Header:** the agent, the session (or "Fovea" for a quick answer) and a project badge, with ✕.
- **The request**, as asked.
- **The response:** the outcome in a sentence, then what fits it (a formula's terms, rows of
  data, numbered points, a draft, the files it touched, what needs your eyes). **The agent's
  screen** sits beside it.
- **Status line:** Complete or Working, how long it took, and "Open in <agent>".
- **Bottom bar:** the keys (esc, fn Ask more, fn⌃ New) and Copy answer.

**A grab bar at the bottom edge pulls the chat out of the notch:**
- Dragged down past 28 pt, the chat follows the pointer as a window.
- Let go, it stays there, and the notch goes back to the board, so another chat can be pulled
  out.
- A window can be dragged anywhere by its header. Dragged with the pointer to the left or right
  side of the screen, it tucks into a tab on that side; a click on the tab brings it back out.
- A window shows the request, the agent's screen (live while it works) and the response.
- **At its foot, a box to ask more** in that session: type and press Return (or the ↑).
  **Send whenever:** done or still at work, the session takes the new message at once and
  works on it in the window, live; the notch is left alone. (fn asks more by voice the same
  way.)
- **Make it bigger or smaller:** drag any of its four edges or four corners, as a Mac window's
  (Oct 24, Ryan: "by dragging all four sides of that chat. So it behaves like any other Mac OS
  apps"), or pinch on the trackpad. The side dragged follows the pointer and the side across
  stays; the pointer is the Mac's resize pointer for that side. The window resizes (70–240 %, the
  screen the last limit) and its words reflow (Oct 11: they no longer scale). The bottom-right
  grip is gone.
- **Every exchange stays in it.** With follow-ups, the window lists each question and what came
  back (one the person moved on from says so), the newest coming into view as it is asked.
  **A rail at its right edge, after Notion's outline,** has a short line per question, the one
  in view bright; hovered, it opens to the questions, and a click goes to one.
- **Its corner has only ✕**, no state mark: it closes the window, and **a session still at
  work is stopped with it** (it can't be left running with nowhere to see it).

### What the person decides

- **The mode:** nothing to decide. The result's shape comes from what returns.
- **Where it goes:** the default in the pill, a suggestion chip, or every chat. Each outcome is
  kept raw as a **routing label**: kept the first, picked the second or third, or browsed. The share where the first was kept is routing's first-try rate.
- **When to look:** a quick answer comes to you; slower work waits on the board, on top.

## Shapes and numbers

The island stretches sideways, as coucou, boring.notch and Atoll do (open panels at 640–770 pt).

- **Width:** every open shape is **660 pt**; only the height changes.
- **Margins:** content sits **16 pt inside the island's body on every side**. The body starts
  where the ears end, 19 pt in, so nothing leans.

| | Value |
|---|---|
| Content width | 590 |
| Choose chat | Request 14 medium, two lines at most; the taken things 40 tall; pill 32 tall, at most 250 wide; send button 32, its ring 40; chips 26 |
| Board | Focus 336 (screen 336 × 210), a 20 pt gap, list 234 (rows 50 tall: a 64 pt thumbnail, the name and the state) |
| Expanded chat | Header 40; request 15 semibold; the response beside a 268 × 167.5 screen, scrolling past 280; status 34; bar 36; grab bar 40 × 5 |
| Transcribing | The aura, clipped to the progress; 1.4 s |
| Pulled out | Windows 340 × 468 at 70–240 %, radius 16, the follow-up box 34 tall, its sides 8 wide and its corners 16 square, half outside it; tabs 34 × 76; a side catches within 12 pt |
| The rail | A 2 pt line per question, 9–17 pt long by its length, 7 apart, white 0.9 in view and 0.24 else; a 22 pt gutter; hovered, a 220 pt card of 26 pt rows |
| Motion | Open 0.34 s, resize 0.3, close 0.24, all critically damped; content in 0.2 s ease-out-quint, 80 ms behind the shape |

## The agents' screens

Each session has a screen: the app it works in, drawn at 480 × 300 and scaled to the focus, a
tile or a result.

| Agent at | Its screen | Its result |
|---|---|---|
| Calendar | The afternoon, the time now as a red line | The events, the next one first |
| Mail | The compose window, the draft typed in | The draft, whole |
| A paper | The page, the formula boxed | A note under the formula: what it means |
| Editing | The editor: removed line struck, the new one typed in | The diff |
| A terminal | The prompt and the line that matters, typed in as it comes | ✓ and its result |
| A browser | The page, the passage it reads highlighted | The page it made |

- **While it works:** a **LIVE** tag at the top right and its pointer moving. Only the focus
  moves; the list's thumbnails are still.
- **Once done:** the same frame holds the result.
- **Rules:** this follows the amendment ("what it is producing, as it looks; never a log").
  Colour inside a screen is the app's own (Calendar's event colours, an editor's diff); the
  island around it stays white on black.

## Research

- **coucou** (`github.com/Louis-CFM/coucou`, cloned to `~/Desktop/things/coucou`; I read its spec
  and design captures):
  - a fixed open width;
  - the focus large, the other sessions to the side;
  - wings at rest;
  - the edited file's real lines as the live view;
  - a result as a bold line, with data in rows.
  - Not built: its live features install hooks into `~/.claude/settings.json`.
- **Live agent screens:**
  - Anthropic computer use, Operator / ChatGPT agent, Devin's "Follow", Manus's Computer,
    Browserbase's live view: a 16:10 frame, a moving pointer or highlight, the frame becoming
    the result when done.
  - The owner's reference: a notch panel with the request in a pill and a LIVE screenshot of
    the agent's screen.
- **Visual results:**
  - OpenAI's Apps SDK cards: at most 2 actions, no scrolling inside.
  - Raycast's detail pane.
  - Apple widgets: 16 pt margins, "balance information density".
  - Where there is width, the visual and the text sit side by side with shared edges.
- **Wings:**
  - Apple Live Activities: leading and trailing similarly sized, read as one piece of
    information, an avatar leading and a timer or ring trailing.
  - Atoll: wings on the closed notch.
- **Boards:**
  - Equal cells, labels under the images.
  - Inner radius = outer radius − padding (WWDC25 356).
  - Previews follow focus after a short dwell.

## Not built (to decide)

- **Routing itself.** The suggestions are samples, and the label log isn't written anywhere yet.
- **Real screens.** These are drawn: an agent's own screenshots, or its app's state, would replace
  them.
- **Taking over a live screen** (Operator's "Take control").
- **Telling the person a slow task is done** other than the board's Ready for review: with the
  wings gone, nothing at rest says so.
- **Real transcription** for fn⌃: the progress here is timed, not the recognizer's.
- **The board itself pulled around**, and follow-ups from the board: still being worked out.
- **Insert:** typing a draft into the frontmost app.
- **Dragging a result out** beside what it is about.
- **Math rendering** for a real formula.

## Oct 21 (Ryan: "simpler is better")

- **Titles:** a new chat's name shows as it is sent. It no longer waits 1.6 s in a grey "naming" ink and crossfades in.
- **The step line:** a running session moves through its steps once, as it works, and stays on its last until the answer comes; it no longer loops through them on a 0.9 s tick, and a new step crossfades in (it pushed the last up and out). A session with no start (a sample) shows its last step.
- **The last minute:** the countdown fades in; the bar no longer grows 6 pt and springs back.
- **A pulled-out chat:** one edge (the glass's own rim), a lighter and closer shadow (12 pt, was 22). Its tucked tab no longer widens under the pointer and has one edge and a 6 pt shadow. The outline's and the turn rail's cards fade in with a lighter shadow (8 pt), no scale.
- **Header buttons** (✕, back, expand) no longer bounce their glyph as the pointer comes.
