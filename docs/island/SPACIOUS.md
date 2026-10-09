# Spacious: the notch's open panels, roomier and more Mac-like

**What prompted this.** On Oct 6, Yulun said the notch is "basically alright", but the panels it
opens feel "too compact and not extremely aesthetically appealing". They should be more
macOS-native and have more space, closer to the Fovea Captures app (`Prototypes/FoveaCaptures`).

**In the Notch Workbench** there is a **Density** switch (Compact / Spacious) at the top right of
the window's toolbar (View › Compact Panels ⌘1, Spacious Panels ⌘2).
`--density=compact|spacious` sets it for one run. Spacious is the default; Compact is the panels
exactly as they were through Oct 6, kept for the comparison.

**What changes, and what doesn't.**
- **Changes:** every open panel. That is Choose chat (with its model sheet and every-chat browser),
  the control board, the session in the notch and the pulled-out window, the #19 chat sheet, the
  queue, the voice errors' notice, and Paste not found.
- **Unchanged:** the resting notch, the voice bar (with the notice and the countdown inside it), and
  the opened referent stack. The Island's geometry in Core (`IslandLayoutSpec`) is untouched, so
  `FoveaCoreTests` still pins the same numbers.

## Why the panels felt compact

**What the panels used:**
- text from 10.5 to 13.5 pt;
- Allow and Deny 20 pt tall; chips 24–26 pt; close targets 20–24 pt;
- 2 pt between a row's two lines; bottom paddings of 4–8 pt.

**Where that density comes from:** most notch apps share it, because they start from one codebase
(Boring Notch's 19/24 corners, 10–11 pt type).
- Claude Island (the closest to our board) uses 13 pt medium titles, 11 pt subtitles and 22 pt
  Allow/Deny.
- Open Island uses 10.5 pt monospaced metadata.

**What makes a panel read as the Mac's** is the Mac's own baselines:

| Baseline | Value | Source |
|---|---|---|
| Body text, the default | 13 pt; Title 3 15, Title 2 17; nothing under 10, small text 11 or up | [Apple] HIG Typography; HIG Widgets |
| Hit target | 28×28 pt by default, 20×20 at least | [Apple] HIG Accessibility |
| Room around a control | about 12 pt with a visible background or border, about 24 without | [Apple] HIG Accessibility |
| Regular push buttons | now 24 pt (they grew about 4 pt); large 28; extra large 36 | [Measured] on this Mac (macOS 27); [Apple] WWDC25 310 |
| Large controls | capsules | [Apple] WWDC25 310 |
| Inner corners | concentric: the outer radius minus the margin | [Apple] WWDC25 356, HIG Live Activities |
| The island | black and opaque, its height fitted to what's in it | [Apple] HIG Live Activities |
| Prominent buttons | one, or at most two, per view | [Apple] HIG Buttons |
| Menu items | 24 pt, 13 pt text | [Measured] on this Mac |

**Fovea Captures** reads as native for the same reasons:
- a 4/8/12/16/20/24/32 scale, with more space between groups than inside one;
- 13 pt body and 15 pt reading text (line spacing 5), 17 pt headers;
- 28–32 pt round icon buttons; 26–34 pt capsules;
- concentric corners;
- springs with no bounce, and a symbol that bounces once on hover.

Spacious brings those to the notch, still white at opacities on black and with no gradients.

## The numbers

| Role | Compact | Spacious |
|---|---|---|
| Content inset from the outline's edge | 35 | **41**: the ears' 19 plus a 22 pt margin |
| Gap below the notch | 10 | **14** |
| Gap between blocks | 12 | **16**; 8 inside a block |
| Bottom corners | Dispatch panels 28, board 22, notices 24 | **32** for Dispatch panels and the board, **28** for notices |
| Rules | 1 pt between header, question and answer | only the header's (0.5 pt, white 0.12); space parts the rest |
| Session question | 15 semibold | **17 semibold** (Title 2) |
| Session header title | 14 semibold | **15 semibold** |
| Choose chat request | 14 medium | **15 regular**, line spacing 4 |
| The answer | 13.5, line spacing 3; headings 14; code 11.5 | **15, line spacing 5** (Captures' reading text); headings 16; code 12.5 |
| Board row | 46 pt; 20 pt icon; title 13.5; line 11.5; 2 pt between | **54 pt; 24 pt icon; title 14; line 12.5; 4 pt between** |
| Board section labels | 11 semibold at 0.45 | **12 semibold at 0.5** |
| Words in buttons and chips | 11.5–12.5 | **13 medium** |
| Allow, Deny, Stop, Answer again, Retry, Send now, Open … | 20–26 tall | **28 tall**, 14 pt padding, 8 apart |
| ✕ and back | 20–24, a bare glyph | **28 round**, a white 0.08 plate (0.14 under the pointer) |
| Chat and model pills; Send | 32 | **36** |
| Chips | 24–26 | **30**, 8 apart |
| Rows: every-chat browser, model sheet / queue | 30 / 34 | **36 / 40** |
| The box to ask more | 34 tall; send 24 | **40 tall; send 28** |
| Widths | board, notice and Paste not found 400; Dispatch 660 | **460**; Dispatch stays 660 (the room goes inside it) |
| Pulled-out window | 340 × 468 | **380 × 520** |

Every number is a token in `Prototypes/FoveaWorkbench/WorkbenchTokens.swift`, written as
`pick(compact, spacious)` (`Density.swift`). A view or layout that reads one is drawn again when the
switch changes.

Kept from Captures and the HIG:
- concentric inner radii (a row's highlight is 10 inside a 32 corner with a 22 margin);
- monochrome symbols;
- monospaced digits for times;
- at most one filled button per view (Allow, or Send);
- springs with no bounce.

## Smaller fixes along the way

- **Hard-coded values.** The session, Choose chat, the browser, the pulled-out window, the answer's
  Markdown, the queue and the notices had values written in their views. They are tokens now
  (AGENTS.md: never hardcode a size in a view). The Markdown's measured height reads the same
  tokens as the view draws with.
- **The browser's height.** Choose chat measured the every-chat browser 1 pt shorter than it draws.
  It now measures it as the #19 sheet does, in both densities.
- **The session's question.** Compact measured it with 2 pt of line spacing that the view never set,
  and keeps that behaviour. Spacious measures and draws it with the same 4.

## Sources

- [Apple] HIG
  [Typography](https://developer.apple.com/design/human-interface-guidelines/typography),
  [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility),
  [Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities),
  [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons),
  [Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets)
- [Apple] WWDC25 [356](https://developer.apple.com/videos/play/wwdc2025/356/) (concentricity) and
  [310](https://developer.apple.com/videos/play/wwdc2025/310/) (control sizes)
- [Measured] AppKit control, menu and list sizes, read on this Mac (macOS 27.0.1)
- [Code] [Boring Notch](https://github.com/TheBoredTeam/boring.notch),
  [Claude Island](https://github.com/farouqaldori/claude-island),
  [Open Island](https://github.com/Octane0411/open-vibe-island)
- Fovea Captures: `Prototypes/FoveaCaptures/DESIGN.md` and `Tokens.swift`
