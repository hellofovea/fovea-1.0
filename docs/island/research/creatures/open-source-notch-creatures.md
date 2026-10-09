# Creatures on the notch: open-source references for Fovea's agent board

Research date: 8 Oct 2026. GitHub was read through the `gh` CLI: READMEs, and source files fetched through the contents API. Nothing was cloned, installed or run. Web pages were read with the gstack browse binary. Star counts and dates come from the GitHub API on this date.

**Legend:** **(R)** read in source, README or official docs · **(S)** seen in a screenshot I took of the project's site or media · **(I)** my inference or general knowledge, not checked in source.

Screenshots in this folder: `notchi-site.png` (Notchi's Clawd-like sprite), `coucou-claude-code.png` (Mochi with the "working" badge), `coucou-demo1.png` (Mochi dropping into the notch), `coucou-site.png` (Mochi in the iPhone Live Activity).

---

## 0. The short version: ideas to borrow

1. **The state words have converged, and OpenAI has published a priority order.** The ChatGPT/Codex desktop **Pets** feature has four statuses: *Running*, *Needs input*, *Ready* (finished, with unread activity) and *Blocked* (failed). With several chats, the pet shows the most urgent one, in this order: Needs input > Blocked > Ready > Running (R, official docs). These are the same four states as Fovea's Agent tasks (Needs you / Failed / Complete-unread / Working).
2. **One creature, many agents (coucou, omarchy-agent-notch).** In the collapsed notch, the focused agent's creature sits big on the left ear and up to 4 other agents sit as 12 pt minis in a 2×2 grid on the right ear. In the open island, the focus card is on the left and a grid of creature pills is on the right. Tapping a pill swaps the focus, with a "blip" sound and a spring animation (R).
3. **The creature moves; the badge says what is wrong.** coucou gives every state its own eye shape (pill, wide, flat, happy arcs, tired, closed, spiral), a small corner badge (three pulsing dots, !, ?, a coloured dot) and a short entry move: a hop for approval, a head-shake for error, a full roll plus sparks for done (R).
4. **Rotate through agents in a single slot (CodeIsland).** When space allows only one creature, it cycles through the non-idle sessions every 5 s, most urgent first, and jumps straight to a session that becomes more urgent. Each tool has its own creature species, and they cross-fade over 0.3 s (R).
5. **"Finished since you last looked" (agent-notch).** Each agent has its own slot. Its mascot walks while it works and turns into a sparkling green blob when it finishes. The blob stays until you focus a terminal (R). By contrast, coucou drops "finished" after 5.2 s, which is too short for "done and unread" (R).
6. **Show load through behaviour (Clawd on Desk).** One pet shows the most urgent state across all sessions. It types for 1 busy session, grooves in headphones for 2, and "builds" for 3 or more. One subagent gets headphones; 2 or more get three-ball juggling (R). This shows how much is going on without a count.
7. **Give each kind of tool a prop (stanhoody/notchi).** A keyboard for edits, a terminal for Bash, a magnifier for reading, a globe for the web, a lightbulb for planning, "…" between tools, a coffee when stuck on one thing for 30 s or more, a hop and a star when done, a "?" when a tool fails, a wave when it needs you, "Zzz" when idle (R).
8. **Make the creature feel alive with cheap tricks (CodeIsland, coucou).** Irregular blinks (every 2.2–5.6 s, with about 1 in 5 doubled). Breathing that is quick on the inhale, slow on the exhale, with a rest. Typing with skipped strokes. A thinking pause every ~11 s. A startle before an alert jump. Use deterministic randomness, cap at 20 fps, and stop drawing when hidden (R).
9. **Handoffs between notch and panel (Notchi, Vibe Notch).** As the panel opens, the creature in the notch ear blurs and fades out while the same creature fades in on the panel's "island" (Notchi). Vibe Notch uses `matchedGeometryEffect` so its crab carries over from the closed header to the open one (R).
10. **Faults that won't settle (omarchy-agent-notch).** "Done" glows green and settles. "Error" stays red and keeps shaking until you look at it (R). MioIsland escalates an unanswered wait: orange after 30 s, red after 60 s (R).
11. **Don't let the board claim more than you know (StarNet).** StarNet's rule is "the interface must never assert state the harness cannot prove" (R). This matches Fovea's "Delivered" vs "Sent" rule.

---

## 1. Coucou ("Mochi"): deep dive

- **Repo:** https://github.com/Louis-CFM/coucou · ★4,253 · 715 forks · created 27 Sep 2026 · last push 9 Oct 2026 (UTC) · macOS v0.2.3 (8 Oct 2026); Windows/Linux 0.3.0 (R).
- **Licence:** the code is MIT. The names "Coucou" and "Mochi", **the Mochi character (design, look, expressions, animations)**, the icons, sounds and media are © Louis Raillé, all rights reserved. Forks must use their own name, character and sounds (R, `LICENSE-ASSETS.md`). Fovea can learn from the engine but must not copy Mochi.
- **Stack:** native Swift 6 / SwiftUI / AppKit with zero dependencies. Mochi is drawn in a SwiftUI `Canvas` inside a `TimelineView` at 60 fps, "no Rive, no Lottie, no images". 28 handcrafted sounds. A Tauri port runs on Windows and Linux (R).

### 1.1 What Mochi looks like
- **Body (R, `BotEngine.swift`):** a superellipse ("soft squircle") 2.28R wide and 1.76R tall (exponent 2/2.7). It is filled with a light-grey gradient (#EDEDEF → #C4C5CA), with a dark rim shading inward and a white highlight at the top right. The current state colour washes up from the bottom.
- **Eyes (R):** two dark pills (ink #1A1412), 0.25R × 0.27R. They are projected onto a sphere, so when Mochi turns his head the eyes slide and foreshorten, and they vanish past ~90°. In idle the eyes follow the cursor: horizontal gaze = tanh(dx/260 pt), vertical = tanh(dy/200 pt).
- **Other parts (R):** pink blush cheeks scaled by the state tint, and two small hand ellipses peeking from behind the bottom of the body, used for waving.
- **Look (S):** a white, softly shaded squircle with two small black oval eyes. The "working" badge is a blue circle with three white dots at the top left. It reads as a marshmallow or mochi rice cake.
- **Sizes (R):** about 58 pt in the open island's overview, ≤20 pt in the compact notch (`min(20, height − 6)`), 22 pt in pills, 16 pt in the side column, 12 pt in the compact mini grid, 120 pt on the desktop.
- **Minis (R):** mini Mochis are a flat fill of the agent's identity colour, with no gradient and no highlight. Their eyes are 1.9× larger, and they look around at random every 0.5–2 s instead of following the cursor.

### 1.2 Every state and how it moves (R, `BotEngine.swift` `BotStates`, `setState`)

| State (when) | Body tint | Eyes | Badge (top-left) | Continuous motion | Entry move | Sound |
|---|---|---|---|---|---|---|
| idle | neutral grey, glow 0.25 | pill | none | eyes follow cursor; random blinks | blink | — |
| thinking (`UserPromptSubmit`) | purple #8B5CF6 | pill, gaze fixed up-right | pill with 3 pulsing dots | — | blink | think |
| working (`PreToolUse`/`PostToolUse`) | blue #3B9EFF | pill | blue pill, 3 white dots pulsing at 2.4 Hz, staggered 0.22 | — (the step ticker carries the motion) | blink | work |
| searching (in the state table, but I found no code in the macOS app that sets it (I); the chat instead sets Mochi to *thinking* while Claude answers) | indigo #6366F2 | pill, **scanning** left-right (yaw = sin(2.6t)·0.6) | dots | scan | blink | search |
| approval (`PermissionRequest`) | amber #F5A524 | **wide** (1.16×) | black ring, amber disc, white "!" | continuous bounce (−\|sin 5.2t\|·0.07R) | hop up 0.2R in 150 ms, back-eased down in 300 ms | approval |
| question (`AskUserQuestion` / Notification ending in "?") | cyan #22D3EE | pill, head tilted 0.17 rad | "?" disc | — | blink | question |
| error (`StopFailure`) | red #F4505E | **flat** bars | red dot | — | head-shake: x +0.08 → −0.08 → +0.05 → 0 over 280 ms | error |
| finished (`Stop`) | green #34D399 (lighter tint) | **happy** arcs (^ ^) | green dot | — | full 360° roll in 950 ms ending in a squash, then 5 white sparks at 0.5 s ("a happy little jump") | finish |
| ratelimit (Notification text mentions a rate limit) | orange #FB923C | **tired** half-lids | orange dot | sweat drops | one sweat drop | rate |
| sleeping | slate #94A2B8 | closed arcs, gaze down | none | breathing (scale y ±3.5%) at 1.8 rad/s; a "z" every 1.3 s | — | sleep |
| dizzy (user clicked him 3×) | pink #F472B6 | rotating **spirals** | none | head wobble sin(9t) | 2-turn roll in 1.3 s | dizzy |

- **Badges (R):** badges pop in with a back-eased scale (280 ms) and out in 90 ms. In the expanded overview there is also a soft glow behind Mochi in the state colour (opacity 0.65; 0.15 when idle).
- **Finished doesn't last (R):** 5.2 s after `Stop`, the task goes back to idle and its pill badge is cleared, even if you never looked. For external agents the pill is removed entirely.

### 1.3 Idle life, emotes and pokes (R)
- **Blinks:** every 2.2–5.4 s, with a 22% chance of a double blink. Minis also pulse gently (scale y ±4%), each with its own phase so they never move in sync.
- **Emotes:** love (hearts + sway), surprised, proud, wink (eye closes + tilt), yawn, happy (a little jump: hop −0.3R with squash and stretch) and annoyed (fast head shake). Minis can hold a permanent emote and replay it every 2–5 s, with staggered starts so the bots don't all fire together.
- **Hover:** hovering the notch makes him peek out and say hi. Hovering Mochi makes him blink and grow his eyes to 1.08×.
- **Click:** a squash and annoyed line-eyes for 0.8 s. Three clicks within 1.7 s make him dizzy.
- **Greeting at launch:** he drops into the island, bounces, slides aside and waves a quick hand (the wave oscillates at 13 rad/s), then comes back.
- **Other tricks:** he dances at 112 BPM when Apple Music or Spotify plays. A dragged file turns him into a box with a mouth that opens, gulps and chews. He has a wardrobe of 11 outfits drawn in code, which follow his head in 3D with spring lag on soft parts, and he dresses for the seasons by himself.
- **Desktop Mochi:** he can be dragged out as a 120 pt desktop companion. He flies back to the notch when an approval or question arrives, then returns to his spot. He falls asleep when no agent has been active for 120 s and the cursor is at least 150 pt away.

### 1.4 How several agents show at once (R)
- **One pill per agent or host, not per session.** Claude Code events from VS Code and from terminals (Warp, Terminal, iTerm, Ghostty…) all go to one pill (`integration_claude`). Cursor, Codex, Gemini CLI and others each get their own pill. Any agent can join by tagging its hook payload with `coucou_agent`. So two parallel Claude Code sessions share one creature (R, from the `HookServer.processEvent` routing).
- **Compact (notch with "ears"):** the focused agent's Mochi sits on the left at x = 40, at most 20 pt. On the right, a 2×2 grid shows up to 4 other agents as 12 pt minis, each animating its own state (R, `CompactMiniGrid`).
- **Open overview (640 × 160):**
  - The **left card** (322 pt) shows the focused agent: the big Mochi, then a colour dot, name, source ("Claude Code") and a step counter ("3/7"). Under that is a two-line **ticker**: the current step shimmers (a light sweep every 2.2 s), and when the next one arrives it slides up and to the left, shrinks to 88%, dims, and its chevron turns into a checkmark (0.38 s). File edits show as "file.ts +12 −3", and tapping one opens the diff. A small ↗ button jumps to the terminal or app.
  - The **right card** is a 2-column grid of up to 4 capsule pills (28 pt tall), each holding a 22 pt mini Mochi and a name. Hovering tints the pill with the agent colour, scales it to 1.04 and adds a glow. A tap swaps the focus, with a "blip" sound.
  - Alerts for agents that aren't focused show as a small corner badge on the pill: amber "!" for approval, green ✓ for finished, red × for error.
- **Card views (approval, question, error, finished…):** the other agents become a vertical column of 16 pt minis on the right, which spring into place with a 35 ms stagger.
- **Colour has two jobs:** on minis it means **identity** (Codex teal #2DD4BF, Gemini #8AB4F8, Copilot #818CF8, Cursor grey, Claude/VS Code white; users can repick from a 10-colour palette chosen to stay readable on black with dark eyes). On the main Mochi it means **state**.

### 1.5 Navigation, hover and click (R)
- **Island states:** hidden → petit (compact) → home (open), plus a greeting state.
  - Hovering only peeks to petit. "Open on hover" is an opt-in setting with a 0.6 s grace period after the pointer leaves.
  - A click opens the island. Petit hides after 60 s; home folds back after 15 s (configurable).
  - A thin white bar (35% opacity) counts down the last ≤10 s before the island folds.
- **Approvals and questions:** they force the island open and **move the focus to that agent**. Once answered, the focus **springs back to the agent you had before**.
  - Finished and error only open the island if that agent is focused; otherwise they badge its pill.
  - A non-alert event while hidden just reveals the compact view and never forces the island open.
- **Keyboard:**
  - In the open island: ⌘← / ⌘→ and ⌘1–9 switch pills, ⌘E opens the diff, ⌘P pins.
  - Global: ⌃⌥] / ⌃⌥[ switch pills, ⌃⌥A jumps to the waiting permission or question, ⌃⌥T brings the terminal forward.
  - Escape folds a pending permission away without answering it.
- **iPhone Live Activity:** shows the single most urgent session with text such as "working · 3/7", "waiting for your OK" or "✓ done", plus a count of the other sessions. Urgency order: approval > question > error/ratelimit > working > finished > idle.

### 1.6 Where the state comes from (R)
- A tiny `nb-hook` script receives Claude Code hook events and forwards them to the app over a Unix socket. For `PermissionRequest`, the hook holds the socket open until the user clicks Allow, Deny or Always.
- Codex, Copilot and Muse use `--agent <name>`. OpenCode, Amp and Hermes use plugins. If the app isn't running, the hook exits at once, so Claude Code is never blocked.
- Mapping: `UserPromptSubmit` → thinking. `PreToolUse`/`PostToolUse` → working, with one localized step per tool and diffs built from Edit/Write input. `Notification` → ratelimit or question. `Stop` → finished. `StopFailure` → error. `SubagentStart`/`Stop` add "+ subagent" and "• subagent done" steps. `SessionEnd` removes the task.

### 1.7 Delightful bits
- The eyes on a sphere, the poke → annoyed → dizzy escalation, the greeting wave, the file-swallowing box, the dancing, and the outfits whose soft parts lag on springs.
- Focus springs back after an approval.
- The ticker's "current step shimmers, then shrinks up-left into a check" transition (R).

### 1.8 Weak spots compared with Fovea's board (R, then I)
- **Coarse identity:** one pill per agent, not per session, so parallel Claude Code sessions collapse into one creature.
- **"Done" fades too fast:** it lasts 5.2 s, so there is no lasting "done and unread".
- **At most 5 agents visible:** focus plus `prefix(4)`.
- **Gradients everywhere:** on Mochi's body, the tint wash and the radial washes on cards.
- **Feature sprawl:** the same pills also cover Stripe, GitHub, Spotify and other integrations.

### 1.9 Ideas to borrow
- One "hero + minis" layout: the hero on the left ear, minis on the right ear.
- Shape eyes per state.
- Short, distinct entry moves: hop for needs-you, shake for error, roll and sparks for done.
- Pull focus to an approval, then restore the previous focus once it's answered.
- Use colour for identity on minis only; carry state in the eyes, motion and badge.

---

## 2. Other notch apps for coding agents

| Project | ★ | Last push | Licence | Creature? | How several sessions show |
|---|---|---|---|---|---|
| Notchi (sk-ruban) | 1,041 | 4 Oct 2026 | GPL-3.0 | yes: pixel sprites per agent family, with moods | each ear shows one sprite or a usage ring; open: one sprite per session on a pixel "grass island", tap to select |
| CodeIsland (wxtsky) | 2,482 | 24 Sep 2026 | MIT | yes: a procedural pixel mascot per tool (20+) | one mascot slot rotating every 5 s by urgency; open: session cards with a 32 pt mascot each |
| Vibe Notch, formerly Claude Island (farouqaldori) | 2,517 | 20 Apr 2026 | Apache-2.0 | small: a 14 pt pixel crab whose legs walk while working | list of sessions; crab + spinner in the closed header |
| Open Island (Octane0411/open-vibe-island) | 2,045 | 15 Sep 2026 | GPL-3.0 | no | session list on hover or click; temporary approval, question and completion cards |
| MioIsland (MioMioOS) | 540 | 14 Aug 2026 | CC BY-NC 4.0 | yes: a 13×11 pixel cat with 6 expressions; also shows your Claude Code /buddy | wings show status dots, a buddy icon and the project name |
| Agent Notch (realfishsam) | 310 | 21 Jul 2026 | MIT | yes: Claude banner critter + official Codex pets | one slot per agent type; walks while busy, green blob when done |
| AgentNotch (AppGram) | 216 | 19 Jan 2026 | none | no (orange dot for Claude, blue for Codex) | expands on hover to tool events, tokens and cost |
| AgentBro (shirenchuang) | 203 | 1 Oct 2026 | Apache-2.0 | optional pet mode, Codex-pet format | one pet follows the most urgent session; island has compact, hover, open and detail views |
| Notch Pilot (trustunsafe) | 68 | 30 Apr 2026 | MIT | yes: 6 buddies × 6 colours, 7 expressions | buddy in the closed pill; hover lists sessions; click shows a timeline |
| Pookify (eyadhammouda) | 41 | 9 Jul 2026 | MIT per README | Clawd crab or the Claude spark | most urgent session on the closed bar, count badge or amber dot; open: list sorted by urgency |
| Agent Notch for Omarchy/macOS (GNSB) | 15 | 3 Oct 2026 | MIT | animated faces: orb, cat, dog, hamster + accessories | Claude orb on the left, 2×2 cluster of other agents on the right; focus card with a step carousel |
| notchi (stanhoody) | 1 | 4 Jun 2026 | MIT | yes: 9 pixel characters, one per session | one creature per session beside the camera; subagents as small companions |
| Notchify (kikudjira) | 23 | 23 Jul 2026 | MIT | pixel Clawd | a single mascot |
| Tower Island (g535879) | 8 | 16 Apr 2026 | none | no | compact pill; hover lists all; completed sessions linger 2 min (configurable) |
| Vibe Island (vibeisland.app) | 152 | — | closed source | — | the repo holds READMEs only, no code (R) |

### Notchi (sk-ruban): https://github.com/sk-ruban/notchi
- **The creature (R, S):** pixel sprite sheets drawn in Aseprite, in three families: `claude`, `codex` and `devin`. The Claude family (S) is an orange-brown pixel block with little side nubs, four stubby legs and two dark slit eyes, close to Claude Code's "Clawd" banner mascot. It is 64 pt on the island and 32 pt in the notch ear.
- **Six activities** (`NotchiState.swift`):
  - idle: a bob of 1.5 pt every 1.5 s
  - working: a fast bob of 0.5 pt every 0.4 s, with its own sprite and a mirrored copy
  - sleeping: after **300 s** without events, no bob, 2 fps
  - compacting: 6 fps
  - waiting (permission or question): a small bob
  - waving: a 25-frame wave at launch, from the last-used family
- **Five emotions:** neutral, happy, elated, sad and sob. They come from an optional **LLM sentiment check of your prompts** (Claude Haiku or OpenAI). Scores build up, then decay ×0.92 each minute.
- **How emotions show:** sway angle 0.15–1.25°, bob ×0.5 when sad or ×1.2 when elated, and a ±0.2–0.3 pt tremble when sobbing. The sprite periodically flips to face the other way: every 10–15 s while working, every 30–60 s when idle.
- **Walking (I):** the model defines walk frequencies, but the current view code places sprites at a fixed position, and I didn't find walking there.
- **Event mapping (R):** `UserPromptSubmit` → working · `PreCompact` → compacting · `PreToolUse` → working (`AskUserQuestion` → waiting) · `PermissionRequest` → waiting · `PostToolUse` → working · `Stop` → idle · `SessionEnd` → removed.
- **Several sessions (R):**
  - Each ear of the collapsed notch shows either "Latest session mascot", the Claude, Codex or Devin mascot, a usage ring, or nothing. Hovering scales the ear sprite to 1.08×.
  - The open panel shows **every session as its own sprite on a pixel "grass island"**. The background can be grass, ground with craters, or animated water, and it rotates automatically.
  - Each sprite's position is a stable hash of its session id, nudged apart from the others, with a hashed vertical offset and back-to-front ordering.
  - Hovering a sprite adds a soft blue glow ellipse under it (0.3); the selected sprite gets 0.7. A tap bounces it to 1.15× and selects that session's activity feed.
  - Sessions are sorted with processing ones first, then by most recent activity.
- **Handoff (R):** when the panel opens, the ear sprite blurs (0 → 5 px) and fades over the first 35%. The island sprite then un-blurs and fades in over the next 35%, and only becomes tappable above 50% opacity.
- **Other details (R):** sounds are auto-muted while the terminal is focused. The site credits Claude Island as design inspiration.
- **Idea to borrow:** a stable, hashed position per session, so a creature's place on the board becomes its identity. Also the blur handoff between notch and panel.

### CodeIsland (wxtsky): https://github.com/wxtsky/CodeIsland
- **The creatures (R):** each tool has its own mascot drawn in `Canvas` from pixel rects, based on its brand:
  - **Clawd** for Claude Code (#DE886D, "adapted from clawd-on-desk SVG pixel art")
  - **Dex** for Codex (a pixel cloud with a `>_` face)
  - a Gemini sparkle, a Cursor gem, Copilot's ear loops, and about 20 more
- **Three scenes per mascot (R):**
  - **Idle → sleep:** a "sploot" pose (lying flat). Breathing is quick on the inhale, slow on the exhale, with a rest (35/45/20% of 4.5 s). Three floating z's. Once in ~6 s one leg twitches like a dreaming pet, and a rare "REM" flutter narrows the eyes.
  - **Processing/running → work:** Clawd types at a little keyboard. Each arm keeps its own cadence (0.15 s / 0.12 s), about 18% of strokes are skipped so it comes in bursts, and keys flash white on real hits. Every ~11 s there is a 1.4 s thinking pause: the hands hover and the eyes drift up. Every 10 s the eyes scan the screen.
  - **Waiting for approval or question → alert:** a 3.5 s cycle. A startle with widened eyes, then decaying jumps (10 → 8 → 5 → 3 units) with squash on landing, arms flung up and waved, an orange "!" popping above the head, and a pulsing glow.
- **How they move (R, `MascotMotion.swift`):**
  - Motion is a pure function of time with **deterministic** randomness (a hash of the time slot), so there is no stored state.
  - Blinks come every 2.4–5.6 s, with 18% doubled.
  - An idle "quirk" happens at most once per cycle, and 30% of cycles skip it "so the rhythm never feels scheduled".
  - Frame rate is capped at 20 fps (8 fps when idle). Drawing stops when the panel is hidden or the Mac sleeps, after heat complaints in issue #14. A user setting controls animation speed.
- **Several sessions (R):**
  - The collapsed left wing shows **one mascot** that **rotates through all non-idle sessions every 5 s** (configurable). Order: approval 5 > question 4 > running 3 > processing 2, then most recent. It jumps straight to a session that becomes more urgent, and the species cross-fades over 0.3 s.
  - Beside it is the current tool name, coloured by kind (Bash green, Edit blue, Read yellow, Grep/MCP purple, Agent orange, compacting cyan). It stays for 2 s after the tool ends.
  - The right wing shows a count, "active/total" (e.g. "2/5"), a pulsing bell for a waiting approval, a bouncing question bubble, a green "glance dot" when something finished while collapsed, and a moon during quiet hours.
- **Hover in three stages (R):** collapsed → "prehover", an immediate nudge of +7 pt width and 1.004× scale over 0.21 s → open after a 0.5 s delay (adjustable 0.1–1 s). A quick pass of the pointer plays only the nudge.
- **Open panel (R):** session cards, each with a 32 pt mascot and, under it, a grid of 8 px subagent icons (4 per row). The project name is coloured by status: green working, orange waiting, white idle, red-orange interrupted. Sessions can be grouped by ALL, STATUS or CLI.
- **Extras (R):** "smart suppress" (no ping while you're looking at that tab), follow-up reminders, iPhone, Watch and ESP32 desk-buddy companions.
- **Ideas to borrow:** a mascot species per agent; the urgency-ordered rotation; prehover; the deterministic motion helpers (MIT).

### Vibe Notch, formerly Claude Island (farouqaldori): https://github.com/farouqaldori/vibe-notch
- **Creature (R):** no creature board, but it has the original tiny creature. The closed notch's left ear shows a 14 pt pixel Clawd crab (antenna-arms and four legs). **Its legs alternate, walking in place, only while Claude is processing** (0.15 s ticks).
  - It keeps its identity from the closed to the open header through `matchedGeometryEffect`.
  - Next to it, Claude Code's own spinner glyphs cycle (· ✢ ✳ ∗ ✻ ✽ every 0.15 s, in Claude orange), and pixel dot-grid icons mark "waiting for input".
- **Other notes (R):** many forks descend from it (VibeHub, claude-island clones). It includes Mixpanel analytics.
- **Idea to borrow:** the smallest working creature. Motion only while working; still means idle.

### Open Island (Octane0411/open-vibe-island): https://github.com/Octane0411/open-vibe-island
- **No mascot (R).** Useful for its surface model:
  - `closed`
  - `opened + sessionList` (manual hover or click)
  - temporary `approvalCard`, `questionCard` and `completionCard`, opened automatically. They close after a timeout, or when the pointer leaves after first hovering them.
  - Actions are never placed inline in the list, "keeping the session list focused on navigation".
- **Scope (R):** 13 agents and 15+ terminals and IDEs for jumping back.

### MioIsland (MioMioOS): https://github.com/MioMioOS/MioIsland
- **Licence (R):** CC BY-NC 4.0, non-commercial, so it can't be reused.
- **Collapsed wings (R, site):** "status dots, buddy icon, and project name. Cyan = working, green = done, red = error".
- **Pixel cat (R):** a 13×11 face with 6 states:
  - idle: blinks
  - working: eyes dart left, centre, right
  - needs you: ear twitch
  - thinking (used for compacting): eyes closed, nose "breathing"
  - error: red X eyes, still
  - done: green heart eyes and a green tint
- **Done means the turn ended:** "waiting for input" maps to **done**.
- **Escalation (R, site):** an unanswered wait turns orange after 30 s and red after 60 s.
- **/buddy (R):** it also reads your Claude Code `/buddy` companion from `~/.claude.json` (see §3).

### Agent Notch (realfishsam): https://github.com/realfishsam/agent-notch
- **Creature (R):** "While Claude Code or Codex is working, its mascot walks beside the notch."
  - The Claude mascot is drawn from the real block characters of Claude Code's launch banner: 2 frames with alternating feet, 2.5 Hz, a 0.5 pt bob and a per-pixel dither sparkle.
  - The Codex mascot is OpenAI's official Codex pet, using the "running-right" row.
- **One slot per agent (R).** When an agent finishes, its slot becomes a **dithered green blob: "finished since you last looked"**. Focusing a terminal app clears it. An idle agent shows nothing.
- **Panel (R):** one row per session, titled by **your latest prompt**. Subagents fold under "▸ N subagents". Running rows walk in place; finished rows show a green pixel checkmark.
- **No hooks (R):** it polls with `ps` and `lsof` every 3 s. "Busy" means the transcript was written in the last 30 s, and it admits to a ~30 s afterglow.
- **Idea to borrow:** "done-unread" as its own persistent creature form, cleared by attention.

### AgentBro (shirenchuang): https://github.com/shirenchuang/agentbro
- **Pet mode (R):** one desktop pet follows the most urgent session. Its "vitality" follows context pressure and token use.
  - Pressure tiers: ≤50% none · ≤75 low · ≤85 medium · ≤92 high · above that critical.
  - While working it shows a pressure bar, a face flush from medium up, and sweat drops at high and critical (3 drops at critical). An energy bar shows when idle.
- **Pet format (R):** Codex pets (`pet.json` + sprite sheet). It can even load the Codex desktop app's own pets.
- **Default mapping (R):** idle→idle · working→running · thinking→review · needs-you→waiting · done→jumping · error→failed.
- **Ecosystem (R):** a pet marketplace (`abpets` CLI) and a skill that generates pets.

### Notch Pilot (trustunsafe): https://github.com/trustunsafe/Notch-Pilot
- **Buddies (R):** the collapsed pill holds one of **six buddies** (eyes, orb, waves, ghost, cat, bunny) in one of six colours. Expressions:
  - **Focused** (narrow, steady): editing files
  - **Active** (pulsing): running a tool
  - **Curious** (darting eyes): permission pending
  - **Shocked** (wide-eyed, red): a dangerous command (`rm -rf /`, `DROP TABLE`, fork bombs)
  - **Content** (happy blinks): a 10 s farewell after activity ends
  - **Idle / Sleeping**
- **Finish moment (R):** when a session finishes, the notch pops out into a bigger pill with the buddy centred and the project name under it ("notch-pilot done"). It is rate-limited and never interrupts.
- **Other views (R):** hovering lists every session (project, model, uptime, permission mode); a click shows a timeline. In always-visible mode the idle buddy peeks out with "zzz…".
- **Data (R):** it tails `~/.claude/projects/**/*.jsonl` every second.

### Pookify (eyadhammouda): https://github.com/eyadhammouda/pookify
- **Creature (R):** right-click to switch the icon between **Clawd** (the crab) and the **Spark**.
- **Several sessions (R):** "The closed island always shows what needs your attention most". Several sessions add a small count badge; any session waiting for permission shows an **amber dot** instead, "blocked sessions always taking priority". The open island lists every session as a stack sorted by urgency.

### Agent Notch for Omarchy and macOS (GNSB): https://github.com/GNSB/omarchy-agent-notch
- **Faces (R):** animated faces "that think, work, wait for you, celebrate when done and shake on errors":
  - orb (glossy ball)
  - cat (ears, whiskers, swishing tail)
  - dog (floppy ears, snout, tongue, wagging tail)
  - hamster (round ears, stuffed cheeks, buck teeth)
  - plus accessories (hat, crown, headphones, shades…), moods and reactions to the pointer
- **Collapsed (R):** "an orb for your Claude session on the left, a 2×2 cluster of other agents on the right" (the same layout as coucou).
- **Hover or click (R):** a focus card with a **step carousel** and one chip per agent.
- **Done and error (R):** "Done: the card glows green and settles. Error: it stays red and shaky until you look at it."

### notchi (stanhoody, unrelated to sk-ruban): https://github.com/stanhoody/notchi
- **One creature per session (R)**, beside the camera, with **a different character per session by default** so parallel sessions are easy to tell apart. The nine characters: Claude, Skull, Dog, Robot, Space Cat, Invader, Cactus, Flower, Jobs.
- **Subagents (R)** "appear as small companions".
- **Behaviour table (R):**

| Claude Code is… | Creature |
|---|---|
| writing code (Edit/Write) | typing, keyboard icon |
| running a shell command (Bash) | terminal-window icon |
| reading files (Read/Grep/Glob) | magnifier icon |
| browsing the web | globe icon |
| planning (TodoWrite / plan mode) | lightbulb |
| thinking between tools | `...` |
| working 30 s+ on one thing | tired, with a coffee |
| done with a turn | a happy hop + star |
| a tool errored | confused `?` + a quip |
| waiting on you | waves, and the island expands |
| idle for a while | sits still, then sleeps (Zzz) |
| nothing running | hidden |

- **Details (R):** it is "observational by default", and it has attitude when it sees `rm -rf`. The README credits Pixel Agents.

### Notchify (kikudjira): https://github.com/kikudjira/notchify
- **States (R):** a pixel Clawd (drawn in Piskel) plays `start` once when you run `claude` (through a shell wrapper), `working` in a 3-frame loop, `waiting` in an 8-frame loop, `done` once (4 frames) and `bye` once when you exit.
- **Idea to borrow:** arrival and departure animations bracket a session.

### Smaller ones (R)
- **Agent Notch (AppGram):** an orange indicator for Claude Code, blue for Codex.
- **Notch Agents (manikosto, 👾):** its "Done screen" shows *which* session finished and *what shipped*.
- **claude-statistics (sj719045032, ★47, MIT):** sessions grouped by project; a session waiting for the next prompt gives "a subtle notch pulse".
- **notchy (adamlyttleapps, ★721, MIT):** a terminal in the notch with an animated pill showing working, waiting or done.
- **NetVar1337/vibe-island (★68):** a 16 px `PixelPet` recoloured per status, with a "!" while waiting.
- **pant0m/ClaudeIsland (★0):** a pet named "Cody" in eight styles (slime, cat, ghost, bunny, bear, fox, chick, penguin).
- **NotchBuddyClaude:** 4 mascots.
- **claude-buddy (handsome-rich):** a gacha egg may hatch a pet when a session ends; 14 pets across 5 rarities.
- **Atoll (Ebullioscopic, ★4,879, GPL-3.0) and boring.notch (★10,972):** general-purpose Dynamic Island apps for macOS. Their READMEs mention no coding agents, so they are useful only as references for building the notch window.

---

## 3. Pets and visualisations beyond the notch

### OpenAI Codex / ChatGPT desktop "Pets" (official; closed source; documented at https://learn.chatgpt.com/docs/pets.md)
- **The pet (R):** a floating pet above all windows. Under it are controls: a pencil to start a chat, a **bell** that opens the **activity tray** of threads, and a chevron to collapse it.
- **Statuses (R):** **Running** · **Needs input** (an approval, answer or decision) · **Ready** (finished, with unread activity) · **Blocked** (failed or system error). "When more than one chat has activity, the pet prioritizes chats that need input, followed by blocked, ready, and running chats."
- **Other surfaces (R):** `/pet` toggles it in the desktop app. In the Codex CLI, `/pets` shows a terminal pet for the current session (iTerm2 3.6+ or Kitty/Sixel; not in tmux or Zellij).
- **Reduced motion (R):** "the pet uses a still frame instead of sprite animation".
- **Custom pets (R):** made with the bundled `hatch-pet` skill. A sprite sheet is a transparent PNG/WebP of exactly **1536 × 1872** px, which is an 8 × 9 grid of 192 × 208 frames according to Petdex.
- **Animation rows:** idle, running-right, running-left, waving, jumping, failed, waiting, running and review. These row names come from AgentBro's loader code, i.e. third-party reverse engineering (R). AgentBro maps "thinking" to review and "done" to jumping.
- **Licence:** agent-notch notes that the official sprite sheets are © OpenAI (R).
- **Idea to borrow:** this is the closest first-party match to Fovea's board: the same four states and a clear priority order. One creature plus a bell-opened list, rather than one creature per task.

### Pixel Agents: https://github.com/pixel-agents-hq/pixel-agents (★9,598 · MIT · pushed 9 Oct 2026)
- **What it is (R):** a VS Code panel or `npx pixel-agents` web app showing a tiny pixel office. **Each Claude Code terminal is one character** (6 characters from the JIK-A-4 "Metro City" pack). Subagents and Agent Teams appear as separate characters.
- **Activity to behaviour (R, `characters.ts`, `constants.ts`):**
  - **Active:** the character pathfinds to its assigned desk and sits. It **types** (2 frames, 0.3 s each) for edits and Bash, and **reads** for reading tools (Read/Grep/Glob/WebFetch/WebSearch).
  - **Turn ends:** after a few seconds it stands up and **wanders**: 3–6 moves to random tiles at 48 px/s, with 2–20 s pauses. Then it goes back to its seat and rests there for 120–240 s.
  - **Speech bubbles:** "permission" stays until resolved; "waiting" shows for 2 s, then fades.
  - **Arrival and departure:** characters appear and vanish through a 0.3 s Matrix-style digital-rain effect.
- **Other details (R):** a two-note permission chime (A5 → E5). Named areas can be mapped to workspace folders. The office is fully editable.
- **Roadmap (R):** health bars for rate limits and token budgets.
- **Idea to borrow:** stay seated and typing = working; get up and wander = idle. The meaning comes from location as much as pose.

### Clawd on Desk: https://github.com/rullerzhou-afk/clawd-on-desk (★6,395 · **AGPL-3.0** · pushed 8 Oct 2026)
- **One pet for every agent (R):** "sessions across all agents resolve to the highest-priority state". 12 animated states:
  - idle: follows the cursor with its eyes, leans its body, stretches its shadow; randomly reads or patrols
  - thinking: a thought bubble and spark, on `UserPromptSubmit`
  - working: **typing for 1 session, headphones groove for 2, building for 3+**
  - juggling: **headphones for 1 live subagent, three-ball juggling for 2+**
  - error: on `PostToolUseFailure`
  - happy: on `Stop` and `PostCompact`
  - notification: an alert, on `PermissionRequest`
  - sweeping: on `PreCompact`
  - carrying boxes: on `WorktreeCreate`
  - sleeping: after 60 s of mouse idle it yawns → dozes → collapses → sleeps, and mouse movement triggers a **startled wake-up**
- **Other details (R):**
  - Mini mode: half the body peeks from the screen edge; hover → peek out and wave; small alert and celebration poses; parabolic jumps between modes.
  - Permission bubbles stack upward from the bottom right.
  - A compact HUD next to the pet lists live sessions.
  - Do Not Disturb puts the pet to sleep and suppresses "asks" but not "done" notices.
  - Themes (Clawd, Calico, Cloudling…) and Codex-pet import.
- **Idea to borrow:** show how much is going on through what the creature does, not with a number.

### Petdex: https://github.com/crafter-station/petdex (★4,211 · MIT)
- **What it is (R):** a gallery, a CLI and a desktop floater for Codex-format pets ("animates on every tool call your agent makes").
- **Format (R):** v1 is 8 × 9 frames of 192 × 208; v2 is 8 × 11. 21 projects build on it.

### OpenPets: https://github.com/alterhq/openpets (★99 · MIT · Swift, macOS 14+)
- **One shared pet (R):** one local desktop pet that many tools report to (MCP server, CLI, and the embeddable **OpenPetsKit** Swift package).
- **Task bubbles (R):** `notify` returns a `threadId`, so one pet can carry **several task bubbles at once**, each updated in place. Statuses: running, review, done, failed, waiting, message.
- **Hotspots (R):** "pet-matched cloud hotspots" show compact values, such as Claude's 5-hour and 7-day quota as small clouds next to the pet.

### Star Office UI: https://github.com/ringhyacinth/Star-Office-UI (★7,500 · repo description says the code is MIT)
- **Location is the state (R):** 6 states map onto 3 rooms of a pixel office. idle → **breakroom sofa** · writing, researching, executing, syncing → **desk** · error → **bug corner**. Speech bubbles carry the status text.
- **Guests (R):** other agents join with a key and push their state every 15 s. There is also a "yesterday's notes" card.

### Agent Town (geezerrrr, ★248) and Agentshire (★1,299, MIT)
- **Agent Town (R):** a Phaser pixel RPG office. Tasks move `queued > returning > sending > running > done/failed`. "Idle workers roam the office: whiteboards, printers, sofas… They return to their seat before starting real work."
- **Agentshire (R):** a 3D town with a choreographed flow: Summon → Rally → Assign → Enter Office → Code → Celebrate → Return to Town.

### StarNet (androoAGI, ★1,249, MIT)
- **Principle (R):** the station is "a projection of live runtime state", and "**the interface must never assert state the harness cannot prove**".

### Statusline pets and tamagotchis
- **Claude Code Tamagotchi (Ido-Levi, ★433, MIT) (R):** a pet in the Claude Code statusline, e.g. `(◕ᴥ◕) Leo 😊 | 🍖 73% ⚡ 66% 🧼 89% ❤️ 96% | 💭 That's a lot of TODO comments...`. It has hunger, energy, cleanliness and happiness, makes thought-bubble remarks, and includes an AI "behavioural enforcement" monitor.
- **claude-pet-tamagotchi (annaluizando, ★2) (R):**
  - Half-block pixel art in the statusline at 1 fps.
  - **Its mood follows `context_window.used_percentage`:** napping → stretching → coding with you → excited → nervous → begging for `/compact`. Above 92% it shakes.
  - After 4+ tool errors in a row it gets a "debugging pain" mood.
  - It evolves egg → chick → bird → phoenix by lines written.
  - It poops after 300+ deleted lines, and the poop is cleaned when you commit.
- **Claude Code's own `/buddy` (R, from third-party code and READMEs):**
  - Claude Code once had a built-in companion whose species came from a hash of your account. The 18 species: duck, goose, blob, cat, dragon, octopus, owl, penguin, turtle, snail, ghost, axolotl, capybara, cactus, robot, rabbit, mushroom, chonk.
  - Each buddy had a rarity from common to legendary, stats (debugging, patience, chaos, wisdom, snark), eyes, a hat and a "shiny" variant, and lived in `~/.claude.json` under `companion` (MioIsland's `BuddyReader`).
  - The coding-buddy README (★468) says "Anthropic removed `/buddy` in Claude Code v2.1.97". This is a third-party claim I did not check.
- **AgentPet (ntd4996, ★375, MIT) (R):** a desktop pet fed by tokens and finished sessions, with XP, levels, 14 achievements and a leaderboard.

### Claude Animation Base (JohnHeibel, ★952, MIT): https://github.com/JohnHeibel/ClaudeAnimationBase
- **What it is (R):** a p5.js kit for animating Clawd, with **31 acted emotions** in `src/clawd.js` (neutral, happy, excited, laugh, love, shy, proud, smug, relieved, sad, cry, angry, furious, scared, surprised, confused, thinking, idea, determined, sleepy, bored, nervous, suspicious, disgusted, dizzy, cool, starstruck, ko, playful, mischief, hopeful…).
- **How an emotion is built (R):**
  - eyes and mouth
  - blush and tint
  - an emote glyph (spark, hearts, sweat, cloud, !, ?, dots, bulb, zzz, stars, music, anger, steam)
  - a "take" strength (how big the anticipation is)
  - a body function of time: vertical offset, squash, rotation, arm angles, gaze
- **Idea to borrow:** a parametric acting model for a creature. Write each state as a parameter set rather than a hand-drawn clip.

---

## 4. Menu-bar and desktop creatures that show live state

- **RunCat:**
  - Repos (R): RunCat365 (Windows taskbar, ★10,329) and **RunCat Neo** (macOS menu bar, ★900, Apache-2.0, App Store, macOS 26) at https://github.com/runcat-dev, plus the original Kyome22/menubar_runcat (★511, Apache-2.0).
  - Mechanic (R, `RunnerService.swift`): **the cat's running speed is CPU% ÷ 5, clamped to 1–20×**. An option inverts it ("speed decreases under load": 0.5 × (21 − value)).
  - Extras (R): community "runners" can replace the cat. Neo can read any local JSON file as a dashboard card (its README suggests Claude Code usage).
  - The idea in one line: one continuous signal, shown as tempo.
- **oneko / Neko:**
  - Repos (R): oneko.js (adryd325, ★1,323, MIT) and neko-mac (★141, Cocoa).
  - Mechanic (R): the cat chases the cursor in 8 directions at 10 px per tick and stops within 48 px. When the cursor moves away again, it first **holds an "alert" pose for a few ticks before running** (anticipation). If it is idle for long enough, about every 20 s it randomly falls asleep (tired → sleeping) or scratches itself, or **scratches the nearest wall when it is at a screen edge**.
- **Shimeji:**
  - Mechanic (I): desktop mascots that walk along the bottom of the screen, climb window edges and ceilings, sit on top of windows, fall with gravity when dropped, and multiply. Behaviours are scripted in XML (Shimeji-ee).
  - Repos (R): Shijima-Qt (★200, GPL-3.0) is now **archived/discontinued**. Its author points to Shijima for iOS, Android and Web.
  - Related (R): WindowPet (★669, MIT, Tauri) is a similar cross-platform pet overlay.

---

## 5. Patterns across all of them

### 5.1 The state words have converged

| Fovea Agent task | OpenAI Pets | coucou | CodeIsland | Notchi | Clawd on Desk | MioIsland |
|---|---|---|---|---|---|---|
| Working | Running | thinking / working (blue dots) | processing / running → typing | working (fast bob) | thinking / typing / groove / building | working (darting eyes) |
| Needs you | Needs input | approval (wide eyes, "!", bounce) / question ("?", tilt) | waitingApproval / Question → startle-jump + "!" | waiting | notification (alert) | needsYou (ear twitch) |
| Complete (unread) | Ready | finished (roll + sparks, gone after 5.2 s) | green "glance dot" | idle | happy | done (heart eyes) |
| Failed | Blocked | error (flat eyes, shake) | — (interrupted = red name) | — | error | error (X eyes) |
| (no task) | — | idle → sleeping | idle → sleep scene | sleeping after 300 s | sleeping after 60 s | idle |

**Priority orders found (R):**
- OpenAI: Needs input > Blocked > Ready > Running.
- coucou: approval > question > error > working > finished > idle.
- CodeIsland: approval > question > running > processing.
- Pookify: "blocked always wins".

OpenAI's order is the one that fits a board whose job is "what needs me": unread "done" ranks above "still working".

### 5.2 Seven ways to show several agents
1. **Hero plus minis** (coucou, omarchy): the focus is big on the left ear, with a 2×2 grid of 12 pt minis on the right. When open: a focus card plus a grid of creature pills. Clear focus, but it caps visibility at about 5.
2. **One slot, rotating** (CodeIsland): rotates every 5 s and jumps straight to the most urgent. Very compact, but you have to wait to see everyone.
3. **Most urgent only, plus a mark** (Pookify, OpenAI Pets): one creature with the top state; a count or dot hints at the rest, and a bell opens the list.
4. **One slot per agent type** (agent-notch): one creature per provider, walking while busy and a green blob when finished-unseen.
5. **A scene of many** (Notchi's grass island, stanhoody/notchi, Pixel Agents, Star Office, Agent Town): a creature per session, with **identity as position** (hashed, stable) or **state as position** (desk, sofa, bug corner). It doesn't fit the 32 pt notch; it works only in the open panel.
6. **One creature, load as behaviour** (Clawd on Desk): what it does scales with the number of sessions and subagents.
7. **One creature, many bubbles** (OpenPets): a thread bubble per task beside one pet.

### 5.3 Motion vocabulary, with the numbers (R)
- **Blinks:** every 2.2–5.6 s, with about 18–22% doubled (coucou, CodeIsland). MioIsland and the statusline pets blink on a fixed 7 s period.
- **Breathing:** asymmetric, 35% inhale / 45% exhale / 20% rest over 4.5 s (CodeIsland). coucou breathes by sine, ±3.5% scale y at 1.8 rad/s, only when asleep.
- **Working:**
  - typing at 0.12–0.16 s per stroke, with about 18% of strokes skipped and a pause every ~11 s (CodeIsland)
  - a bob every 0.4 s (Notchi)
  - feet alternating at 2.5 Hz (agent-notch) or 0.15 s ticks (Vibe Notch)
  - a pulsing three-dot badge at 2.4 Hz (coucou)
- **Needs you:**
  - a hop in 150 ms and back-eased landing in 300 ms, then a continuous bounce at 5.2 rad/s (coucou)
  - a 3.5 s cycle of startle and then decaying jumps of 10/8/5/3 with an "!" (CodeIsland)
  - darting eyes (Notch Pilot) or an ear twitch (MioIsland)
  - escalation at 30 s and 60 s (MioIsland)
- **Done:**
  - a 360° roll in 950 ms, then a squash and sparks (coucou)
  - a hop and a star (stanhoody)
  - heart eyes (MioIsland, Clawd)
  - a green blob that stays until seen (agent-notch)
- **Error:**
  - a 280 ms head-shake (coucou)
  - "stays red and shaky until you look" (omarchy)
  - a confused "?" and a quip (stanhoody)
- **Sleep:** after 60 s (Clawd on Desk), 120 s (coucou's desktop pet) or 300 s (Notchi). Yawn → doze → collapse → sleep, with a startled wake-up (Clawd on Desk).
- **Anticipation:** an alert pose before chasing (oneko), a startle before jumping (CodeIsland), an intensity value per emotion (ClaudeAnimationBase).
- **Springs:** coucou uses response 0.5 / damping 0.72 for focus swaps, and 0.2 / 0.7 for pill hover.

### 5.4 Who says *which agent* and who says *what state*
- **Species = agent, motion = state:** CodeIsland (each mascot based on its brand), Notchi (one family per provider), agent-notch.
- **Species = session:** stanhoody/notchi (a different character per session).
- **Colour = agent, eyes/badge/motion = state:** coucou's minis. Coucou's main Mochi uses colour for state instead.
- **Position = session:** Notchi's island, Pixel Agents' desks. **Position = state:** Star Office's rooms.

### 5.5 Engineering notes (R)
- **Frame rate:** cap at about 20 fps for tiny sprites. Pause the `TimelineView` when hidden. Re-anchor schedules on wake instead of replaying missed ticks (CodeIsland; heat complaints in its issue #14).
- **Pointer polling:** coucou polls the pointer 8×/s while hidden.
- **Reduced motion:** show a still frame (OpenAI, Notchi).
- **Deterministic randomness:** a hash of the time slot makes frames reproducible, so they can go on contact sheets and snapshot tests (CodeIsland renders them offscreen; stanhoody has `--export-assets`).

---

## 6. Fit with Fovea's own rules (AGENTS.md): flags before borrowing

- **"The Island never shows a task count":** CodeIsland's "2/5", Pookify's count badge and coucou's "others" count (on its iPhone Live Activity) are out. Showing one mini creature per task, or "most urgent only + bell", fits.
- **"Never uses gradients":** coucou's gradient body, state wash and radial card washes are out, as are gradient mascots (CodeIsland's Gemini). Mini Mochis are already flat fills: borrow that.
- **"Island neutrals are white at an opacity on black":** a creature's neutral body would need to be white at an opacity, with state carried by eyes, badge and motion. That echoes coucou's minis and Vibe Notch's crab.
- **"No efficiency metrics, streaks…":** tamagotchi XP, levels, leaderboards and gacha (AgentPet, claude-buddy, the Tamagotchi vitals) are out.
  - AgentBro's context-pressure sweat is a state cue, not a score, but it is close to the line.
- **"Never shows a provider icon inside Quick Answer":** a creature species per provider (CodeIsland, Notchi) would act as a provider icon, so it must stay out of Quick Answer. It is fine on the board itself.
- **"Never opens an empty hover panel":** matches Notch Pilot and CodeIsland, which hide when there is no session.
- **One line of current activity per task:** coucou's two-line step ticker shows the previous step too, which is more than "one line" and must be trimmed.

## 7. Licences: what can be reused

**Permissive (R):** CodeIsland (MIT), Vibe Notch (Apache-2.0), Pixel Agents (MIT; its characters come from the JIK-A-4 pack, which has its own terms), OpenPets / OpenPetsKit (MIT), agent-notch (MIT, but the Codex pet art is © OpenAI), stanhoody/notchi (MIT), Notch Pilot (MIT), Notchify (MIT), oneko.js (MIT), RunCat (Apache-2.0), coucou **code** (MIT).

**Copyleft or restricted (R):** Notchi (GPL-3.0), Open Island (GPL-3.0), Clawd on Desk (AGPL-3.0), MioIsland (CC BY-NC 4.0, non-commercial), Atoll (GPL-3.0). Fovea should not copy their code.

**Characters you may not copy (R):**
- **Mochi** (© Louis Raillé).
- **Clawd** and the Claude spark are Anthropic's marks (Pookify's trademark note).
- The official Codex pets are © OpenAI.

## 8. Not found, and caveats

- **"Crew Tower":** not found on GitHub under that name (searched "crew tower", "crewtower", "crew-tower", "notch crew"). The closest is **Tower Island** (g535879/TowerIsland, ★8), "a … control tower for all your AI coding agents". I can't say it is the same project.
- **Names that resolved (R):**
  - "Claude Island" is now **farouqaldori/vibe-notch** ("previously Claude Island").
  - "Vibe Island" is a closed-source app; its GitHub repo has only READMEs.
  - "Atoll" is a general-purpose Dynamic Island app with no agent features in its README.
  - Two unrelated projects are both called "Notchi" (sk-ruban and stanhoody).
- **Behaviour I describe from code, not from running the apps:** timings and mappings come from reading source. I did not run any app. Visual descriptions marked (S) come from four screenshots of project pages; the rest come from drawing code.
- **Third-party claims:** the Codex sprite-row names come from AgentBro's reverse engineering, and the `/buddy` removal version comes from a third-party README.
