# The window in five looks, to match the notch (Oct 27)

Ryan, Oct 27, after the notch became Wings: "the notch becomes The app and the notch feel like two
entirely different products. I'm not sure exactly what the discrepancy is… Maybe it's because of the
color. If the UI were more minimal and whiter—more white, like Notion style—it might be a better fit."
After the research and five proposals in words: "actually build all 5 and lemme check. also, i want
the window to be smaller than now andd the size should be fixed."

## Why they read as two products

**What the research found:**
- **The notch speaks the website's language now:** a black object, white words, the website's EB
  Garamond for its voice ("Listening", "Hello, Ryan."), a waveform.
- **The window has its own:** a system-blue heatmap, teal and purple marks, colored app icons, grey
  cards on grey, New York titles.
- **Whiteness isn't the gap.** A black object over a white app is Apple's own pairing: the Dynamic
  Island over iOS apps.
- **What ties a small surface to its window**, in the products that do it well, is something of the
  one showing up in the other: one color (Granola's green), one component (ChatGPT's and Claude's
  quick entry is the window's own input), one type voice (Wispr Flow sets a few words in EB Garamond
  italic on its site).
- **Apple's HIG for the Dynamic Island:** "Don't add elements to your app that draw attention to the
  Dynamic Island." So the window shouldn't wear a black band to imitate the notch.

## The five

All five are built on Aligned's parts (`docs/window/ALIGNED.md`): its controls, its sidebar, its
row anatomy, its presses. They differ in their paper, their ink, their cards and their faces
(`T.Look` and `Palette.look()` in `FoveaV1/Sources/FoveaWindow/Tokens.swift`). In all five the
accent you chose in Appearance gives way to the look's own, and the kinds of capture have no color.

| Look | The window | The tie to the notch | Risk |
|---|---|---|---|
| **Monochrome Room** | White, the ink and nothing else: grey cards, the heatmap in greys, the notch's black as the main button and the chosen filter, its green, orange and red for state. The website's Garamond italic only for a page's title (Settings' panes, an empty page, a day's page) | The notch's black and its state colors; the serif as the notch's voice, once a page | So quiet Home has no voice of its own |
| **The Book** | The website's paper (#F8F8F5) and ink (#141414). The words you said set in EB Garamond, as the site sets its words (Chinese stays in the system face). Cards are entries under a rule, square, the page's own color. Titles and days in Garamond italic | The website and the notch's words, one type voice | Precious; serif rows scan slower |
| **Same Object, Two Sizes** | Aligned's white page, and the newest day's captures drawn as the notch draws its rows: black, white words at the board's opacities. The main button and the chosen filter black | The same object at two sizes | Heavy if there were more of them; it's only the newest day |
| **Lights Down** | As dark as the notch, whatever the Mac or Appearance says: near-black layers (#101010, cards #1A1A1A), white words, white as the accent. Titles in Garamond italic | The notch's material | Heavy for a window opened once a week; the odd one out on a light Mac |
| **Notion White** | Notion's white, its warm ink (#37352F) and greys, a warm grey sidebar (#F7F7F5), white cards with an edge and a soft shadow, its blue (#2383E2) for the one action, bold sans titles. No serif anywhere | Restraint, and Apple's own pairing | Fovea looks like any other app; the notch's Garamond becomes the odd one out |

**Not done in any of them:**
- **The notch is unchanged.** Notion White would take the Garamond out of the notch too.
- **Settings › Notch keeps its Glass (Light/Dark) and Panels (Attached/Floating) options.** Only the
  Wings bar and the board drafts are pure black; today's board, Choose chat, an open session and the
  pulled-out chats are still glass, and those options set them.
- **The real Wings drawn in Settings › Notch** (Same Object, Two Sizes' second half) isn't built.

## Picked: Notion White (Oct 27)

Ryan: "lets go with the build of notion white", with two fixes: "the top menu bar is too big. and 2 i
thnkk the capture card is too big as well… like reducing the information shown below the top bar of
icon, capture name, type, and time."

- **It's the window's design now:** the default when no other is chosen in View.
- **The top bar:** the Mac's compact toolbar, its controls 30 pt (they were 36): the filter's pill
  22 pt, search's circle, the circle around you.
- **The cards:** 196 × 128 (they were 220 square), four a row in the window. Under the header (the
  app's icon, the name, the type and the time), three lines of your words. What you took is a chip
  in the line, with no preview filling the card's foot. Opening a card shows everything, as before.
- The other six designs stay in View for now.

## Notion White, as white cards on grey (Oct 27)

Ryan, with a picture of Arc UI's site (uiarc.dev): "i like this feeling of white cards hovering on a
light gray background. make every button, dispatch card, and the activity dashboard on the top a card
hovering on the gray bg. use the same color as the reference pic." And of Arc UI: "find good ones and
replace some designs that are not good enough now."

**The colors**, sampled from the picture and taken from Arc's MIT design tokens (`foundation.css`):

| | Light | Dark |
|---|---|---|
| The ground | #EFEFF1 | #1A1A1B |
| Cards, buttons | #FFFFFF | #262627 |
| Words | #111111 | #F2F2F2 |
| Second, third | #5E5E5E, #8A8A8A | #BDBDBD, #9B9B9B |
| Hairline | #E8E8E8 | #3A3A3A |
| What's chosen, the main button | #262626 | #EDEDED |

**Shadows:** Arc's, in two layers each.
- Resting, for a card or a button: `0 1 2 / 3.5%` and `0 3 12 / 5%`.
- Raised.
- Floating, for the toast: `0 20 48 / 10.5%` and `0 3 10 / 4.5%`.

Dark mode triples them and adds a faint edge.

**What floats** (`T.Look.floats`, `FloatSurface` in `Glass.swift`):
- every toolbar control: the filters, the All/Dictation/Dispatch control, search, you;
- every capture card (16 pt corners);
- the year's dashboard, as one card (20 pt corners, 18 pt inside);
- Settings' groups, the chosen pane in the sidebar, the secondary buttons;
- the opened card's buttons;
- the toast.

The ground runs up behind the toolbar, with no rules under it or beside the sidebar.

**From Arc UI's free components (MIT), rebuilt in SwiftUI:**
- **The segmented control:** on a quiet track, the chosen one is a white card resting on it. On a
  white card (the toolbar's), the chosen one is the ground's grey, sunk into it.
- **The activity heatmap's squares:** 28 % rounded, no edge, over the look's empty square (#EEEEEE).
  The busier days are now the accent you chose, in four shades (Ryan, later on Oct 27: "make the
  color here the color of the accent"), in every look, not Arc's greys.
- **The copy button's confirmation**, quick and quiet: the new symbol fades in from 85 % in 0.16 s and
  the old one out in 0.1 s, with no blur and no bounce. On Oct 21 Ryan had the swap made instant
  after it bounced and blurred. This is neither; say if it should be instant again.
- **The toast:** a floating white card.

**Left out:**
- **Agent timeline, agent status, tool call and agent plan** are Arc Pro (paid, licensed), so they
  aren't rebuilt.
- **The window doesn't show an agent's work** ("a remote control, not a display").
- **Rolling digits on the year's total, and the heatmap's wave on arrival:** Ryan took the rolling
  total out on Oct 21 ("simpler is better").

## The window's size

880 × 620 pt, the same shape as before at 86% (it was 1024 × 720). It stays one size: no resizing, no
full screen (`T.Layout.window`). Home shows three columns of the usual cards at this width (four of
Notion White's), and the year graph fits the width.

## Trying them

- **In the app:** View › Current Design, Aligned Design, Monochrome Room, The Book, Same Object, Two
  Sizes, Lights Down, Notion White. The switch is immediate and kept for the next launch.
- **From a launch:** `Fovea --window-look=room|book|twoSizes|lightsDown|notion`.
- **Pictures:** `FOVEA_NO_ACTIVATE=1 Fovea --design-shots window <dir> --data-dir=<scratch> --fixture --looks`.
  - It pictures each look's Home, an open capture, and Settings › Notch and › Appearance, as
    `<look>-home.png`…
  - The window stays behind every other window, never comes forward, and the look you chose is put
    back afterwards.
