# The listening bar: Wings (Oct 26–27)

Ryan, Oct 26, looking at the listening bar: "the notch transition from the top menu bar to the notch is
too abrupt and the color change is too abrupt." He pointed at VoiceOS: a narrower, thinner notch, a
blue circle at the left, "a very small voice waveform bar on the right", and black that turns to
Liquid Glass gradually. He asked for research on the notch products first, then a few versions.

Four were built (Wings, Lip, Melt, Droplets). He picked Melt, then Wings: "actually do wings, dont
have the previous version. but do delete the circle on the left, replace it with listening". On
Oct 27: "i want only the wing build, dont have the others", every state of the bar in it, and:
- Voiceflow: the bar without the aurora;
- Dispatch: "dont have the voiceflow bars, have a little orb-like-thing thats lively, breathing,
  kind of 3d … find a way to integrate the aurora into the orb" (tried, then dropped: below);
- Transcribing: "a progress circle on the right in white that measures the progress";
- "the words listening, transcribing, etc, should follow our design (especially website design)".

Then, the same day, after three orbs: **"abandon the orbs and aurora completely, i think these are
too flashy. go with the voiceflow bars for both voiceflow and dispatch."** So Dispatch's bar is
Voiceflow's: the small waveform at the right, and no aura anywhere, in Wings or in a band over a panel.

**The corner's aurora (Oct 28).** Ryan, of another app's bar with a green light in its corner: "when
doing dictation/dispatch. make an accent color a little aurora in the same fashion as the attachment
on the bottom right of the notch like this." While the bar listens (Voiceflow and Dispatch, the
waveform at the right), a small light in the accent sits inside its bottom-right corner, under the
waveform: three soft lights, blurred (not a gradient), wandering a few points, the voice brightening
and growing them, the bar's edge lit along the corner's curve. It fades in and out with listening
(0.35 s) and is cut to the bar's own corner. `WingsAurora` (Wings.swift), `WorkbenchTokens.Aurora`.
Asked whether the glow's old palettes suited it, Ryan saw both and chose: "lets just do one color
hue. this should be determined along with accent in the onboarding. when user is choosing accent in
onboarding, they should see this notch input bar to demonstrate the accent color. if they choose
multicolor, the hue in the attachment should be the color." So its color is the accent's one hue;
on Multicolor, the glow's Colorful palette (pink, blue, violet). Choosing the accent, in the first
run's Make it yours or in Settings, shows the listening bar at the notch a moment, its aurora in it,
breathing with a voice that never falls quiet (no microphone). Pictures of each accent:
`--design-shots notch <dir> --only aurora-`.

Lip, Melt, Droplets and the menu bar's Listening Design are gone.

**Wings over a panel (Oct 27).** Ryan, of the smaller glass panels: "they should also suit the new
notch design as well". While it listens, Wings stays the bar over what opens under it, where the old
tall glass bar used to be:
- **the opened stack:** the bar says "Listening" (what's taken is open below). Since Oct 27 it
  isn't a panel but a strip floating 8 pt under the bar, whether the panels float or not: five in
  view, the rest a swipe away, a click on one to see it large, and Esc or the bar's left to close
  it. Ryan: "there should only be a floating strip of 5 pics".
- **asking more over a session:** the session stays where it was;
- **the route's sheet** (review off): it hangs at Dispatch's width.

Floating, the bar is black and the panel glass under it. Attached, the glass is one shape from the
screen's edge, and the bar is drawn black on it, as the notch is. The opened stack's own waveform
and its "esc" pill are gone; the bar's waveform is the one.

## Wings

**The shape.** The menu bar's height (32 pt), all black, growing sideways from the notch: 10 pt ears,
12 pt bottom corners. Both wings are as wide as the wider side needs, so the sides stay balanced (as
Apple's HIG asks of a compact activity). The content is placed from the wing's own edge, so it comes
out from under the notch with the shape.

**The words** are the system face, as a notice's title is: SF Pro, medium, 12 pt, white at 0.88.
While it works, the website's three dots after the word (2.4 pt, one lighting after another every
0.36 s). Oct 27, later: Ryan, pointing at "Mic access off", "for the notch, go with this font. dont
have the flashy font of the current thinking, transcribing, etc." (The website's EB Garamond
italic, tried that day, is gone from the notch.)

| State | Left | Right |
|---|---|---|
| Voiceflow listening | "Listening", or what's taken (18 pt thumbnails, a pile and "+2" past three) | The small waveform: five white bars, 2.5 pt wide, 3–12 pt tall; the accent's little aurora in the bar's bottom-right corner (Oct 28) |
| Dispatch listening | The same | The same small waveform and corner aurora (no orb, no aura along the edge). With review off, the chosen chat's agent before it |
| Transcribing | "Thinking…" (Voiceflow, as its band always said), "Transcribing…" (Dispatch) | A white ring, 14 pt, a 2 pt line on a faint track, filling clockwise from the top as the words come |
| The last minute | As listening | Its time before the waveform (amber in the last ten seconds) |
| A file dragged over | The state's word, as listening | Oct 27: no well in the bar, since its middle is under the hardware notch. A drag that comes near opens a drop zone floating under the bar ("Drop files here", dashed), which lights in the accent with the files over it ("Let go to add all 3") |
| Cancelled | "Cancelled" | Undo, its time draining round its side |
| No speech | "No speech" | |
| Nowhere to paste | The words held, quoted, cut at 110 pt | Copy |
| A notice | Its symbol and a short title ("Offline", "Mic access off", "Screen Recording off") | Its one way on: Retry, Settings, Sign In, Upgrade, Renew, Choose |

## The orbs, tried and dropped (Oct 27)

Three orbs were built for Dispatch's bar before Ryan dropped them all as too flashy. Kept here for
what they found; none is in the code.
- **A glass sphere** with three of the aurora's colors orbiting inside, a shade, a rim and a highlight.
- **After Oasis HQ's glass water orb** (joinoasis.com, a three.js icosphere and two shaders). Oasis's
  never grows or shrinks: two octaves of slow simplex noise push its surface in and out (amp 0.2,
  frequency 0.65, drifting 0.21 a second), it turns once every 17 s, and inside is a photo of a pool's
  caustics seen as through a lens, with a pale fresnel rim and one sharp highlight. Ours drew the same
  outline on the CPU with the aurora's colors inside; the research on placing them: small orbs carry
  one to three hues and get their depth from lightness (Oasis, LiveKit's Aura and OpenAI's are one hue;
  ElevenLabs' two), hues more than ~120° apart averaged together go gray, so three of a palette's
  seven, the two ends added as light.
- **VoiceOrbs** (voiceorbs.vercel.app, MIT): Siri Sheet, Nebula, Mercury, Minimal, Grain and Dither,
  studied in a live page in each palette. All take two colors and derive the rest; states cross-fade
  over ~0.1 s; colors mix in linear light.

## What's abrupt today

- **The shape.** The bar hangs 44 pt below the notch at the notch's width. Its 6 pt ears are its only
  curve into the menu bar, so it reads as a block stuck under the notch.
- **The color.** The notch is black and the band below it is grey glass, with a hard line between
  them. TypeWhisper ships exactly this as a theme: a black cap over a glass body
  (`NotchIndicatorView.swift`).

## What the research says

**VoiceOS** (its in-browser demo draws the notch in CSS, the `lns` classes, read Oct 26):
- **Listening:**
  - It's 296 × 32 against a notch 29 tall, so it stays at the menu bar's height and only widens.
  - It's solid black, with concave 13 px ears and 13 px bottom corners.
  - A four-bar waveform sits at the left (2.5 px bars, 8–12 px tall, grey 153–189); a ✕ sits at the
    right.
- **Open (502 × 300):**
  - The tint is black to 53% of the height, then fades to 50% black at the foot.
  - Under it is glass: `blur(18px) saturate(160%)` over `rgba(0,0,5,0.18)`, with a shadow of
    0 8 18 at 0.3.
  - The blue orb ("lens") sits at the top left.
  - The web version has a sheen: clear to 46%, then 0.05 at 74%, then a 0.3 line along the foot.
- **Motion:** it opens over 280 ms on (0.2, 0.8, 0.2, 1) and closes over 200 ms. The content comes
  in 80 ms behind the shape.

**Thirteen other products** (a survey; screenshots in the session's scratchpad, not in the repo):

| Pattern | Who | Numbers |
|---|---|---|
| Stay at the notch's height and grow sideways | Boring Notch, DynamicNotchKit, TypeWhisper, OpenDictation, NotchNook, DynamicLake. Only VoiceInk drops, and only 6 pt | +30 to +90 pt each side |
| Concave ears at the top, larger radii as it opens | Nearly all; most descend from DynamicNotchKit | 6–8 / 13–16 pt closed, about 15–19 / 20–32 open |
| An icon at the left, a few bars at the right | Boring Notch, VoiceInk, TypeWhisper, OpenDictation, NotchNook, DynamicLake | Icon 14–20 pt. 4–6 bars, 2–3 pt wide, 2 pt apart, 12–16 pt tall |
| The shape leads and the content follows | DynamicNotchKit, VoiceInk | The side slots blur and scale out from the notch's side, about 0.09 s after the shape |
| Opaque black | Apple mandates it for the Dynamic Island; nearly everyone else does it too | |
| Black at the notch, clearing to glass below | DynamicLake's Lake26 (and VoiceOS's open panel) | Sampled rgb 13–15 at the top, 26–59 at the foot |
| Balanced sides | Apple's HIG for the compact leading and trailing | 52 × 37 each side on a 393 pt iPhone |

Apple doesn't put iPhone Live Activities in the Mac's notch: macOS Tahoe shows them as a menu bar
item.

## Motion

Each state was filmed on the real notch: Fovea's own windows read about 1,000 times a second for
0.6 s after the change (`--design-shots bar-film <dir>`). Two things the frames showed are fixed:
- **A grey edge flashed past.** The black faded in on the spring while the glass came in. Fix: the
  notch at rest is already the bar's black (drawn with its 6 pt ears), so coming out and going back
  never pass through glass.
- **What the wing held ran ahead of it and was cut by its edge** (the first orb). Fix: beside the
  notch, what the wings hold is placed from the shape's own edge, which moves with the shape frame by
  frame.

## Departures

- **No aura.** Dispatch's voice was the aura along the bar's edge (AGENT_VOICE_AND_THINKING.md,
  DISPATCH_V2.md). Since Oct 27 it is Voiceflow's waveform, and the aura is drawn nowhere. Since
  Oct 28 a small light sits in the bar's corner while it listens, blurred lights rather than a
  gradient (the Island's rule against gradients, as the Halo keeps it).
- **The notch at rest** is drawn with its 6 pt ears in black.

## Running it

- **Pictures:** `--design-shots notch <dir> --only wings` (every state × Dark, Light), drawn off the
  screen: nothing covers it, nothing comes to the front, the desktop is drawn behind the island in the
  picture only. `--full-screen-shots` brings back the old way (a backdrop over the screen).
  `--shot-wallpaper=<file>` for a picture of your own behind it.
- **Frames:** `--design-shots bar-film <dir>`. It reads Fovea's own window on the screen, so frames
  can come back empty while Fovea is behind another app.
- **Checked:** `--smoke` (each state's pose, the bar's height and its black).
- **Code:** `FoveaV1/Sources/FoveaIsland/MockDesktop/Wings.swift`; tokens in
  `WorkbenchTokens+Bar.swift` (`Bar`); the surface in `Native/NativeSurface.swift`.

## Sources

- The orbs (dropped): [VoiceOrbs](https://github.com/amunozdev/voiceorbs); [Oasis HQ](https://joinoasis.com) (its glass water orb, in the site's scripts);
  [ElevenLabs UI, Orb](https://github.com/elevenlabs/ui/blob/main/apps/www/registry/elevenlabs-ui/ui/orb.tsx);
  [SmoothUI, Siri Orb](https://github.com/educlopez/smoothui/blob/main/packages/smoothui/components/siri-orb/index.tsx);
  [LiveKit Agents UI, Aura](https://github.com/livekit/components-js/blob/main/packages/shadcn/components/agents-ui/agent-audio-visualizer-aura.tsx);
  [Paper Shaders, mesh gradient](https://github.com/paper-design/shaders/blob/main/packages/shaders/src/shaders/mesh-gradient.ts);
  [siriwave](https://github.com/kopiro/siriwave/blob/master/src/ios9-curve.ts);
  [OKLab](https://bottosson.github.io/posts/oklab/); small-field tritanopia,
  [Williams et al. 1981](https://aria.cvs.rochester.edu/papers/williams-etal_VR1981b.pdf);
  [gradients through gray](https://www.joshwcomeau.com/css/make-beautiful-gradients/)
- The noise: Ashima Arts' webgl-noise (MIT), as Oasis's shader uses it
- [VoiceOS demo](https://www.voiceos.com/demo), the `lns` styles, read Oct 26
- [Apple HIG: Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)
- [WWDC23: Design dynamic Live Activities](https://developer.apple.com/videos/play/wwdc2023/10194/)
- [Boring Notch](https://github.com/TheBoredTeam/boring.notch) (`ContentView.swift`, `MusicVisualizer.swift`, `sizing/matters.swift`)
- [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) (`NotchView.swift`)
- [Atoll](https://github.com/Ebullioscopic/Atoll), [NotchDrop](https://github.com/Lakr233/NotchDrop), MewNotch (its source)
- [VoiceInk](https://github.com/Beingpax/VoiceInk) (`NotchRecorderView.swift`)
- TypeWhisper's source (`NotchIndicatorLayout.swift`, `NotchIndicatorView.swift`), OpenDictation's source
- [NotchNook and MediaMate, MacStories](https://www.macstories.net/reviews/notchnook-and-mediamate-two-apps-to-add-a-dynamic-island-to-the-mac/)
- [Alcove](https://tryalcove.com) (its changelog); DynamicLake's site and demo; Wispr Flow's site
