# Open any chat from the notch (Oct 24)

Ryan, Oct 24: "when the user hovers their mouse over the notch, they can open any chat. The notch
does not need to contain an input field; it is simply for selecting a chat. Users will also be able
to pin chats there." The search button "should always be present, even when other tasks or agents
are running, so the user can open any session at any time." The first message also asked that the
search let you "type to search or have the agent choose".

So the board, on hover, always has two more things:
- **a search** (any chat of Claude Code's or Codex's, typed or picked);
- **the chats you pinned**.

There is no box for a request: the notch only chooses the chat.

## Decided (Oct 24, later)

Ryan: "lets go with top bar. when the user clicks on a chat in the search button, they should be
able to open the chat on the notch. also, the maximum number of chats there should be 5, if more
than 5, the user should scroll through all." Then: "dont have the choices from the menu bar now,
delete those."

- **The board is A, the top bar**, on the real Mac (`boardSearch`, in
  `FoveaV1/Sources/FoveaIsland/Feedback/OpenChat.swift`):
  - nothing running: "Hello, Ryan." with the search beside it;
  - running: the greeting and the search on a bar over the list;
  - the pinned chats first, five at most (the rest are in the search's Pinned);
  - then the sessions running, five in view and the rest a scroll away (Ryan, later: "for the
    sessions running, if there's more than 5, also collapse to 5 and let the user scroll to find").
    ↑↓ scroll the row they reach into view.
  - "Remembered" (NH-03), while there is one, sits under the greeting, so the search doesn't move.
  - The first run's board stays as it was: it teaches the board with its own sessions.
  - B, C and D are gone from the code, and so is the menu bar's switcher; their pictures stay in
    `FoveaV1/build/open-any-chat/`.
- **The search lists every chat:**
  - Suggested, Pinned, then Recent, which is every other chat, the most recent first.
  - Five chats in view (`OpenChat.rowsVisible`), the rest a scroll away.
  - A chat that can't take a request is dimmed and says why, and doesn't open.
- **A chat picked opens in the notch:**
  - One Fovea has a session in opens as it is.
  - Any other opens as a session of its own, with nothing sent from Fovea yet:
    - its header, and "Last active 9h ago in Futuro. Ask below: it goes into this chat.";
    - Open in its agent;
    - the box, "Ask in this chat", ready to type in.
  - What's asked there goes into that chat, works, and joins the board.
  - Back (or Esc with nothing typed) returns to the board.
- **Pins are kept in the prefs** (`FoveaPrefs.pinnedChats`). A pin is set from a row in the search
  (its pin button, or the row's menu), and unpinned the same way.
- **Checked:** `--smoke` walks every step of the above (15 checks).

## The comparison (Oct 24)

Four designs were built on the real notch for comparison. Their pictures are in
`FoveaV1/build/open-any-chat/` (not in the repo):
- `open-any-chat-closeup.png`: running and the search opened, the four side by side;
- `open-any-chat-floating.png`: every state, floating (Ryan's look);
- `open-any-chat-attached.png` and `open-any-chat-dark.png`.

## The search (the same in all four)

- **Opened, nothing typed:**
  - **Suggested:** Fovea's pick (routing's prediction, the last chat sent to, with why);
  - **Pinned:** the chats you pinned;
  - **Recent:** the four most recent others that can take a request.
  - That is the "have the agent choose" half: the pick is first, one click away.
- **Typed:**
  - chats whose title or project has the words, most recent first, the words set heavier;
  - Return opens the first; "No chats match" when none does.
- **A row:** the agent's icon, the title over its project and agent, and how long ago. Under the
  pointer, a pin button (pin, or unpin when it's pinned); pinned rows show a small pin by the time.
- **A click** opens the chat in the notch, as a row on the board opens its session.
- **Esc** closes the search, then the board. While the search is open, the board stays when the
  pointer leaves (`hoverHolds`). The island's window takes the keys while the field shows.

## The four designs

| | Where the search is | Where the pinned chats are | Cost |
|---|---|---|---|
| **A · Top bar** | A bar over the board: "Hello, Ryan." and the search at the right. With nothing running, the Hello block keeps its two lines with the search beside them | First in the list, as full rows, a seam under them | A row of height; the greeting on every hover |
| **B · Beside the notch** | In the right ear, hugging the notch, as the Dynamic Island's trailing side. Floating, the ears are a band over the panel (the `split` surface the Wings board uses) | Their agents' icons in the left ear, three at most; the rest in the search | No height; the board itself unchanged. Pins are icons only, so two Claude Code chats look alike until hovered |
| **C · Pinned shelf** | At the end of the shelf | Chips across the top (icon and title), as Arc's and Safari's favourites. Nothing pinned: a dashed "Pin a chat" | A row of height; titles truncate past three chips |
| **D · Bottom bar** | Apart at the bar's right, as iOS 26's tab bar; the search's field opens at the bottom too | The same chips, under the list | A row of height, and the farthest from the pointer, which is at the notch when the board opens |

## What the research says

- **Notch products put their controls beside the notch.** The Dynamic Island's compact view has a
  leading and a trailing side. Boring Notch, NotchNook and Atoll keep their tabs and buttons in the
  top row (docs/island/research/control-board, §5 and §7). That is B.
- **Search at the top trailing for a pointer.**
  - On iPhone, iOS 26 moves the search field to the bottom, for the thumb; on iPad it sits at the
    top trailing corner (nilcoalescing on iOS 26's search).
  - The Mac's toolbars put search at the top trailing corner too (Finder, Mail, Notes).
  - The pointer is already at the notch when the board opens. A and B are closest to it; D is the
    farthest.
- **Pins live above the rest, apart.**
  - ChatGPT pins chats in a section over its history.
  - Arc keeps its favourites at the top, the day's tabs below.
  - Raycast's favourites sit at the top of its root search.
  - Claude's desktop app has no pins (a Claude Code feature request asks for them).
  - So A's rows and C's shelf follow the common pattern; B's icons are the Dynamic Island's.
- **Finding beats organizing** (Arc's command bar): the search does most of the work, and the pins
  are for the few chats you return to daily.

## My pick (before the decision)

**B's search with A's pinned rows.**
- The search in the right ear: no height, the shortest move from the notch, and the same place
  whether the board is busy or empty.
- The pinned chats as full rows at the top of the list, so each is told apart by its title.

Each design also runs as it is.

## Still open (after the pick)

- **A chat's history.** Oct 24: the sample chats a request goes to, and the pinned ones, open on
  their exchanges so far (`V2SampleHistory.swift`), the last one where the chat is now; asked
  there, that one joins the ones before. The other sample chats still open on "Last active…". A
  real chat's exchanges would be read from its agent (Claude Code's session files); in 1.0 the
  agents are simulated.

## Running them

- Picture a state: `--demo chats:<state>`, the states `hello`, `pinned`, `board`, `open`, `search`
  and `opened`.
- Try it: `--demo chats:rest`, the sample sessions and pins on a board that opens only when the
  pointer reaches the notch (Ryan: "Only when the user moves their mouse onto the notch, then that
  should open").
- Picture them all: `--design-shots notch <dir> --only …` (`IslandController.openChatStageNames`).

## Sources

- [SwiftUI search in iOS and iPadOS 26](https://nilcoalescing.com/blog/SwiftUISearchEnhancementsIniOSAndiPadOS26)
- [WWDC25: Build a UIKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/284/)
- [Spotlight in macOS Tahoe](https://techcrunch.com/2025/06/09/apple-updates-spotlight-to-take-actions-on-your-mac/)
- [Arc design study](https://blakecrosley.com/blog/design-study-arc)
- [Arc's sidebar](https://www.howtogeek.com/888738/ways-arc-transforms-your-web-browser-experience/)
- [Raycast's search bar and favourites](https://manual.raycast.com/search-bar.md)
- [Pinning a chat in ChatGPT](https://www.guideflow.com/tutorial/how-to-pin-a-chat-from-the-sidebar-in-chatgpt)
- [Pinned chats request, OpenAI community](https://community.openai.com/t/feature-pin-chats-for-quick-access-in-sidebar/1035278)
- [Claude Code issue 35185](https://github.com/anthropics/claude-code/issues/35185)
