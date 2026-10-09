# The control board: notch products and agent control panels (Oct 9)

**Why.** Yulun on Oct 9: everything else in the Native design is right, but the control board is
not. This folder collects how other notch products and agent control panels lay out the same job, so
Yulun can pick what to reference.

**The board:** `control-board-references.html`, one self-contained page with 53 screenshots, grouped
by layout. Each reference has:
- its source;
- what the layout does;
- what it could give our board;
- where it runs against the Island's rules.

Click an image to see it larger. The screenshots are of other products, for internal reference only.

**How it was gathered.**
- Discovery: web search.
- Every page was visited and captured with gstack's browse tool.
- **Product Hunt** answers automated visits with a security check (403), and it was not bypassed.
  Its launches come from the products' own sites and GitHub.
- **X** was read through the public api.fxtwitter.com mirror, as in the Oct 8 research.
- **NotchNook's** own page now returns 404; its image is from a BGR article.
- **Not shown:** six agent-notch repositories have no screenshots in their READMEs:
  - lihao505/agent-notch
  - pnpmx/AgentNotch
  - jibc45453jibc/agent-island
  - x-typo/codex-live-activity
  - farouqaldori/vibe-notch
  - adamlyttleapps/notchy (its README image is missing)

**Related:**
- `../apple-native/` has Apple's own patterns: Live Activities on the Mac, snippets, popovers.
- `../creatures/ai-avatars-and-agent-panels.md` has the state vocabularies of the agent panels, in
  text.

## The board's sections

0. **Our board today:** Original, Native attached (Light), Native floating (Dark).
1. **A pill at rest, a list when open:**
   - [Vibe Island](https://vibeisland.app/) ([launch post on X](https://x.com/edwardluox/status/2078111197212414447),
     929K views)
   - [NotchHUD](https://github.com/thilinaa/notch-agent-hud)
   - [X Island](https://xisland.app/)
   - [CrewTower](https://crewtower.app/)
   - [CodeIsland](https://github.com/wxtsky/CodeIsland)
2. **Compact, Live Activity style:**
   - [notch (hyderay)](https://github.com/hyderay/notch)
   - [AgentsRoom](https://agentsroom.dev/features/dynamic-island)
   - [Agent Notch for Omarchy](https://github.com/GNSB/omarchy-agent-notch)
   - [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit)
3. **Denser session lists:**
   - [Notch Pilot](https://github.com/trustunsafe/Notch-Pilot)
   - [Open Agent Island](https://github.com/patheonsceo/openagentisland)
   - [Agent Notch (realfishsam)](https://github.com/realfishsam/agent-notch)
   - [AgentBro](https://github.com/shirenchuang/agentbro)
4. **Deciding in place:** approvals and questions in CrewTower, CodeIsland, Vibe Island, Open Agent
   Island, Notch Pilot and X Island.
5. **Beside the notch, or at the screen's edge:**
   - the [side-notch concept on X](https://x.com/hivinz_/status/2092996055248126353) and
     [rivantmedia/agentnotch](https://github.com/rivantmedia/agentnotch), which builds it;
   - [Boring Notch](https://github.com/TheBoredTeam/boring.notch)'s compact view.
6. **A session opened in the notch:**
   - [Coucou (Mochi)](https://github.com/Louis-CFM/coucou)
   - CodeIsland ([dev.to](https://dev.to/krisying/i-turned-my-macbooks-notch-into-a-control-center-for-ai-coding-agents-2o57))
   - AgentBro
7. **General notch products:**
   - [NotchDrop](https://github.com/Lakr233/NotchDrop)
   - [Atoll](https://github.com/Ebullioscopic/Atoll)
   - NotchNook
   - Notchy ([X](https://x.com/adamlyttleapps/status/2037731313562923121))
   - Product Hunt launches, as links only: SuperIsland, Islet, Perch, Pulse Island, NotchPop,
     AgentNotch.
8. **Agent control panels:**
   - [Claude Code agent view](https://code.claude.com/docs/en/agent-view)
   - [GitHub's agents panel](https://github.blog/news-insights/product-news/agents-panel-launch-copilot-coding-agent-tasks-anywhere-on-github/)
   - [GitHub Mission Control](https://github.blog/news-insights/company-news/welcome-home-agents/)
   - [Cursor 3's Agents Window](https://cursor.com/changelog/3-0)
   - [Conductor](https://www.conductor.build/)
   - [Orca](https://www.onorca.dev/)
   - [Vibe Kanban](https://www.vibekanban.com/)
   - [Warp](https://docs.warp.dev/agents/using-agents/managing-agents)
   - [Superset](https://superset.sh/)
   - Claude Squad
   - Terragon

## What recurs

- **At rest, one signal:**
  - a pill, or the agents' faces beside the notch;
  - the rest stays hidden until something changes.
- **Open, urgency first:** needs you, then working, then done, as sections, tabs or one sorted list.
- **A row is short:**
  - the project or title;
  - one line: your last request, or what it is doing now;
  - the agent as a tag, and an age.
  - Only the row that needs you grows, or opens.
- **Decisions in the row:** the approval or the question opens inside the session's row, with "Show
  all sessions" under it.
- **Jump back, don't read here:** the main action is to jump to the exact terminal or app.
- **Opening by itself shows one:** when the notch opens on its own, CrewTower shows only the session
  that needs you.
- **Unread and Mark all read:** done work stays until it is seen.

**Common in these apps, and against the Island's rules (AGENTS.md):**
- **Counts** in pills and headers. The Island never shows a task count.
- **Usage and context meters.** Usage figures live only on Usage & Plan and the avatar's arc.
- **Step lists, transcripts and terminals in the notch.** The Island allows one line of activity per
  task; steps fold under an answer until opened.

## To choose

- **Rest:** nothing but the notch (today), a pill with a word, or faces beside the notch.
- **Open:** sections (today), tabs by state, or one list sorted by urgency.
- **A row:** two lines (today), or one line with only the row that needs you growing.
- **A session:** opened in its row (Vibe Island, X Island), or its own view (today).
- **Decisions:** in the row with "Show all", or in their own card.
- **When the notch opens by itself:** the whole board, or only the session that needs you.
