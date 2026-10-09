# The control board's pet

**What prompted this.** Two rounds of notes from Yulun on Oct 8.

**Round one.**
- **The expanded session:** it was hard to tell the person's requests from the agent's answers.
  They should be clearly told apart, but not the way a chatbot does it (bubbles, one side each, a
  "Message …" box).
- **The control board:** the teammates preferred Wings (the sessions along the top, in the notch's
  wings); Yulun liked Capsules for being unique and Badges for being solid. But Wings was hard to
  navigate, and none of the designs had an "aha". What feels generational is a dynamic avatar:
  small creatures that look busy, like OpenAI's dots, Meta's Muse, Grok Bot, or coucou's creature
  on the notch. The request: study the psychology and UX, look at coucou and other agent control
  panels, and redesign the board.

**Round two** (on the first creature, in the wings):
- **The wings are not the best place for them.** To choose a session you have to point at each
  pet; you can't tell which agent a session belongs to; and other layouts show every agent's
  progress better.
- **The notch pet is cool, but it looked like every other notch pet.**
- **Show the same pet in several designs of the notch,** to see how it fits each.

**In the Notch Workbench** (Board tab › Design):
- **The designs:** Pets · List, Pets · Capsules, Pets · Desk, Pets · Lanes, and round one's Pets ·
  Wings. `--stage=progress:petLanes` (or `petList`, `petCapsules`, `petDesk`, `creatures`) opens on
  one.
- **The pet at rest beside the notch:** the switch "Pet at rest beside the notch", on by default in
  the designs with pets.
- **Screenshots** in `Prototypes/shots`:
  - `pet-designs.png`, the designs side by side, and the pet at rest;
  - `fb-09-board-pet-*.png`, each design in the Workbench (and a session opened);
  - `creatures-sheet.png`, every pose over time;
  - `workbench-v2-expanded-*.png`, the expanded session.
- **Motion:**
  - `swift run FoveaWorkbench --record-pets pets.mp4` records the pet through the designs: at rest,
    the board opening on Lanes, the pets walking on as their plans get done, one finishing, Desk
    and an Allow, List, Capsules, closed again.
  - `--record-creatures creatures.mp4` records round one's Wings.
  - `--render-pets=<dir>` draws the designs side by side; `--render-creatures=<dir>` the poses.

**Research behind it** (three studies, Oct 8, in `research/creatures/`):
- `open-source-notch-creatures.md`: open-source notch apps and agent pets;
- `ai-avatars-and-agent-panels.md`: the AI avatars named above, and agent control panels beyond the
  notch;
- `psychology.md`: the psychology, with a risk register and a test plan.

The findings, and where they changed the design, are below.

## Amends

- **AGENT_PANEL.md, "No decoration: no mascots, carousels or sounds."** It stands for every other
  design. The pet is the exception, because it *is* the session's state glyph: it takes the place
  of the agent icon's ring and badge, and carries nothing that isn't state.
- **FEEDBACK_2026-10-06.md, round three:** "Illustration only where it carries state" and "Only
  running moves; color only for action." The pet keeps both:
  - at rest, only a working pet's agent spinner and a breath of well under a point move;
  - everything else moves once, for an event;
  - the only colours are amber (waiting on you) and coral (failed).
- **PRD §8, Resting:** "If an active-state affordance is necessary, use one subtle breathing
  point." In the designs with pets, that point grows into the pet of the session most in need, in a
  small black circle at the notch's right. It keeps the section's other rules: no count, no task
  details, it breathes, and Reduce Motion holds it still. Its colour is the pet's (white, amber,
  coral), not the accent palette. A prototype behind a switch, for the team's decision.

## The pet: the Lasso, alive

**Why it changed.** The first creature was the notch's capsule with two eyes and an antenna. It was
still a soft shape with two eyes, and that is what every notch pet is: coucou's Mochi, Notchi's
characters, Clawd, the pixel agents. Each is a mascot drawn for its own sake. Nothing in it was
Fovea's.

**What it is now.** Fovea's own mark, alive: the **Lasso**, the hand-drawn circle Fovea draws
around what you point at and draws while the agent thinks ("The orb is the Lasso", decided
Sept 30), with two eyes inside.
- **Hand-drawn:** a loop of 1.12 turns, a little uneven, overlapping where it closes. Each pet's
  loop has its own waver, the same every time for its session.
- **Its body is its progress.** A faint whole loop, and over it the bright stroke drawn as far as
  the agent has got through the plan it reported (Codex's `update_plan`, Claude's `TodoWrite`).
  Done, the loop closes. With no plan reported it shows a little and never pretends to progress
  (StarNet's rule: the board never claims what the agent didn't say). No counts (AGENTS.md).
- **The pen at the stroke's tip is the agent,** in its own working glyph: Claude Code's spinner
  frame by frame (· ✢ ✳ ✶ ✻ ✽), Codex's bullet.
- **The eyes** are on the pen while it works.

So it is told apart from the other notch pets three ways: it is the app's own mark, its body is a
progress ring, and its pen is its agent. It reads at 17 pt, the smallest it is drawn.

| State | The loop | The eyes, and when it moves |
|---|---|---|
| At work: reading, searching, writing, running | drawn as far as its plan has got, the pen at the tip | on the pen. **A new step:** the pen circles once where it is |
| Thinking | ″ | closed |
| Needs you | whole, amber | **one call** as it starts to wait (a wind-up, rising 12% larger), then held there, still. Looking up; in Wings, at the pointer |
| Done, not yet read | whole, closed | ahead; still |
| Failed | coral, as far as it got, the pen where it stopped | **none** (the persona drops); one short shake as it fails, then still |
| Stopped | dim, as far as it got | closed |
| Status unavailable | dashed, dim | closed, a still "z" |

**At rest, almost nothing moves:**
- a breath of well under a point, slower than 2.5 s, in one rhythm for every pet;
- each pet's own irregular blink;
- its agent's spinner at the pen.

**Each event is one gesture of half a second.** No pet is busy for show.

**Power and access:**
- 24 frames a second at most; nothing is drawn while its design is closed.
- A still pose with Reduce Motion and in screenshots.
- **State never rests on colour or motion alone:**
  - a loop part drawn, or closed;
  - a larger loop for waiting;
  - no eyes for a failure, a dashed loop and a "z" for asleep;
  - the words beside it in every design.

## One pet, five designs

**The rule for all of them:** every session is shown at once, with its agent's icon, its title and
what it is doing; nothing is behind a hover. The pet is the same in each; only where it stands
changes.

**List** (round three's rows, 400 pt; 460 Spacious):
- The pet leads each row, where the agent's icon was; the agent's icon sits by the title.
- The parts (Needs you, Done, Running, Status unavailable) are parted by a seam, as in Badges: the
  pet already says each one's state.
- Allow and Deny in place; how long at the right.
- The densest, and the most expected.

**Capsules** (round four's, the design Yulun found unique):
- Each session its own small island under the notch, its pet at the front, its agent's icon by
  the title.
- The one waiting on you is the tallest, amber, with Allow and Deny.

**Desk** (580 pt; 640 Spacious):
- The sessions as a team, four to a row, in the board's order: each pet at its desk.
- The agent's icon in the desk's top-left corner, how long at the right; the title under the pet,
  then what it is doing (on two lines), its question with Allow and Deny, or what it brought back.
- The one waiting on you is outlined in amber.
- ↑ and ↓ go a row, ← and → one along. Three rows show; past that it scrolls.
- The most "aha" of the five, and the tallest.

**Lanes** (560 pt; 620 Spacious):
- A lane each: the agent's icon, the title and what it is doing, over a track.
- The pet stands on its track as far as its plan has got, the way travelled brighter, the finish a
  tick at the end. A step of the plan done, it walks on.
- **Done:** at the finish. **Waiting on you:** amber where it stopped, Allow and Deny on its lane.
  **Failed:** coral where it stopped.
- **No plan reported:** the pet waits at the start of a dotted track. How far it has to go isn't
  known, and the board doesn't make it up.
- The design that best answers "how far along is everyone?".

**Wings** (round one, 600 pt): the pets alone in the notch's wings, the one under the pointer on a
stage below. Kept to compare. Round two's notes are about it: choosing means pointing at each pet,
and whose each is shows only on the stage.

**In a session:** its pet before its agent's icon in the header. In the expanded session, it
stands in the margin beside its answers (below).

**At rest, beside the notch:**
- A small black circle at the notch's right, the notch's height less 3 pt each side, 6 pt from it,
  holding the pet of the session most in need: waiting on you, then failed, then done, then
  running (Codex Pets' order); never one whose state can't be read.
- It is PRD §8's breathing point, grown into the pet. It is drawn the Dynamic Island's way of
  holding a second activity in its own circle (its detached minimal), rather than by widening the
  notch, as the other notch pets do.
- **Calm:** it breathes and blinks, its agent's spinner held still; it gestures only at a new
  step; waiting on you, it calls once, amber, and holds.
- **Pointing at it opens the board,** as the notch's own hover does; a click opens it and keeps it
  open. It goes into the notch while the board is open, and comes back out when it closes.
- Only in the designs with pets, and behind the panel's switch.

**Which to keep** is the open question. Measured against round two's notes:

| | Choose without pointing at each | Whose it is | Everyone's progress at once | Room |
|---|---|---|---|---|
| List | yes | the icon by the title | each pet's loop | the least |
| Capsules | yes | ″ | each pet's loop | as many capsules as sessions |
| Desk | yes | the icon in the corner | each pet's loop | the most |
| Lanes | yes | the icon by the title | the loops, and how far along each track | middling |
| Wings | no: the stage shows one | on the stage only | the loops, small | one band |

## The expanded session: your words and the agent's

**Your request** sits on a quiet band (white 0.075, the column's full width, radius 12), after a
prompt chevron ›.
- This is how Claude Code and Codex print what you typed: the coding-agent world, not a chat app.
- It is never a bubble: no tail, never pushed to one side, as wide as the answer.

**The agent's answer** stays open on the black.
- Its pet stands in the left margin where the answer starts, beside "Worked for …".
- At ease beside earlier answers; in its current pose beside the one now.
- Read down the margin, you see who spoke when.

**What changed:**
- The request is no longer a 20 pt title competing with the answer's headings. The band says
  "you", and the pet says "the agent".
- The outline at the right still lists the requests.

## The psychology, and what it changed

The research, in short. Evidence is strong where marked; weak or contested findings are flagged.

**What supports a pet:**
- **Simple shapes read as living agents when they move.** Heider & Simmel (1944), replicated in
  2019.
- **Agents with human-like traits get more trust and forgiveness.** Waytz, Heafner & Epley 2014;
  de Visser et al. 2016. Cute AI assistants get more tolerance when they fail (Lv et al. 2021).
- **Showing real work raises its perceived value** (the labor illusion, Buell & Norton 2011). It has
  been tested on consumer services, not yet on experts supervising agents.
- **Occupied waits feel shorter than empty ones** (Maister 1985).

**What it predicts will go wrong, and what we did about it:**
- **Motion onset captures attention, ongoing motion doesn't** (Abrams & Christ 2003), and a moving
  target among moving neighbours is hard to find.
  - So no pet loops: they rest, and each event is one short gesture.
  - "Needs you" is the single onset, then held still.
  - The others share one breath, so nothing competes with it.
- **Constant animation adds workload and is tuned out** (Burke 2005). The novelty fades by the second
  week (Kanda 2004). The design has to work in week three, when the pets are just the state
  glyphs.
- **Eyes pull attention by reflex** (Driver et al. 1999). So only the pet that needs you looks
  up at you; the others keep their eyes on their work.
- **A humanized face makes things worse when the person is already angry** (Crolic et al. 2022), and
  cuteness lowers perceived competence (Zebrowitz). So:
  - failures drop the persona (no eyes on a failure), and a question is always its words and its
    buttons beside the pet, never the pet alone;
  - the style is competent-cute (a hand-drawn line, mild, white ink);
  - done closes its loop rather than celebrating, so it never looks verified.
- **A sad creature makes people look away (Fish'n'Steps), and needy appeals raise the urge to quit**
  (De Freitas et al. 2025). So no pet suffers, escalates or misses you when ignored. No streaks,
  levels or pet deaths; a read session simply leaves the board.
- **Clippy failed by being unsolicited and impossible to dismiss.** The pets never speak, pop up
  or block, and the one at rest has a switch.

**Contested, so not relied on:**
- "Cute images make you more careful": Nittono 2012 did not replicate in two preregistered studies
  (Ziv & Fox 2022).
- The "watching eyes" effect.
- The Zeigarnik memory advantage. The urge to finish what's open does hold up.

## How to know it works

The psychology study proposes a three-week comparison: the chosen pet design against Sections or
Badges, switching weekly, the order counterbalanced. It measures:
- how fast "needs you" is answered;
- idle checks (hovers with no action) and reported distraction;
- trust calibration: are diffs still opened before accepting, as often as before?
- enjoyment and annoyance on days 2, 7 and 20.

Adopt the pet only if, at week three, the answer to "needs you" is no slower and idle checks no
higher than with the glyph designs, and trust is no worse calibrated. Enjoyment alone isn't
enough. The pet at rest is measured the same way, on and off.

## References and what we took

**Notch apps for coding agents and agent pets** (all read through their source):
- **coucou** (MIT code; the character © its author).
  - **Its features:** a tint and eye shape per state, a short entry move, eyes on the cursor, one
    creature per agent, and "done" clears after 5.2 s.
  - **We took:** eyes on the pointer (for the one waiting), an entry move per change.
  - **We didn't take:** the character, colour per state beyond amber and coral, gradients, a done
    that vanishes.
- **CodeIsland, Notchi, agent-notch, stanhoody/notchi, Clawd on Desk, Pixel Agents:**
  - a creature per session in a stable place;
  - done stays until seen;
  - load shown by behaviour, not a number;
  - a motion per kind of tool;
  - irregular blinks, a capped frame rate, still frames for Reduce Motion.
- **Licences:** Notchi, Open Island (GPL), Clawd on Desk (AGPL) and MioIsland (CC BY-NC) are
  copyleft or non-commercial, so no code from them.

**The avatars named:**
- **OpenAI's dots** (Sept 29, 2026): plush characters with tiny eyes and no mouth, partly inspired
  by Codex Pets. Names and looks tell agents apart; animated cues show work.
- **Codex Pets** (May 2026): Running, Needs input, Ready, Blocked, and the priority order the pet
  at rest and the wings use. Reduced motion shows a still frame.
- **Meta's Muse and its mascot Jolly** (Sept 8, 2026): its designer says the first UI drawn was a
  status pill answering "what is my agent doing right now?". The character came later, on that
  pill.
- **Grok Bot** (Aug 11, 2026): a flat shape whose two eyes and body carry six states. xAI rejected
  three animated dots as too little to tell working from stuck.

**Control panels:**
- Claude Code's agent view turns a blocked row into the agent's question.
- Devin separates waiting for an answer from waiting for approval.
- Linear has a stale state for an agent that goes quiet.
- Warp clears unread on visit and shows at most two alerts at once.

## Not done, for discussion

- **Which design to keep,** and whether the pet at rest stays (the table above). The pet at rest
  changes the quiet resting notch, so it needs Yulun's and the team's decision.
- **Two kinds of waiting.** A question and a permission could differ (Devin; Vibe Kanban's raised
  hand). Today both are the same amber call.
- **The data.** The loop, the lanes and the gestures use what the agents already report: the plan
  and each step. Fovea's progress contract has to keep them (#16, still to settle with the dev
  team). A session that reports no plan never walks its lane.
- **A setting to keep the pets still,** beyond Reduce Motion.
- **Out of scope here:** the pulled-out window keeps its icons, and the shipping app
  (`Sources/Fovea`) is unchanged.
