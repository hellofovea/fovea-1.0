# Fovea brand assets

The app's icon (since Oct 13) is the pressed loop: the highlighter loop and its dot pressed blind
into cotton paper, with black ink only where the loop closes over itself. It's rendered, not drawn,
because it's the light on a press: `scripts/fovea-pressed-loop.py` (numpy) writes the artwork into
`Source/`, and `swift scripts/fovea-icon.swift` builds every export from it. Run both after changing
it; never edit the exports by hand.

- **The loop** is one pass of a flat-tipped highlighter, its closing pass laid over its start along
  the top center. That's where the notch is, left to the overlap and never drawn as a notch.
- **The press:** no ink, only the paper and the light on it, from the top left. Where the pen passed
  twice the press is twice as deep, and it lands and lifts like a pen, so it never reads as a tab.
- **The ink:** black (`#1A1918`), only on that second pass, its ends cut on a chisel's slant, with
  the faint tooth of letterpress ink. Black over a coloured ink (Oct 13): the loop and the page stay
  ink on paper, as the window and the book landing are.
- **The dot** is what the loop caught, and an eye glancing down and to the right. It sits off center
  so it doesn't read as the generic eye, a pupil staring back. It's pressed a little deeper.
- **The paper:** `#EEEAE2`, lit softly from the top left, with fine grain and faint fibres.
- **Small sizes:** a blind press vanishes at 16 and 32 pixels, so those have their own artwork: a
  heavier loop and dot in a light graphite (`#8A8680`), the black still only where it closes.

Earlier icons are kept as variants: the flat highlighter loop in macula yellow (Oct 10), Ryan's
serif f (Oct 6 to 10, traced from his artwork) and the geometric "fo" before it. The fo's o is an
eye with the fovea in it, and that eye is still the menu bar's mark.

- `Source/fovea-pressed-loop.png` / `-small.png`: the icon's artwork, full-bleed 1024 squares (the
  tile's content filling the canvas, as Icon Composer takes a layer), for 64 px and up and for 16
  and 32. Written by `scripts/fovea-pressed-loop.py`.
- `AppIcon.icon/`: the layered icon for macOS 26 and later, the format Icon Composer writes: one
  layer, the artwork, on a solid paper field. `FoveaV1/scripts/bundle.sh` compiles it with `actool`
  into `Assets.car`, which the system draws with its glass edge and in its dark, clear and tinted
  styles. macOS 26 and later put an `.icns`-only icon in a grey container, so this is the one that
  ships. The field is solid, not the system's light fill, which shades toward the foot (Oct 9);
  `actool` drops a dark fill specialization (checked Oct 10). The layered icon has one image for
  every size, so the small-size artwork reaches only the `.icns` and the PNGs. Pass `actool` an
  absolute path: its helper resolves relative ones against its own directory.
- `AppIcon.iconset/`: every size for the `.icns`, the small-size artwork at 16 and 32 pixels.
- `../AppIcon.png`: the 1024 icon the apps put in the Dock at runtime (`swift run`, unbundled). It's
  the icon's master; there's no SVG of a rendered icon.
- `fovea-mark.svg` / `fovea-mark-reversed.svg`: the one-colour mark, the loop's outline and its dot,
  in ink / in white, on transparency.
- `fovea-eye.svg` and `fovea-menubar-{16,18,32,36}.png` (+ `-reversed`): the geometric fo's o and
  its dot alone, for the menu bar item (template images).
- `Variants/`: the icons the window's Variants › App Icon puts in the Dock: the pressed loop (the
  app's icon), the yellow loop, the serif f light and dark, and the geometric fo as drawn, balanced,
  looking, round o, and dark.
- `Source/fovea-serif-f.png`: the serif f's artwork, lossless, as handed over (1254 px; its white
  tile measured at x 119–1133, y 131–1126, taken as a 1005 px square on its center). Oct 9: Ryan's
  revision, the ring's hole smaller (about 108 px across, from 135); its transparent margin is read
  as white. Traced by marching squares at half coverage, thinned to a third of a pixel; 0.18 % of
  its pixels differ from the artwork's, all at the edge.
- The agents' `fovea.png` (`FoveaV1/Sources/FoveaIsland/Resources/Agents/`, and the Workbench's):
  the icon at 256, the mark for the default agent's sessions.

Geometry: the sketch's tile (144 units at (8, 8) in a 160 square) and the drawing's 988-unit tile
are both mapped onto Apple's grid (an 824 body, 100 in from each edge of the 1024 canvas,
continuous corners of 185.4); the pressed loop's artwork fills that body. The fo's ink is `#0C0C0C`,
the window's own ink. Its "Balanced" evens the drawing's weights: the f's stem was 121 units against
the o's 97 to 102, so the stem is 111 and the ring 112 at its sides and 96 at its top and bottom.
