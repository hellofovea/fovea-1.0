# Agent icons

Full-colour official artwork, drawn as-is: never tinted, never redrawn (PRD §6: official provider
artwork only). Bundled so the workbench and its snapshots look the same on any Mac.

- `codex.png`: the Codex product icon for dark surfaces, `icon-codex-dark-color.png` from the
  signed Codex app (`/Applications/ChatGPT.app/Contents/Resources/`, bundle id `com.openai.codex`),
  scaled to 256×256. The same file fovea-mac ships as `Brand/icon-codex-dark-color.png`.
- `claude-code.png`: the Claude app icon, used as Claude Code's mark: fovea-mac's
  `Brand/icon-claude-256.png` (the 256×256 representation of the signed Claude app's icon).
- `cursor.png`: the Cursor app icon, fovea-mac's `Brand/icon-cursor-256.png`.
- `grok-bot.png`: the Grok Bot app icon (SpaceXAI and Cursor's desktop agent), the 256×256
  representation of `icon.icns` in the signed `/Applications/Grok Bot.app` (bundle id
  `com.anysphere.sand`).

Why app icons and not one-colour marks: the Codex mark is a cloud with a cut-out `>_`, which is a
blob at 16 pt (and lobe-icons' SVG of it renders wrongly in CoreSVG); the app icons are what each
agent looks like in the Dock and the menu bar, and fovea-mac chose the same (its `Brand/README.md`).
The PRD lets destination icons keep their brand colours (§2).
- `fovea.png`: Fovea's own app icon for dark surfaces, `Sources/FoveaCore/Resources/Brand/fovea-app-icon-dark-1024.png`
  scaled to 256×256. The mark for the default agent's sessions (Quick answers), which never show a
  provider's icon (AGENTS.md).
