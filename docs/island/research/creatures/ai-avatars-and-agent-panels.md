# Animated agent avatars and agent control panels: research for the Fovea notch board

Researched 2026-10-08 with the gstack browse binary (isolated daemon) plus web search for discovery.

**Evidence tags used throughout**

- **(R)** I opened the page and read the text.
- **(S)** I looked at the image or video frames myself (frame grabs listed at the end).
- **(SR)** Only seen in a search-engine snippet; I could not open the page. Treat as unconfirmed.
- **(I)** My inference or synthesis, not a claim from a source.

**Blocked sources (not bypassed):** openai.com (Cloudflare check never completed), fastcompany.com (403),
x.com (403; I read public posts through the api.fxtwitter.com JSON mirror instead), uxdesign.cc /
Medium (Cloudflare block), and x.ai/changelog (Cloudflare block after a few page loads; the x.ai
design post itself loaded fine).

---

## TL;DR for the board redesign

1. **The three named references are all real, all launched in the last two months, and all solve
   the same problem Fovea has:** showing what an always-on agent is doing without making you read
   a log.
   - **OpenAI "dots"** (Sept 29, 2026): a personal always-on agent in ChatGPT whose face is a
     customizable plush character (shape, color, eyes, glasses, accessories). It descends from
     **Codex Pets** (May 2026), a floating desktop pet that already reports
     Running / Needs input / Ready / Blocked for coding chats. Codex Pets is, in my judgment, the
     closest existing product to Fovea's board (I).
   - **Meta "Muse"** (Sept 8, 2026) with its mascot **Jolly/Jollybot**: a fuzzy cream plush
     character. The design lead says the very first UI drawn was a persistent **status pill**
     answering "what is my agent doing right now?"; the avatar was added to that pill later
     (it puts on headphones and types on a tiny laptop while working).
   - **xAI "Grok Bot"** (Aug 11, 2026): a roster of named Bots, each a **flat solid shape with two
     white slit eyes**. Its avatar alone carries six states (Idle, Working, Waiting, Blocked,
     Thinking, Done), and hovering shows the current action. xAI explicitly rejected "three
     animated dots" as too little information.
2. **Grok Bot's system is the best fit for the Island's rules** (one face, no gradients, state in
   motion, one line on hover). Codex Pets supplies the missing rule for a resting notch: when many
   sessions are active, show the most urgent one first (needs input > blocked > ready > running).
3. **Control panels converge on the same 4 to 6 states**, grouped with "needs you" on top, a
   one-line summary per row, and an unread/acknowledged notion for finished work. Two refinements
   worth copying: Devin splits *waiting for an answer* from *waiting for approval*, and Linear
   has an explicit *stale* state when an agent goes silent.
4. **Watch-outs:** status dots that stick (a filed Claude app bug), counts in the header (the
   Island forbids task counts), and gradients (Gemini, Siri) conflict with Fovea's rules.

---

# Part A: the named references

## A1. OpenAI "dots" (launched Sept 29, 2026)

**What it is (R).** At DevDay on Sept 29, 2026, OpenAI launched dots: always-on personal agents
inside ChatGPT, powered by GPT-6 Astra, each with its own cloud computer and browser, working
toward goals between conversations and coming back with results or decisions. You can message a
dot in ChatGPT, Slack or Teams, or call it. Rollout went to Pro and Business Premium first
(EEA, Switzerland and UK excluded for Pro at launch). At launch you get **one** dot; MacStories
reports OpenAI plans multiple dots later. Sources: TechCrunch, OpenAI's own docs at
learn.chatgpt.com, Anima's walkthrough, MacStories.

**How they look (R + S).**

- The official docs say you give your dot a name and choose its **shape, color, eyes, glasses and
  accessories**, changeable any time; the handle follows the name (for example a dot named Alfred
  becomes @yourname-alfred) (R).
- The customization sheet (MacStories screenshot) has three rows (S):
  - **Colors** as swatches: grey, blue, yellow, magenta, lime, pink.
  - **Characters**: fuzzy 3D plush figures, including a teal bunny-like shape with headphones and
    sunglasses, a blue cloud with a black beret, a yellow pear or rounded triangle with round
    glasses and a bow tie, and a magenta heart with round sunglasses.
  - **Pets**: pixel-art characters, which look like the Codex Pets lineage.
- The launch video names include Alfred (yellow, glasses and bow tie), Felipe (blue cloud, beret)
  and Jojo (magenta heart, sunglasses) (S). Mashable lists Iggy, Felipe, Todd, Alfred and Jojo in
  pink, blue, green, yellow and purple (R).
- Engadget describes them as muppet-like, with a green googly-eyed one in a bow tie reminiscent of
  Kermit, and notes none of them seem to have a nose or mouth (R).
- A snippet attributed to Fast Company says the default look, "Dottie", is a green bean shape with
  two diamond eyes (SR; Fast Company returned 403, so unconfirmed).

**How it shows up in the UI (S, from the launch video and MacStories screenshots).**

- In a conversation, the dot sits small and centered at the top with its name under it, peeking
  over the first message.
- Your own message bubbles take the dot's color (yellow for Alfred, magenta for Jojo), and the
  call screen fills with that color. The color works as identity across every surface.
- While it composes, the chat shows a classic grey three-dot typing bubble.
- The profile panel shows the avatar, the name, a state word ("Active"), Call and Slack buttons,
  Computers (its own and yours, with an Allow button), a **Recent activity** list (one row per
  task with a small marker at the right) and Outputs.
- The docs describe an **Activity** view in the profile where you open a task and answer requests
  for decisions, sign-ins or approvals, and a **Scheduled** view for recurring work (R).

**Motion and states.**

- What OpenAI says (via Fortune, R): animated cues let users see when an agent is working; distinct
  names and appearances help people tell agents apart when several share a workspace; the
  character is optional.
- **I found no official list of the dots' animation states.** A widely indexed list
  (idle, listening, processing, working, speaking, awaiting approval, complete, error) comes from
  an independent Rive animator's dev.to post. That post says outright that it does not describe
  Dots. Do not cite it as OpenAI's design (R).

**Design rationale (R, Fortune).** The design team worked with external partners. They partly drew
on Codex Pets, aiming for something approachable that would not get in the way of work. They
explored abstract shapes, recognizable objects, and different materials and textures before
settling on a flexible system of shapes, colors and accessories.

**Why people found them delightful, and the pushback.**

- Delight (R): personalization and naming (MacStories named his dot Puck), plush toy-like
  material, faces that are almost nothing (two eyes), one identity color, and a character you can
  call on the phone. Mashable frames it as a familiar little face you can return to and trust.
- Pushback (R): Fortune quotes Ed Zitron calling it marketing, and Fairplay accusing Meta and
  OpenAI of using children's iconography. Gizmodo and Engadget argue the cuteness smooths over
  real risks and data access.

Sources: TechCrunch (R), Gizmodo (R), Mashable via Yahoo (R), Fortune (R), Engadget (R),
MacStories (R + S), Design Compass (R), Anima blog (R), learn.chatgpt.com/docs/dots{,/getting-started,/controls,/tasks-and-memory}.md (R),
OpenAI launch video via fxtwitter (S), dev.to Rive post (R; independent, not OpenAI).

### A1b. Codex Pets (May 2026): the direct precursor, and the closest product to Fovea's board

**What it is (R).** Optional animated companions in the Codex desktop app (now the Codex mode of
the ChatGPT desktop app, merged July 9, 2026). The pet floats above all other app windows on
macOS and Windows and reports what your coding chats are doing while you work elsewhere.
Commands: `/pet` shows or hides it, and `/hatch` (the `hatch-pet` skill) generates a custom pet.

**Layout and controls (R, official docs).**

- The pet floats with controls under it: a pencil to start a chat, a voice button, a **bell** that
  opens your threads, and a chevron to collapse them. Option+Space shows the controls.
- It can be dragged anywhere. Its position and choice persist.
- The Computer Use picture-in-picture window can attach to the pet and follow it.

**States (R, official docs).** Four statuses:

| Status | Meaning |
| --- | --- |
| **Running** | A chat is working |
| **Needs input** | It needs your approval, answer or decision |
| **Ready** | Done, with unread activity |
| **Blocked** | Failed or hit a system error |

When several chats are active, the pet shows them in priority order: **needs input, then
blocked, then ready, then running**.

**Visual cues (R, PCWorld).** A thought bubble above the pet shows a **small red clock** when a
chat waits for approval and a **green check** when a chat is done and ready for a new prompt.

**Built-in pets (R).** There are eight, including the default blue "Codex", a duck called
"Dewey", "Rocky" and "BSOD". The community made Clippy versions.

**Accessibility (R).** With reduced motion on, the pet shows a still frame instead of sprite
animation.

**CLI version (R).** Terminal pets report the same four states for one session. They need
iTerm2 3.6+, Kitty graphics or Sixel, and do not work in tmux or Zellij.

**Sprite contract (R, openai/skills `hatch-pet` references/animation-rows.md).** A fixed 8 × 9
atlas of 192 × 208 cells (1536 × 1872 px), transparent PNG or WebP:

| Row | State | Frames | Frame timing |
| --- | --- | --- | --- |
| 0 | idle | 6 | 280, 110, 110, 140, 140, 320 ms |
| 1 | running-right (dragged) | 8 | 120 ms each, last 220 |
| 2 | running-left (dragged) | 8 | 120 ms each, last 220 |
| 3 | waving | 4 | 140 ms each, last 280 |
| 4 | jumping | 5 | 140 ms each, last 280 |
| 5 | failed | 8 | 140 ms each, last 240 |
| 6 | waiting (needs you) | 6 | 150 ms each, last 260 |
| 7 | running (working) | 6 | 120 ms each, last 220 |
| 8 | review | 6 | 150 ms each, last 280 |

The skill's guidance per state (R, paraphrased):

- **idle:** calm. Breathing, a blink and a small bob, with visible micro-variation but no large
  gestures. It doubles as the reduced-motion frame.
- **running:** focused effort such as typing, scanning or thinking. It must *not* show literal
  running.
- **waiting:** an expectant, asking pose, distinct from idle.
- **review:** focus shown through a lean, a blink or a head tilt.
- **failed:** a deflated reaction. Tears or smoke are allowed only if attached to the body.
- **All rows:** no detached sparkles, speed lines, glows, shadows or speech bubbles in the sprite.
  The app draws the bubble.

I could not find which row plays for "Ready". Waving or jumping are plausible (I).

**Why people liked it (R, PCWorld).** The writer kept missing idle agents waiting for approval
while working in other windows. The pet's bubble fixed that and made him feel in the loop.

Sources: Engadget (R), PCWorld (R), learn.chatgpt.com/docs/pets.md (R),
learn.chatgpt.com/docs/notifications.md (R), github.com/openai/skills hatch-pet SKILL.md and
references/animation-rows.md (R), releases.sh merge note (R).

---

## A2. "Muse by Meta" and its mascot Jolly (Jollybot)

**What it is (R).** Muse is Meta's always-on personal agent, from Meta Superintelligence Labs. It
launched in the US on Sept 8, 2026 (Fortune; AGTP's X post); several outlets describe it as 18+
only (SR). It runs in its own app and on the web (NBC, R), in WhatsApp (SR) and in a Mac app
(Engadget, R) that reportedly operates desktop apps (SR). It reached #1 on the US App Store, with
2.5M downloads in 13 days (AGTP). Its mascot, **Jolly** or "Jollybot", was shown at
Meta Connect (around Sept 23 to 24). Alexandr Wang credited Muse product design lead
**Alex Cornell** with designing it.

**How it looks (S + R).**

- Jolly is a cream or ivory fuzzy plush figure in a hood-like body, with a round face opening,
  beady black eyes, pink cheeks and a small smile (S, from Wang's image). NBC likens the Muse
  Charm keychain to a Labubu crossed with a Tamagotchi (R); other coverage compares Jolly itself
  to Labubu (SR).
- Engadget calls it a fuzzy egg-shaped creature (R).
- Users can rename it and change its look; the agent **generates the new look plus all its
  animations**, according to TestingCatalog's walkthrough (R). Examples include Zuckerberg's toga
  and wreath-wearing "Agrippa" (NBC, R), a cat (Engadget, R) and a golden retriever in sunglasses
  (S).
- Changing the avatar also changes the Muse favicon (R, Simon Smith's post).

**How it moves (R + S).**

- **Working (R):** Engadget's reviewer gave her Muse a cat avatar. When given a task it
  dramatically puts on headphones and starts typing on a tiny laptop. Axios says the animations
  appear at the top of the app (tapping at a keyboard, for example) while Muse works.
- **"Something great happens" (R):** David Singleton (Meta) singles out animations for working and
  for good moments.
- **The full set (S):** a customization share video shows the golden-retriever avatar "Avo" as
  four cards: standing idle; headphones on, typing at a laptop; holding a glowing orb; and jumping
  with arms up, then holding a star and wearing a cape. The orb card is probably thinking and the
  star card a celebration (I).
- **In the chat header (S):** the avatar's bust sits on a small pill with its name.

**The status pill, the design idea that matters most (R; Alex Cornell's own post, Sept 23, 2026).**

- The very first thing designed for Muse was a **status pill at the top of the screen**. It
  survived every revision. Its job is to answer "what is my agent doing right now?" across every
  surface of the app.
- Cornell calls it a messaging pattern, chosen against the industry habit of showing chain of
  thought at the bottom of the thread. A persistent display was necessary because the app had
  three tabs (feed, chat, library).
- The first version had **no avatar and about six deterministic states**. Even then, showing the
  connection status alone was critical in testing.
- His early mock (S) shows a white pill with an icon and "Jollybot". When busy, it expands to a
  second monospace line ("is researching Carmel"), and the icon changes with the activity.
- AGTP adds that status lines carry a matching emoji ("checking scores"), and that Julie Zhuo
  called the pill's live animation a big part of why the agent feels responsive (R).

**Hardware and video avatar.**

- Zuckerberg showed a keychain **Muse Charm** with a small screen running the animated avatar. You
  press a side fingerprint sensor to talk. New Atlas and NBC describe it as Tamagotchi-like (R).
- Meta also demoed **Muse Realtime Avatar**, a live video face and body for calls, about 870 ms to
  the first response, judged by Meta's own evaluation (R, RuntimeWire).

**Why people liked it, and the pushback (R).**

- Liked: it solves a real problem (seeing background work), personalization, and endless
  memeability (Wang posted Jolly memes; Spotify announced its integration with Jolly in green
  headphones).
- Axios reports Meta's design team concluded personal avatars were critical to the product.
- Pushback: Fortune, Engadget and Gizmodo cite privacy incidents and the trust-by-cuteness
  critique.

Sources: Axios via Yahoo (R), Fortune (R), Engadget (R), NBC (R), New Atlas (R), RuntimeWire (R),
fxtwitter JSON of @alexcornell 2102560084836704642, @alexandr_wang 2102573821807202724,
@AGTPinsights 2102636424550088886, @testingcatalog 2097472570450726970, @dps 2098261414335160641,
@_simonsmith 2104192411425775772 (R), plus frames from @christinesed's video (S).

---

## A3. "Grokbot": xAI's Grok Bot (launched Aug 11, 2026)

**What it is (R, x.ai).** Grok Bot is a team of always-on agents ("Bots"). Bots share their own
cloud computer, sign into your tools and come back only when something needs approval. It runs on
desktop (macOS) and iOS. It is bundled with SuperGrok tiers and Cursor plans, but its usage is
counted separately from them. The app is organized around a **roster of Bots**, not a chat
history.

**xAI's design write-up (R; x.ai/news/designing-grok-bot, Sept 3, 2026).** This is the single
most relevant document for Fovea.

- **Presence as interface.** The way a Bot appears must answer three questions: *who is this,
  what are they doing, how much do I need to know?*
- **Who.** A roster only works if you can recognize a Bot from its avatar almost peripherally.
  They explored initials, emoji, pixel art, watercolor, claymorphism, Noritake-style line art,
  silhouettes and identicons (S, exploration grid). Watercolor and clay had character but too much
  detail at sidebar size, and simpler systems made Bots interchangeable.
- **The final system (S):** eight **flat, solid-color shapes**: circle, blob, rounded square,
  pill, triangle, hexagon, cloud and droplet. Each has **two white slanted slit eyes**: one
  construction, varied by shape, color and accessory.
- **What.** Once the avatar was the identity, it became the place to show state, instead of a
  separate indicator. In their words, at rest the Bot is calm and slightly curious; it
  acknowledges new work, kicks into gear when work begins, moves differently when waiting or
  needing help, and settles when done.

**The avatar motion system (S).** I clicked through each state of the live demo on that page.

| State | What the avatar does |
| --- | --- |
| **Idle** | Black ball; eyes slanted, looking up and to the right |
| **Working** | Eyes straighten into two vertical bars, facing forward and focused |
| **Waiting** | Eyes flatten into two horizontal dashes, patient and half-closed |
| **Blocked** | The whole body morphs into a black **exclamation mark** |
| **Thinking** | The body morphs into **three pulsing dots** |
| **Done** | Eyes tilt, then thin colored ribbons swirl around the ball like orbit rings, a brief celebration |

A third-party "Grok Bot avatar system" site says the rings belong to Working. In the official demo
I captured them only after selecting Done (S; the third-party claim is SR and unofficial).

**How much to show (R).**

- They rejected the standard three animated dots: too little information, so you cannot tell
  working from stuck.
- A one-line written action made people want every step. Research showed they wanted the detail
  mostly for reassurance.
- The final design: the avatar's **motion is the first reassurance**, and **hovering shows the
  current action**.

**The Bot's computer has three levels of visibility (R).**

- **Status:** a title-bar icon turns purple while the computer is active.
- **Preview:** a pinned side panel.
- **Takeover:** full screen.
- Its wallpaper shifts lighter and darker through the day, so the Bot's computer feels separate
  from yours.

**Scale and restraint (R).**

- The roster reads like a messages list (S): avatar, name, last message, time.
- They set practical limits of about **50 Bots per account and 6 per group chat**.
- They removed window controls, computer-view options and agent metadata.
- They rejected dashboards and assignment boards in favor of a coordinating Bot.

**Later changes (SR; x.ai changelog blocked).** A refreshed look with **bigger eyes**, and an
avatar editor with square, sparkle, clover, flower, heart, house and star shapes.

**Not to confuse with:** Grok's July 2025 "Companions" (Ani, Rudi, Valentine, Mika), 3D anime
and red-panda characters with voice and lip-sync. A snippet says xAI announced retiring that 3D
mode in July 2026 (SR). Given the word "bot", the founder almost certainly means Grok Bot (I).

**Fit with Fovea (I).** This is a one-ink system: a solid body, two white eyes and motion for
state, with no gradients except the brief Done ribbons. On the black Island the body must be light
(white at some opacity, eyes punched out) or outlined, because a black body vanishes.

Sources: x.ai/news/introducing-grok-bot (R), x.ai/news/designing-grok-bot (R + S),
docs.x.ai/grok-bot/bots (R), search snippets for changelog and companions (SR).

---

## A4. Related animated AI presences

| Presence | Shape language | How states map to motion | Expressive or minimal | Sources |
| --- | --- | --- | --- | --- |
| **Microsoft Copilot "Mico"** (Oct 2025) | A soft, fluid blob or flame-like face designed by Psyop, defined by behavior rather than fixed features | Listens, reacts and **changes color** with the conversation's tone (warm and bright in lively talk, softer in serious moments); on by default in voice mode. Tapping it repeatedly turns it into **Clippy** (easter egg) | Middle: minimal form, emotionally expressive | TechCrunch (R), Psyop case study (R); color detail from TechJuice (SR) |
| **Google Gemini** | The four-color spark plus a particle system of **dots and pills moving like a shoal of fish** (Art&Graft, Gemini 3 identity) | Ambient state: particles drift quietly. Engaged: they form deliberate shapes. Particles stretch when moving and contract when settling | Abstract, no face. Gradient-heavy, which the Island forbids | Abduzeedo on Art&Graft (R) |
| **Apple Siri** | An edge glow, no character | Since iOS 18 a glowing light wraps the screen edge while Siri is active. Pre-WWDC 2026 reports said iOS 27 would move Siri into the Dynamic Island with a thin glow and "Search or Ask"; **I could not confirm what shipped** | Minimal, ambient | Apple Newsroom, June 2024 (R); MacTrast, iPhoneIslam, Business Today (SR) |
| **Anthropic: Clawd** | A small 8-bit orange pixel creature (crab-like) greeting you at the top of Claude Code sessions | Static greeting, no state animation | Minimal and charming | Stark Insider (R) |
| **Claude Code spinner** | A star glyph spinner plus a **rotating whimsical verb** (Accomplishing, Architecting, Baking…) and tips | The verb rotates while a turn runs. Users can append or replace verbs (`spinnerVerbs`). `prefersReducedMotion` cuts spinner, shimmer and flash animations | Text-first whimsy | code.claude.com settings reference (R) |
| **Claude Code "/buddy"** (April 2026) | 18 ASCII species (duck to capybara) with rarity tiers, hats and "shiny" variants, assigned deterministically per account | A 3-frame idle beside the prompt, speech-bubble comments on your session, `/buddy pet` floating hearts | Playful, low-fidelity. Shipped as an April Fools 2026 feature (R); reportedly pulled after about a week and later restored as a community plugin (both SR) | claudefa.st (R); search snippets (SR) |
| **Duolingo characters** (Rive) | Flat 2D cartoon cast; Lily in Video Call | A Rive **state machine** blends idle, listening, thinking and speaking; **8 head × 8 body idle clips combine into 64+ variations** so idle never loops visibly; processing delays play a head tilt or pondering pose so the wait feels intentional; 20+ viseme mouths per character for lip-sync | Highly expressive | Rive blog on Lily (R); Duolingo blog on visemes (R). No primary source specifically about Duo's own rig |
| **claudlet** (open source) | A pixel creature drawn in code, living on the desktop and reacting to Claude Code and Codex hooks | Poses for editing, reading, MCP, thinking, waiting on you, done and failed; a **VR visor over its eyes in auto or bypass mode**; each **subagent appears as a hatted companion trailing it (up to 3)** that waves goodbye on finish; click brings the terminal forward | Expressive, Tamagotchi-like | PyPI page (R) |
| **Notion Agent** | Named personal agent with an avatar and accessories (mobile customization calls it "Nosey") | Animation behavior not documented in what I found | Unknown | Search snippets only (SR) |
| **Independent Rive guidance** | n/a | Keep **activity, emotion and speech as separate inputs** so a concerned face can still talk, and fire completion only on real completion | n/a | dev.to (R; independent, not OpenAI) |

---

# Part B: agent control panels and how they show coding-agent activity

Format per item: layout · how state is shown · progress / current step · how "needs you" is
surfaced · scale · **one idea to steal** for a small notch board.

### B1. Claude Code agent view (`claude agents`, research preview) (R docs + S image)

- **Layout:** a full-terminal table grouped by state, with sessions that need you on top. The
  doc's sample groups are Pinned, Ready for review, Needs input, Working and Completed. A header
  counts, for example, 1 awaiting input · 1 working · 2 completed. A dispatch input sits at the
  bottom, and a "… 6 more" row collapses overflow.
- **State:** a leading icon whose color and animation carry state.

  | State | Icon |
  | --- | --- |
  | Working | Animated |
  | Needs input | Yellow |
  | Idle | Dimmed |
  | Completed | Green |
  | Failed | Red |
  | Stopped | Grey |

  A separate shape layer says whether the process is alive: ✻ or animated ✽ for running, ∙ for
  exited, ✢ for a sleeping /loop.
- **Progress:** each row is name · **one-line summary** · age.
  - Summaries are written by a Haiku-class model. While working, the line refreshes at most every
    15 s from the session's own output, and gets rewritten at turn end and every few minutes.
  - A blocked row shows the question itself.
  - The PR label is colored by status: yellow waiting, green passing, purple merged, grey draft or
    closed.
- **Needs you:**
  - **Peek panel:** shows the exact question with numbered choices and a reply box, without
    attaching to the session.
  - **Counters:** the terminal tab title shows the awaiting-input count. In other sessions the
    prompt footer shows a `← 2 agents` hint that changes color when the count moves and briefly
    shows `← 2 done`.
  - **Notifications:** sent for needs input, finished and failed.
- **Scale:** sessions across all projects (`--cwd` filters), grouping, overflow collapse,
  `--json` for scripts.
- **Steal:** *the row text becomes the question when the agent is blocked*, so you answer from the
  board in one step.
- Note: the header count conflicts with the Island's no-task-count rule (I).

### B2. Claude Code Desktop and Claude Projects Overview (R docs)

- **Layout:** the **Overview** pane groups threads into **Ready for review, Waiting on you,
  Working, Landing** (PR approved or queued to merge), **Idle** and **Resolved**. Resolved threads
  are marked done by you, by Claude after the last step, or **automatically after a week without
  activity**.
- **Needs you:** a **dot on the Overview button** when any thread waits on you, plus desktop
  notifications for errors and input requests. Code sessions spawned from your phone carry a
  "Dispatch" badge and push a notification when done or blocked.
- **Steal:** a **single resting dot** that means "something waits on you", and auto-resolving
  stale work.
- **Watch-out (R, GitHub issue #56770, May 2026):** a user reported the Claude app's yellow
  "asking for input" dot getting stuck permanently, which forced them to open every session.
  Their point: a stuck indicator is worse than none.

### B3. OpenAI Codex (Codex mode of the ChatGPT desktop app since July 9, 2026; cloud; mobile) (R)

- **Layout:** the desktop sidebar has an **Activity** view behind a bell (⌘⌥U) listing chats
  that are **unread, running or waiting for your response**, with filters (Work, Chat, Pinned,
  Scheduled) and **Mark all as read**.
  - Long tasks use **/goal**, with a progress row above the composer to pause, resume, edit or
    clear.
  - On iPad, Codex has a split view that keeps the task list beside the open task (R, a one-line
    release summary on releases.sh, Sept 23, 2026).
- **State:** Running / Needs input / Ready / Blocked (same vocabulary as Pets, see A1b).
- **Needs you:** the pet's red clock (A1b), system notifications (turn-completion alerts set to
  never, background only or always; separate toggles for permission and question alerts), and
  sleep prevention while running.
- **Steal:** the **priority rule for one aggregate avatar** (needs input > blocked > ready >
  running), plus "unread" as the definition of done-but-not-seen.

### B4. Conductor (Melty Labs) (R changelog and docs, homepage)

- **What it is now:** a Mac app plus Conductor Cloud (microVM sandboxes), multiplayer, iOS
  (Oct 2, 2026) and an API. It runs Claude Code, Codex, Cursor and OpenCode in isolated
  workspaces, one branch and PR each.
- **Layout:** a sidebar of workspaces that can be **grouped by status**, with pinned and emoji
  sections.
- **State:**
  - **Animated workspace status marks** in the sidebar.
  - An experimental **"Workspace status matrix"** (later on by default for cloud organizations)
    distinguishes routine runs, **attention**, errors, running PR checks and merged PRs. I could
    not see what the matrix glyph looks like (no image found).
  - Checks waiting on approval show a clock instead of looking pending.
- **Identity:** every workspace gets a **city name** (295 cities, with a "Passport" of cities
  visited). The work item (branch or PR title) stays primary; the city is where it lives.
- **Needs you:** notifications titled with the chat name, and optional fun **completion sounds**
  (a "Quack").
- **Steal:** a **stable, friendly identity separate from the task title** (city ≈ avatar), and
  distinct states for PR-level outcomes (checks running, merged).

### B5. Vibe Kanban (BloopAI) (R docs and homepage)

- **Status:** the homepage says Vibe Kanban is **sunsetting**; it continues as a
  community-maintained open-source project.
- **Layout:**
  - A kanban of issues: In progress, In review, Done (Backlog and Cancelled hidden).
  - Moving a card to In progress starts an agent in a worktree.
  - Workspaces have a sidebar with a flat or **accordion grouping by status**.
- **State:** Running, **Idle** (waiting for input), **Needs Attention** (pending approval, shown as
  a **raised-hand icon**), a blue dev-server indicator and a PR badge.
- **Steal:** the **raised hand** as the glyph for approval-needed. It is a gesture an avatar can
  literally perform.

### B6. Claude Squad (smtg-ai, TUI) (R README and source)

- **Layout:** a numbered list of instances. Each row shows the title, the branch and a **diff
  stat (+48,-47)**, beside Preview and Diff tabs.
- **State (from the source):** a spinner for Running or Loading, a green ● (#51bd73) for Ready,
  and a grey ⏸ for Paused. There is no explicit "needs input" state; Ready implies waiting for
  your next prompt.
- **Scale:** keyboard list for a handful of sessions (I).
- **Steal:** the **diff stat as a free progress proxy** for coding work.

### B7. Omnara (R Show HN, Aug 2025; homepage)

- **Then:** an "agent command center" (YC S25) that mirrored a Claude Code session to web and
  mobile.
  - It sent **push notifications when an agent needed input** and allowed one-tap approvals on
    the phone.
  - It worked by wrapping the CLI and parsing the session file.
- **Now (2026):** it has **pivoted** to an open-source managed-agent platform, an alternative to
  Claude Managed Agents.
- **Steal:** **answer without opening the session**: the approval is the notification.

### B8. Sculptor (Imbue)

- **What it is (R):** each agent runs in its own container. **Pairing Mode** syncs an agent's
  container state into your local repo and IDE. Sessions are saved with their plans and tool
  calls, and Codex support was added in Dec 2025.
- **Sidebar (SR, docs snippet):** agents appear in a left sidebar with an **auto-generated name
  from the prompt**. The Pairing Mode indicator stays visible whichever agent you are viewing.
- **Not found:** I could not open docs describing its status visuals.
- **Steal:** **auto-names from the request**, so each board entry is legible without typing a
  title.

### B9. Terragon (R homepage and OSS README; S dashboard image)

- **Status:** **shut down Feb 9, 2026**, with an open-source snapshot.
- **Layout:** a task list **grouped by date** (Today, Yesterday, Older). Each row shows a green
  check for done or a blue dot (likely unread or new, I), then title, age, repo and PR or check
  icons.
- **Needs you:** status streamed live to the browser, with browser notifications on completion.
- **Steal:** **check = done, dot = unread**, the cheapest possible pair of glyphs.

### B10. Crystal (stravu) (R README)

- **Deprecated in February 2026** and replaced by Nimbalyst, an AI-native editor workspace with
  worktree-isolated sessions.
- I did not find Crystal's old status UI documented in what I read.

### B11. GitHub Agent HQ, mission control and the Copilot app (R blog, docs, Help Net Security)

- **Mission control (Universe, Oct 2025):** one command center that follows you across
  github.com, VS Code, mobile and CLI. The **agents panel is reachable from any page on GitHub**.
  Each session has a log, steering prompts, Stop and Archive.
- **GitHub Copilot app (Build 2026, technical preview):**
  - A **"My Work"** view of active sessions, issues, PRs and background automations.
  - **Agent Merge** follows a PR through checks and reviewers until merged.
  - **Canvases** hold the work itself (a plan, PR, browser, terminal or deploy).
- **State visuals:** not detailed in the docs I read.
- **Steal:** the **"landing" phase**: work that is done but still shepherding a PR to merge is its
  own state, not "done".

### B12. Cursor (background agents → Cursor 3 Agents Window, Apr 2, 2026) (R docs and blog; S low-res)

- **Layout:** an agent-first window. **All local and cloud agents appear in one sidebar**,
  including ones started from phone, web, Slack, GitHub or Linear. Agent Tabs show several chats
  side by side or in a grid.
- **Progress and proof:** cloud agents return **demos and screenshots of their work** for you to
  verify, shown as a "Worked for 47m" walkthrough card (S).
- **State visuals:** the agents sidebar's state icons are not described in the docs I read.
- **Steal:** a **proof artifact (screenshot or clip) as the "done" face** of a session.

### B13. Warp (R docs)

- **Notification types:** **Complete**, **Request** (blocked on you: approvals, permission or idle
  prompts) and **Error**.
- **In-app signals:**
  - **Toasts:** at most 2 visible; they auto-dismiss, hover pauses the timer, and a click jumps to
    the session.
  - **Mailbox:** a bell panel with All, Unread and Errors filters and Mark all as read.
  - **Tab icons** show working, blocked, completed or errored, plus an **attention badge for
    unread**. Badges clear **automatically when you visit the tab**.
- **Orchestration:** child agents show in a **pill bar** with in-progress, succeeded, blocked,
  failed, error and cancelled states.
- **Steal:** **auto-clear unread on visit**, and a hard cap of two transient alerts.

### B14. Devin (Cognition) (R API reference)

- **State model:** two levels. `status` is new, claimed, running, exit, error, suspended or
  resuming. `status_detail` refines it:
  - While running: **working, waiting_for_user, waiting_for_approval, finished**.
  - While suspended: the reason, such as inactivity, user request or usage limits.
- **Steal:** **two flavors of "needs you"**, a question to answer versus an action to approve.
  They want different affordances.

### B15. Linear agents (R developer docs and Agent Interaction Guidelines)

- **Session states:** six states visible to users: **pending, active, awaitingInput, error,
  complete, stale**.
- **Liveness:** agents must acknowledge within **10 seconds** or the session is marked
  unresponsive.
- **Activity types:** thought, **elicitation** (asks you), action (for example "Searching", then
  "Searched" with a result), response and error.
- **Ephemeral activities** are replaced by the next one, a one-line "current step".
- **Agent Plans:** a checklist whose items are pending, in progress, completed or canceled.
- **Guidelines:** give instant feedback, and make internal state (thinking, waiting, executing,
  finished) clear at a glance and inspectable on demand.
- **Steal:** an explicit **stale or unresponsive state**, and the **ephemeral one-liner**.

### B16. Others found

- **Superset** (R changelog, Jan 2026):
  - 3-color workspace status: **amber working, red permission needed, green ready for review**,
    fed by Claude Code hooks.
  - **Clicking acknowledges**: review becomes idle, and permission becomes working.
  - A compact icon-only sidebar and a searchable workspaces page.
  - **Steal:** click-to-acknowledge.
- **Muse status pill** (A2): the persistent "what is it doing now" pill, with emoji per status
  line.
- **Grok Bot roster** (A3): the avatar carries state, hover shows the action, and the roster reads
  like a messages list.
- **claudlet** (A4): subagents as small companions following the main pet.

---

## Cross-cutting synthesis for a notch board (I)

**State vocabularies mapped to Fovea's (Working / Needs you / Complete-unread / Failed):**

| Fovea | Codex Pets | Claude agent view | Grok Bot avatar | Warp | Devin | Linear | Vibe Kanban | Superset |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Working | Running | Working (animated) | Working; Thinking (dots) | working icon | working | active | Running | amber |
| Needs you | Needs input (red clock) | Needs input (yellow) | Waiting (dash eyes); Blocked ("!") | Request | waiting_for_user / waiting_for_approval | awaitingInput | Needs Attention (raised hand) | red |
| Complete, unread | Ready (green check) | Completed (green), Ready for review | Done (ribbons, then settles) | Complete + unread badge | finished | complete | In review | green |
| Failed | Blocked | Failed (red) | probably Blocked (the post does not separate failure) | Error | error | error | — | — |
| Idle / stale | idle row | Idle (dimmed), Stopped (grey) | Idle | — | suspended | pending, **stale** | Idle | idle |

**Patterns worth carrying into the redesign:**

1. **The avatar carries state; there is no separate badge** (Grok Bot, Muse, Codex Pets). For
   Fovea: one face per session, its motion saying Working / Needs you / Done. The Island's amber
   and coral tints can stay tied to the status word, as Tokens already requires.
2. **Identity and state on separate channels.**
   - Identity: shape, accessory, name, and color where allowed (dots, Grok Bot, Conductor
     cities).
   - State: motion and eyes.
   - On an ink-only Island, identity should come from **silhouette and accessory** rather than
     hue.
3. **At rest, one aggregate face with a priority rule**: needs input > failed > ready > running
   (Codex Pets). This directly addresses DISPATCH_V2's open item that nothing at rest says a slow
   task is done.
4. **Hover for the current action, one line max** (Grok Bot, Linear's ephemeral activity, Claude
   agent view's summary). When blocked, the line *is the question* (Claude agent view, Omnara).
5. **Make waiting look intentional**: Lily's head tilt, Muse's headphones-and-laptop, Codex's
   expectant "waiting" pose distinct from idle. Celebrate Done briefly, then settle (Grok Bot
   ribbons, Muse jump and star).
6. **Never let a state lie.** Auto-clear unread on visit (Warp, Superset). Add a stale state when
   an agent goes quiet (Linear). The stuck-dot bug report (B2) shows the cost.
7. **Idle without noise:** idle needs visible micro-variation but no gestures (hatch-pet).
   Randomized combinations prevent a visible loop (Duolingo 8 × 8). With reduced motion, use one
   still frame (Codex Pets, Claude Code `prefersReducedMotion`).
8. **Two "needs you" flavors:** a question (answer inline) versus a permission (approve), as in
   Devin, the Claude peek panel and Vibe Kanban's raised hand.
9. **Production formats seen:**
   - Sprite atlases with per-frame timings (Codex Pets: 8 × 9 at 192 × 208).
   - Rive state machines (Duolingo; independent Rive studios pitching dots-style avatars).
   - Simple vector shapes plus eyes (Grok Bot), the cheapest to draw natively in SwiftUI and the
     most consistent with "no custom faces, one ink" (I).
10. **Conflicts with Fovea's rules:** header counts (Claude agent view, Warp mailbox),
    gradients (Gemini, Siri), and provider-colored status dots across many sessions. Grok Bot's
    flat body plus eyes plus motion is the reference least at odds with the Island spec (I).

---

## Frame grabs and screenshots I captured (for the design team)

Folder: kept outside the repo (third-party screenshots), in the Oct 8 session's scratch folder.

- `sheet-grokbot-states.png`: Grok Bot avatar in Idle, Working, Waiting, Blocked, Thinking and
  Done (3 frames each, from x.ai's live demo)
- `grokbot-final-avatars.png`: the 8 flat shapes with slit eyes
- `grokbot-styles.png`: xAI's style exploration grid
- `grokbot-roster.png`: the roster (avatar, name, last line, time)
- `muse-status-pill.png`: Alex Cornell's early status-pill mock ("Jollybot · is researching Carmel")
- `muse-jolly-wang.png`: Jolly
- `sheet-muse-avatar.png`: a custom Muse avatar's animation cards (idle, headphones and laptop,
  orb, jump, star and cape)
- `muse-avatar-chat-top.png`: the Muse avatar perched on a name pill in the chat header
- `dots-customize.png`: the dots customization sheet (colors, characters, pets)
- `dots-activity.png`: a dot's profile (Active, Call, Slack, Computers, Recent activity)
- `dots-carousel.png`: OpenAI launch image (Felipe peeking over a conversation)
- `sheet-dots-launch3.png`: launch-video frames (chat header avatar, typing bubble, call screen)
- `claude-agent-view.png`: Claude Code agent view (official docs image)
- `claude-squad.png`: Claude Squad instance list
- `terragon.png`: Terragon task list

## Source URLs

**OpenAI dots and Codex Pets**

- https://techcrunch.com/2026/09/29/openai-launches-dots-its-bubbly-agentic-avatar/ (R)
- https://gizmodo.com/with-dots-openai-wants-you-to-stop-being-afraid-of-its-ai-agents-2000819082 (R)
- https://tech.yahoo.com/ai/chatgpt/articles/openai-dots-own-little-guy-213519742.html (Mashable, R)
- https://fortune.com/2026/10/02/meta-openai-ai-agent-mascots-jolly-dots-trust/ (R)
- https://www.engadget.com/2275148/dont-let-the-adorable-ai-agents-fool-you/ (R)
- https://www.macstories.net/stories/openais-dots-a-first-look/ (R + S)
- https://designcompass.org/en/2026/09/30/openai-dots-always-on-ai-agents/ (R)
- https://animaapp.com/blog/agentic/openai-dots/ (R)
- https://learn.chatgpt.com/docs/dots.md, /dots/getting-started.md, /dots/controls.md, /dots/tasks-and-memory.md (R)
- https://api.fxtwitter.com/OpenAI/status/2104984504133918973 (launch video, S)
- https://www.fastcompany.com/91615068/openai-dots-agent-crew-of-friendly-mascots (blocked 403; "Dottie" detail SR only)
- https://dev.to/uianimation/chatgpt-dots-by-openai-building-expressive-ai-assistants-with-rive-animation-2m7g (R; independent, explicitly not about Dots' real design)
- https://www.engadget.com/2162796/openai-introduces-ai-generated-pets-for-its-codex-app/ (R)
- https://www.pcworld.com/article/3131011/i-love-my-new-codex-ai-pet-and-now-i-want-one-in-every-app.html (R)
- https://learn.chatgpt.com/docs/pets.md, https://learn.chatgpt.com/docs/notifications.md, https://learn.chatgpt.com/docs/long-running-work.md (R)
- https://raw.githubusercontent.com/openai/skills/main/skills/.curated/hatch-pet/SKILL.md and .../references/animation-rows.md (R)
- https://releases.sh/release/rel_ju1EtELr_TlXn7mNqKSQH-chat-work-codex-merged-into-single-desktop-app (R)

**Meta Muse and Jolly**

- https://tech.yahoo.com/ai/meta-ai/articles/meta-gives-muse-adorable-mascot-142824348.html (Axios, R)
- https://www.nbcmiami.com/news/national-international/meta-muse-ai-agent/3864177/ (R)
- https://newatlas.com/consumer-tech/meta-muse-ai-agent-charm/ (R)
- https://runtimewire.com/article/meta-muse-realtime-avatar (R)
- fxtwitter JSON for x.com/alexcornell/status/2102560084836704642, x.com/alexandr_wang/status/2102573821807202724, x.com/AGTPinsights/status/2102636424550088886, x.com/testingcatalog/status/2097472570450726970, x.com/dps/status/2098261414335160641, x.com/_simonsmith/status/2104192411425775772 (R), plus videos from x.com/christinesed/status/2098259891362431399 (S) and x.com/spottedinprod/status/2097461280705565016 (S; booking flow, no avatar detail)

**Grok Bot**

- https://x.ai/news/introducing-grok-bot (R)
- https://x.ai/news/designing-grok-bot (R + S)
- https://docs.x.ai/grok-bot/bots (R)
- x.ai/changelog/bot (blocked; SR)
- https://www.grokbotexplained.app/avatar-system (third party; SR only)

**Related presences**

- https://techcrunch.com/2025/10/23/microsofts-mico-is-a-clippy-for-the-ai-era/ (R)
- https://psyop.com/work/microsoft-ai-mico (R)
- https://abduzeedo.com/node/89300 (R)
- https://www.apple.com/newsroom/2024/06/introducing-apple-intelligence-for-iphone-ipad-and-mac/ (R)
- https://www.starkinsider.com/2025/10/clawd-ai-retro-mascot-command-line.html (R)
- https://code.claude.com/docs/en/settings-reference.md (R)
- https://claudefa.st/blog/guide/mechanics/claude-buddy (R)
- https://rive.app/blog/duolingo-s-ai-powered-video-call-brings-lily-to-life (R)
- https://blog.duolingo.com/world-character-visemes (R)
- https://pypi.org/project/claudlet/ (R)

**Control panels**

- https://code.claude.com/docs/en/agent-view.md (R + S)
- https://code.claude.com/docs/en/desktop.md (R)
- https://code.claude.com/docs/en/claude-projects.md (R)
- https://github.com/anthropics/claude-code/issues/56770 (R)
- https://www.conductor.build/ (R)
- https://www.conductor.build/docs and /docs/concepts/{workflow,parallel-agents} and /docs/reference/cities (R)
- https://www.conductor.build/changelog (R)
- https://www.vibekanban.com/ (R)
- https://vibekanban.com/docs/workspaces/interface.md and /issue-management.md (R)
- https://raw.githubusercontent.com/smtg-ai/claude-squad/main/README.md and /ui/list.go (R + S)
- https://news.ycombinator.com/item?id=44878650 (R)
- https://www.omnara.com/ (R)
- https://raw.githubusercontent.com/omnara-ai/omnara/main/README.md (R)
- https://imbue.com/blog/sculptor-announce (R)
- docs.imbue.com (SR)
- https://www.terragonlabs.com/ (R)
- https://raw.githubusercontent.com/terragon-labs/terragon-oss/main/README.md (R + S)
- https://raw.githubusercontent.com/stravu/crystal/main/README.md (R)
- https://github.blog/news-insights/company-news/welcome-home-agents/ (R)
- https://docs.github.com/en/copilot/how-tos/copilot-on-github/use-copilot-agents/manage-and-track-agents (R)
- https://www.helpnetsecurity.com/2026/06/08/github-copilot-app-ai-coding-agents/ (R)
- https://cursor.com/docs/agent/agents-window (R)
- https://cursor.com/changelog/3-0 (R)
- https://cursor.com/blog/cursor-3 (R + S)
- https://docs.warp.dev/_llms-txt/agents.txt (agent notifications section, R)
- https://docs.warp.dev/_llms-txt/automation-platform.txt (R)
- https://docs.devin.ai/api-reference/v3/sessions/get-organizations-session.md (R)
- https://linear.app/developers/agent-interaction (R)
- https://linear.app/developers/aig (R)
- https://superset.sh/changelog/2026-01-06-sidebar-workspaces-status (R)
