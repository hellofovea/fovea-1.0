# Apple-native references for the notch (Oct 9)

**Why.** Yulun on Oct 8: the onboarding feels macOS-native and smooth, but the notch (the control
board, the sessions) copies ChatGPT's and Claude's apps rather than Apple's design language. This
folder collects Apple's own designs for the same jobs.

**The board:** `apple-native-references.html`, one self-contained page with every screenshot and
its source. Our app and onboarding were rendered on Oct 8 from `Prototypes/FoveaCaptures` and
`Prototypes/FoveaOnboarding`; the notch from the Workbench shots. Apple's figures are screenshots
of Apple's pages, for internal reference only.

## What our app and onboarding do

- **The app** looks like the current macOS: a Liquid Glass toolbar, System Settings' grouped
  forms, standard controls, the destinations' real app icons, SF Pro at Mac sizes.
- **The onboarding** puts the notch inside a real Mac (Safari, the desktop's files, System
  Settings, the real permission alert). Its notch card stays small: a title, a line or two, one
  white button. Its result opens where the work is (the edited file), not in the notch.
- **The notch today:**
  - The board is close to a menu.
  - A session is a chat client in a black slab (660 pt wide; expanded 880 pt, down to the
    display's foot): the request, a Markdown answer, "Worked for … · Edited N files", Open in,
    Answer again, "Ask a follow-up", a grab bar.

## Apple's references

- **[Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)**
  (HIG, updated Dec 16, 2025 for the Mac):
  - **Glanceable:** for more, people open the app at the right place.
  - **Small:** expanded is at most 408 × 160 pt, and the Mac uses the same sizes.
  - **One control:** essential, tied to the activity.
  - **Look:** a black, opaque island with color in text and objects; a logo mark without its
    container; large, medium-or-heavier text; concentric margins.
  - **Motion:** only for a change, two seconds at most.
  - **On the Mac:** they sit in the menu bar.
- **[Live Activities on the Mac](https://support.apple.com/en-us/120684)** (macOS Tahoe 26):
  - In the menu bar: a small icon, or a compact capsule.
  - A click shows a small card: a title, one line, progress, the time.
  - A double click opens the app.
- **[Snippets](https://developer.apple.com/design/human-interface-guidelines/snippets)** (Siri,
  Spotlight, Shortcuts):
  - A **confirmation** has Cancel and a specific verb.
  - A **result** has Done.
  - At most 400 pt tall; more detail is a link into the app.
- **[The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar):**
  a menu bar extra shows a menu, not a popover, unless what it exposes is too complex for a menu.
- **[Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers):**
  - Small and transient, one at a time.
  - On the Mac, can be detached into a panel that looks almost the same.
- **[Panels](https://developer.apple.com/design/human-interface-guidelines/panels):** a dark HUD
  panel is for media work, kept small; prefer standard panels.
- **[Materials](https://developer.apple.com/design/human-interface-guidelines/materials):** Liquid
  Glass is for the controls layer, used sparingly.
- **[Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators):**
  determinate when possible, accurate, kept moving.
- **Control Center and call alerts** ([macOS Tahoe 26](https://www.apple.com/newsroom/2025/06/macos-tahoe-26-makes-the-mac-more-capable-productive-and-intelligent-than-ever/)):
  glass modules and cards under the menu bar, round buttons, color only for the decision.
- **Apple's own AI and agents:**
  - **Siri on [macOS 27](https://www.apple.com/os/macos/):**
    - Over an app, a floating Liquid Glass panel: close, expand, the question as a small
      bubble, the answer, an "Ask Siri" field with a microphone.
    - Long conversations live in the Siri app's window.
  - **Claude Agent and Codex in [Xcode 26.3](https://www.apple.com/newsroom/2026/02/xcode-26-point-3-unlocks-the-power-of-agentic-coding/):**
    - The agent works in Xcode's sidebar.
    - Its steps are a checklist with circles (a Todo List popover), and "Thinking" is a titled
      card.
    - Each edit is a file card (+44, −1, A/M); "Message Claude Agent" sits at the bottom.
    - The toolbar's activity view says only "Build Succeeded".

**So "a chat" is not itself un-Apple.** Apple uses one for Siri and for agents in Xcode. What
differs is:
- **where it lives:** a window, a glass panel, a sidebar, never the status surface;
- **how it looks:** system materials, SF Symbols, standard fields, a checklist for steps, cards
  for edits.

## Directions to discuss (not decisions)

1. **The notch shows state; detail opens in a window.** Fovea already has the window: the capture
   card in Home.
2. **A finished session in the notch is a result snippet:** a status, one line or progress, Done,
   Open; at most about 400 pt.
3. **A question is a confirmation snippet:** what will happen, Cancel and a specific verb.
4. **Black only where it is the island.** What drops further uses the system's material, light
   or dark with the system.
5. **SF Symbols and the system's progress views for state;** logo marks without containers;
   determinate progress when the agent reported a plan.
6. **The board as a menu,** or as one Live Activity that rotates through the sessions.
7. **Pulling a session out** follows macOS's detachable popover: a panel that looks almost the
   same.
8. **Typing to an agent happens in the window,** and the notch keeps the voice key.
