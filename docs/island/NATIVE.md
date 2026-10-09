# The notch's Native design

**Why.** On Oct 9 Yulun said the notch felt detached from the rest of the product.
- **The rest is macOS:** the onboarding (`Prototypes/FoveaOnboarding`) and the app
  (`Prototypes/FoveaCaptures`) read as current macOS.
- **The notch is not:** its board and sessions copy ChatGPT's and Claude's chat apps, in one black
  slab.
- **The ask:**
  - put every Voiceflow and Dispatch workflow in another tab of the Notch Workbench;
  - rebuild their design so the notch looks like the app and the onboarding: coherent colors, a
    Liquid Glass feel;
  - keep the content the same, any content change by Yulun's approval.
- **The research:** Apple's own designs for the same jobs are in `research/apple-native/`.

**In the Workbench.**
- **The toolbar's Original · Native** switches the design. So do View › Original Design (⌥⌘1)
  and Native Design (⌥⌘2), or `--design=native` for one run.
- **The sidebar's Native panels** (Attached · Floating, shown in Native) sets how what drops below
  meets the notch. `--native-panels=attached|floating` sets it for one run. Attached is the
  default.
- **The sidebar is otherwise the same in both,** so every Voiceflow, Dispatch and Feedback · Oct 6
  state shows in either design.
- **The Appearance switch** (System, Light, Dark) flips Native's glass between light and dark.
- **Shots:**
  - `swift run FoveaWorkbench --snapshot shots --only native-` gives:
    - `native-light-…` and `native-dark-…`: every state, the panels attached;
    - `native-floating-light-…` and `native-floating-dark-…`: the states with a panel, floating;
    - `native-desktop-…` and `native-floating-desktop-…`: Dispatch's bar, Choose chat, the board,
      a session and an error on the desktop, under the menu bar.
  - `Prototypes/shots/native/` keeps a curated set, `native-compare.png` (Original, Native Light
    and Native Dark side by side) and `native-panels.png` (Attached beside Floating, Light and
    Dark).
  - The screen must be unlocked: only a window capture draws glass.
  - `--render-native=<dir>` draws the main states off screen, the glass as a flat stand-in, for
    when it is locked.
  - `--only a,b` takes several names.
- **Motion:** `--record-native native.mp4` records both flows, Light then Dark, then the panels
  floating.
- **Checks:** `--smoke` ends with Native's 20 checks; `--smoke --only-native` runs those alone.
  They cover:
  - the tab;
  - the inks;
  - the shapes, attached and floating, and the gap;
  - the hover across the gap;
  - the verb;
  - the same words in both designs;
  - the pixels: the notch black, the panel light in Light and dark in Dark, attached and floating;
    Voiceflow's and Dispatch's bars glass, light in Light and dark in Dark.

## Decided with Yulun (Oct 9)

**Round one.**
1. **A black island with a glass panel under it.** The island stayed black. Everything that drops
   below floated under the notch as a Liquid Glass panel, 8 pt below the island's foot, as
   Control Center and a Mac Live Activity's card hang under the menu bar.
2. **The panels follow the Mac:** light glass with ink words in Light; dark glass with white words
   in Dark.
3. **Colors: the accent and the system's.**
   - **The Fovea accent** goes on primary actions (Run Tests, Copy, Retry, Send), the chosen chip,
     progress and spinners, and links (Open in Claude Code, links in answers).
     - It's the one picked in the onboarding's Make it yours, Multicolor included, in the
       system's own colors as the app uses them.
   - **States:** systemOrange for needs you, systemRed for failed, systemGreen for done.
   - **Voiceflow is white,** never a color (round three, below). Round one had made it the app's
     Dictation teal.
   - **Dispatch keeps the aura** chosen in Make it yours. That is how the onboarding and the app's
     Notch settings color it; a fixed purple would override the person's choice.
4. **The content is Original's, with one approved change.** In Native, an approval's Allow says
   what it does: `swift test --filter …` reads **Run Tests**, and a Desk card, short of room, reads
   **Run**.
   - This is how Apple's confirmation snippets label their button ("Order", not "OK").
   - The verb comes from `ApprovalVerb.of` (`AgentBoard.swift`): tests → Run Tests; build →
     Build; `git push` → Push; install → Install; `rm` → Delete; anything else → Run.
   - Deny stays.
   - Nothing else changes in words, controls, states or order. The smoke run compares every
     state's accessibility text in both designs.

**Round two.** Yulun, on round one's shots: the notch should still connect with the top edge as in
Original, with a switch to compare; and Voiceflow's and Dispatch's bars, still black, weren't glass
and didn't match the rest.
1. **Everything is glass; only the notch is black.**
   - The island itself is Liquid Glass now: the listening bar and its stack, transcribing,
     cancelled, no speech, the Dispatch aura bar and its transcribing, the bar's notices and
     countdown, the Wings band, and the pet at rest (a glass circle).
   - The hardware notch stays black, drawn on the glass where it is. When an app is full screen,
     so does the black band the island hangs from; the glass starts below it.
   - At rest only the notch shows: the island's glass comes in over its first 12 pt of growth past
     the notch.
2. **Panels: Attached or Floating.**
   - **Attached (the default):** what drops below is one glass shape with the island, hanging from
     the top edge with its ears. It is Original's outline exactly, so the content sits where it
     does in Original.
   - **Floating:** round one's panel, 8 pt under the resting notch.
3. **Everything on the glass follows the Mac,** the island's words too: ink on light glass, white
   on dark.
   - What sits straight on a full-screen app's black band (Wings' tokens, the pets) stays dark.
   - **The aura on light glass:** its colors are laid over white rather than lit on black, so its
     layers are drawn 1.7 times as strong there (`VoiceGlow.lightGlassBoost`).

**Round three.** Yulun: Voiceflow's bar is only white; it can't be changed to the accent color.
- **The waveform and the progress lines are white** (`Island.waveform`, `Progress.fill`), as in
  Original and the onboarding. That covers listening, transcribing, the undo line, and the rings of
  Paste not found and an error.
- **Never a color:** neither the accent nor teal, whatever is picked in Make it yours.
- **On light glass** they are the glass's ink (black), since white doesn't read there. A white
  waveform in Light would need the bar to stay dark in Light.

## How it is built

**One set of views and a second design axis,** built the way density is:
- `DesignStore` and `WorkbenchTokens.skin(original, native)` live in `Native/Design.swift`. So do
  `NativePanels` and `WorkbenchTokens.floatsPanels`.
- Every token that follows the design reads it, so a view drawn in Original is drawn exactly as
  before.
- `ink(a)` is white at `a` in Original. In Native it is the system's ink: white at `a` in dark and
  black at `a` in light, resolved by the view's color scheme.

**The surface** (`Native/NativeSurface.swift`) replaces the one black outline in Native.
- **`model.notchSurface`** says island, panel or split:
  - split is Wings and Pets · Wings, whose band beside the notch stays on the island;
  - and #19's route sheet, under the bar.
- **`model.nativeShapes`:**
  - **Attached:** the outline, all island; no separate panel.
  - **Floating:** the island is the resting notch over a panel, or the band or bar in a split;
    the panel is under it by the gap, inside the outline's body.
- **`NativeSurface`** draws, back to front:
  - the floating panel's glass;
  - the island's glass;
  - the black notch.
  - The content goes over all of it, clipped to the island and the panel.
  - **The island's glass has no top edge.** It runs 6 pt above what it hangs from (the screen's
    top edge, or a full-screen app's black band) and is cut there. Liquid Glass draws its rim over
    whatever is drawn after it, so a rim along the top would show as a line that nothing can
    cover.
  - It frames the content exactly as Original does. When the panels float, each panel's top
    padding gains the gap (`Native.panelGap`: 8 floating, 0 attached and in Original), so the
    content keeps its distance from the panel's top edge.
- **Color scheme:** in Native, the island's content takes the display's scheme;
  `.panelScheme()` gives the display's scheme in Native and dark in Original.
  `.panelScheme(onBlack:)` stays dark on a full-screen app's black band.
- **Motion:** the island and the panel move on the island's spring together. Floating, the island
  springs back to the notch while the panel grows out of its foot.

**Glass** is `glassEffect` on macOS 26 and later (`Native/NativeGlass.swift`, copied from the
app's `Glass.swift`).
- Before macOS 26 it is the system's material with a solid rim; there are no gradients, as the
  Island asks.
- It is used for the island, the panel, the capsules, the pet at rest and the pulled-out window.
  Inside them, controls are fills, as the app's are.

**Controls keep their sizes,** so no measured layout moves:

| Control | Native look |
|---|---|
| Primary buttons and Send | The accent with white words |
| Secondary buttons | An ink fill |
| Chips | An ink fill; the chosen one the accent at 20 % |
| State glyphs | The system's monochrome symbols in their state's color, the mark cut out |
| The Badges design's ring | Cut through to the glass |

## Rules this departs from

- **AGENTS.md, "every Island neutral is white at an opacity on black":** in Native the island is
  glass, its neutrals the system's ink.
- **The Oct 6 decision that the island is black** (`Prototypes/FoveaCaptures/DESIGN.md`): Native's
  island is glass at Yulun's request (Oct 9, round two); the notch on it stays black. Original
  keeps the black island.
- **PRD §2.7 and §6** (a black surface, no glassmorphism): Native is a prototype under comparison in
  its own tab, like the material study's B–E. It needs an amendment before it ships.
- **Still kept:** no gradients, SF Pro, tokens for every color, no counts.
