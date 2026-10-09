# Fovea brand assets

The app's icon (since Oct 6) is Ryan's serif f, its hook curling into the o: one stroke for "fo",
the ring at its end an eye looking down. It's his artwork, `Source/fovea-serif-f.png`, traced by
`scripts/fovea-icon.swift` (the glyph followed at half coverage by marching squares, thinned to a
third of a pixel, placed on the icon's tile as he placed it; 0.18 % of its pixels differ from the
artwork's, all at the edge). Run `swift scripts/fovea-icon.swift` after changing the artwork; never
edit the exports by hand.

The geometric "fo" it replaced is still drawn from measurements there: its o is an eye with the
fovea in it (the point the eye sees sharpest). It makes the variants below, and its eye is still the
menu bar's mark.

- `Source/fovea-serif-f.png`: the artwork, lossless, as handed over (1254 px; its white tile
  measured at x 119–1133, y 131–1126, taken as a 1005 px square on its center).
- `AppIcon.icon/`: the layered icon for macOS 26 and later, the format Icon Composer writes.
  `scripts/bundle-app.sh` compiles it with `actool` into `Assets.car`, which the system draws with
  its glass edge and in its dark, clear and tinted styles. macOS 26 and later put an `.icns`-only
  icon in a grey container, so this is the one that ships.
- `AppIcon.iconset/`: every size for the `.icns`, used when `actool` isn't available. The serif f
  has one outline at every size; its hairlines (the crossbar and the foot, about 1 % of the tile)
  fade below 64 pixels and are gone at 32.
- `../AppIcon.png`: the 1024 icon the apps put in the Dock at runtime.
- `fovea-app-icon.svg` / `fovea-app-icon-dark.svg`: the icon masters, white field / black field.
  `fovea-app-icon-dark-1024.png` is the dark one exported.
- `fovea-mark.svg` / `fovea-mark-reversed.svg`: the mark in ink / in white, on transparency.
- `fovea-eye.svg` and `fovea-menubar-{16,18,32,36}.png` (+ `-reversed`): the geometric fo's o and
  its dot alone, for the menu bar item (template images).
- `Variants/`: the icons the Captures prototype's Variants › App Icon puts in the Dock: the serif f
  (the app's icon) light and dark, and the geometric fo as drawn, balanced, looking, round o, and
  dark.

Geometry: the drawing's 988-unit tile is mapped onto Apple's grid (an 824 body, 100 in from each
edge of the 1024 canvas, continuous corners of 185.4); the artwork's tile is mapped onto the same
tile. Ink `#0C0C0C`, the window's own ink, on white. The geometric fo's "Balanced" evens the
drawing's weights: the f's stem was 121 units against the o's 97 to 102, so the stem is 111 and the
ring 112 at its sides and 96 at its top and bottom.
