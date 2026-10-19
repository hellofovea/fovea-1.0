# Localization (Oct 18)

Fovea's interface follows the person's primary language (English or Simplified Chinese).
English is written in the code; the Chinese lives here, one `.strings` file per part of the app:

- `zh-Hans/onboarding.strings` — the first run (FoveaOnboarding, OnboardingCore)
- `zh-Hans/window.strings` — Home and Settings (FoveaWindow, CapturesCore)
- `zh-Hans/island.strings` — the notch (FoveaIsland)
- `zh-Hans/app.strings` — menus, the menu bar, alerts, shared keys (FoveaApp, FoveaKit, FoveaPlatform)

Each line is `"English key" = "中文";`, the key exactly as the compiler extracts it (`%@` for an
interpolated string, `%lld` for an integer, `%lf` for a Double). `scripts/bundle.sh` merges the
files into `Fovea.app/Contents/Resources/zh-Hans.lproj/Localizable.strings`.

`python3 scripts/l10n.py` builds with `-emit-localized-strings` and lists every key that has no
Chinese yet, by source file (`--module FoveaWindow` to narrow it).

## Glossary (use these, so the three parts read as one app)

Apple's own Simplified Chinese where macOS has a word (System Settings' names, 拷贝, 粘贴, 好). A
space between Chinese and Latin letters or digits ("在 Claude Code 中打开", "3 个请求"); full-width
punctuation in Chinese sentences (，。：？！ and “” for quotes, as Apple writes them); keys as caps (fn、⌥、⌘). Product and app names stay
as they are: Fovea, Claude Code, Codex, Claude, Wispr Flow, Typeless, Superwhisper; Finder is
访达, as macOS writes it (在访达中显示).

| English | 中文 | English | 中文 |
|---|---|---|---|
| Voice Flow / Dictation | 听写 | Dispatch | 派发 |
| capture (a Home card) | 记录 | referent (what's taken) | 引用对象 |
| Screenshot | 截图 | Whole screen | 全屏 |
| Selected text and files | 选中的文字和文件 | the notch | 灵动岛 (never 刘海) |
| the board (control board) | 控制面板 | session | 会话 |
| chat (Choose chat) | 会话 (Choose chat: 选择会话) | agent / coding agent | Agent / Coding Agent (never 代理; Ryan, Oct 18) |
| quick answer | 快速回答 | request | 请求 |
| Needs you | 需要你 | Working | 进行中 |
| Ready for review / Done | 待查看 / 已完成 | Failed | 失败 |
| Home | 主页 | Settings | 设置 |
| app (an app on the Mac) | App (as Apple China writes it: “当前 App”) | the Applications folder | “应用程序”文件夹 |
| Account | 账户 | Plan | 套餐 |
| Getting Started | 开始使用 | Appearance | 外观 |
| Notch (section) | 灵动岛 | Language | 语言 |
| Voice & Capture | 语音与记录 | Dictionary | 词典 |
| Memory | 记忆 | Shortcuts | 快捷键 |
| Connectors | 连接 | Eye Tracking | 眼动追踪 |
| About | 关于 | the tour / first run | 导览 |
| Exit tour | 退出导览 | Back | 返回 |
| Continue | 继续 | Skip / Skip for now | 跳过 / 暂时跳过 |
| Begin | 开始 | Try Again | 重试 |
| Allow / Allowed | 允许 / 已允许 | Open Settings / System Settings | 打开设置 / 系统设置 |
| Copy / Paste | 拷贝 / 粘贴 | Send / Sending | 发送 / 正在发送 |
| Stop | 停止 | Close | 关闭 |
| Cancel | 取消 | Done | 完成 |
| Sign In / Sign Out | 登录 / 退出登录 | Sign up | 注册 |
| Open in Claude Code | 在 Claude Code 中打开 | Answer again | 重新回答 |
| Ask more | 继续提问 | Edit | 编辑 |
| Glow | 光晕 | Customize | 自定义 |
| Hue / Drift / Spread | 色相 / 流动 / 扩散 | Glass (Light/Dark) | 玻璃（浅色/深色） |
| Panels: Attached / Floating | 面板：贴合 / 悬浮 | Size: Compact / Spacious | 尺寸：紧凑 / 宽松 |
| Accent | 强调色 | Choose your languages | 选择你的语言 |
| Primary language | 主要语言 | Tidy my words | 整理我的文字 |
| Device Control and Data Access | 设备控制与数据访问 | Screen & System Audio Recording | 录屏与系统录音 |
| Input Monitoring | 输入监控 | Microphone / Speech Recognition | 麦克风 / 语音识别 |
