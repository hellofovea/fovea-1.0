# The onboarding on a real Mac: what works, and the flow it leads to

Tested Oct 8 on this MacBook (macOS 27.0.1, 1470×956 pt, menu bar 32 pt, notch 179 pt).

**The test app:** Fovea Probe, a throwaway app built for the test. It has:
- a notch card made the way the shipping `NotchPanel` is (`statusBar + 8`, non-activating, every Space);
- a draggable tile;
- a drop target;
- a capture overlay;
- an empty-desktop backdrop;
- System Settings links;
- a relaunch.

**How it was driven:** commands, real mouse drags, and screenshots. Nothing in System Settings was changed.

The prototype (`Prototypes/FoveaOnboarding`) stays as it is. This page says what a real Fovea can and can't do for each of its moments, and proposes the real flow for review.

## Results

| What the onboarding needs | On this Mac | Evidence |
|---|---|---|
| The card at the real notch, above everything | **Works** | Shown at the notch; stays above System Settings, the Dock and every window (window level 33). |
| Drag Fovea out of the notch card | **Works** | The card starts a real macOS drag carrying `FoveaProbe.app` as a file. A drop target received the app's path. The app in front (Calculator) stayed in front: the card never took focus. |
| …dropped into System Settings' list | **Works (tested by hand)** | Dropped on Device Control and Data Access: the drop was accepted (copy). The app joined the list already switched on. The probe saw Accessibility allowed 2.5 s later, live, with no relaunch and no switch to flip. HeyClicky ships the same (its tile says "drag me into the list above."). |
| Open System Settings at the exact list | **Works** | Device Control and Data Access, Screen & System Audio Recording, Microphone, Automation and Keyboard all open directly. The new (`com.apple.settings.PrivacySecurity.extension?Privacy_…`) and old (`com.apple.preference.security?Privacy_…`) links both work. |
| Move System Settings next to the card | **No** | Moving another app's window needs Accessibility, which isn't granted yet at that point. System Settings opens where you last left it, so the card has to work wherever it is. |
| Only Fovea's windows on screen | **Works, by hiding the other apps** | All 12 running apps hid; only the Dock and the menu bar stayed. Then exactly those 12 came back. No permission needed. `hide()` reports "refused" even when it works, so check the screen instead. |
| …or Fovea's own backdrop over everything | **Works, but not your wallpaper** | A backdrop window covers other apps; System Settings opens above it; the Dock and the notch stay above. But macOS reports a stock image (`DefaultDesktop.heic`, the Golden Gate) while the real wallpaper is a moving one (a forest), so it reads as Fovea's stage, not your desktop. |
| In a full-screen app | **Windows go to the desktop** | macOS won't put another app's window into a full-screen Space. Fovea's windows open on the desktop, and activating Fovea switches there. The notch card shows in any Space. |
| ⌘ then a drag over any app | **Works** | A non-activating overlay took the drag (3 drag events) over Calculator. Calculator stayed in front and got no clicks. Taking the pixels then needs Screen Recording (ScreenCaptureKit). |
| Screen Recording's Quit & Reopen | **Works** | Relaunched in 0.3 s and resumed at its saved step. |
| fn's clash with the Globe key | **Readable** | `AppleFnUsageType` reads 0 (Do Nothing) here. Fovea can check it and link to Keyboard › Press 🌐 key. |
| Agents on this Mac | **Works, with places to look** | `claude` is in `~/.local/bin`. The Codex and Cursor command-line tools aren't installed. ChatGPT's Codex app is, but it isn't a command-line agent. Detection must look in known folders, not only the app's PATH. |

**Not tested yet:**
- the same drop into Screen & System Audio Recording, and its Quit & Reopen;
- macOS adding Fovea to a list when Fovea asks;
- fn, ⌘ and ⌥ from any app, which need Accessibility (already real in `build/Fovea.app`);
- taking pixels, which needs Screen Recording.

### Two things to design for

- **macOS 27 warns hard.** Device Control and Data Access says apps with it "can view and send email, edit contacts and photos, monitor your keyboard, track websites, record your screen, control any app on your Mac". Fovea's card has to say in one plain line why it asks, before the person reads that.
- **Files on the desktop.** Writing practice files to `~/Desktop` makes macOS ask "Fovea would like to access files in your Desktop folder", an extra prompt for nothing. Practice files live in Fovea's own window instead.

## What changes from the prototype

| Prototype | Real Mac |
|---|---|
| A mock desktop, coast wallpaper | The person's own desktop, other apps hidden (or Fovea's backdrop) |
| A mock Safari page and desktop files | Fovea's own practice window: a short article, a photo, a shelf of three files |
| Mock System Settings beside the card | The real one, opened at the exact list, wherever it last was |
| Mock alerts | macOS's own prompts, which can't be styled; Fovea's card prepares each one |
| The script as the transcript | Their real words; any words pass, the script is a suggestion |
| A mock Messages reply box | Fovea's own practice reply box |
| No relaunch | Screen Recording's Quit & Reopen, then resume |

## The proposed flow (for review)

About 6–7 minutes; real permissions take longer than the mock.

**0. Arrive** (~40 s)
1. Fovea opens on the desktop (switching out of a full-screen app if needed), and the notch opens: "I live up here." Language.
2. Clear the screen for the tour: the other apps hide and come back at the end. The list is saved, so it survives the relaunch.
3. Make it yours: the accent and the aura, live at the real notch.

**1. Turn things on** (~1½–2½ min, real System Settings)

4. **Device Control and Data Access.**
   - The card says why, in one line, then opens the exact list.
   - The person drags Fovea from the card into the list, or turns on the switch if Fovea is already there.
   - macOS asks for the password or Touch ID.
   - Fovea sees it live and comes back to the front.
5. **Microphone.** Continue, then macOS's own prompt, then the voice bar as the mic test.
6. **Screen & System Audio Recording.**
   - What Fovea looks at, then the exact list, then the same drag or switch.
   - macOS asks to Quit & Reopen, and Fovea reopens where it was.

**2. Point and say** (~2 min, Fovea's practice window)

7. Watch once: a pointer Fovea draws shows fn ⌃, ⌘, a drag, fn ⌃.
8. Try 1: fn ⌃, ⌘, drag over the photo, speak, fn ⌃, then the review card.
9. Try 2: fn ⌃, hold left ⌥, mark the second paragraph, speak, fn ⌃.
10. Try 3 (can skip): fn ⌃, ⌘⌘ for the whole screen, or ⌥ and a click on a file on the shelf, fn ⌃.

**3. Send it** (~1½ min)

11. The agents found on this Mac.
12. Sign in, in the browser, and come back.
13. Return sends to the practice chat. The board at the notch, the answer, then fn for a follow-up. Automation is asked only if the send goes to Terminal.

**4. Dictation** (~30 s, can skip)

14. Click Fovea's practice reply box, fn, speak, fn: the words land.

**5. Home** (~20 s)

15. The hidden apps come back, exactly those. Home opens with the practice captures. Open at login (macOS shows "Login item added"). "Next time, start from the notch."

## Answered Oct 8

- **The first send is real:** Claude Code edits the practice files.
  - It runs as Fovea's own process, so there's no Automation prompt.
  - `claude auth status` says whether it's signed in. On this Mac it isn't (the desktop app's Claude Code is separate), so the practice agent stands in.
- **The practice files are on the desktop,** cleared at the end. Writing them to `~/Desktop` costs one Desktop access prompt.
- **No step for connecting agents:** they connect by themselves.
- **Every step has a way past it.**
- The prototype and [ONBOARDING.md](ONBOARDING.md) follow these.

## Oct 9: what the new flow asks of a real Mac

- **Both permissions in one step.** System Settings shows one list at a time, so it's two drags in a row:
  - **First, Device Control and Data Access:** each drop asks for Touch ID or the password, and Fovea is in, already on, seen live.
  - **Then Screen & System Audio Recording:** Fovea opens it by its link (tested above).
  - **Once Accessibility is allowed,** Fovea may move System Settings next to the notch for the second drop. Before that it can't.
  - **One Quit & Reopen** at the end (tested above).
  - **Still to test by hand:** the drop into Screen & System Audio Recording.
- **The blog task** points at a real local page.
  - **In the prototype:** the page is drawn in a web view, and pictures of the mock screen need no permission.
  - **In the product:** taking the whole screen or a part of it is Screen Recording's job, which is why that permission comes first.
- **Real words** need macOS's microphone and speech prompts, and those need the app to say why in its Info.plist.
  - **The prototype:** runs them from its bundle (`Prototypes/scripts/onboarding-app.sh`).
  - **The product:** transcribes without Speech Recognition (window feedback rows 3–5).
- **Words for the window under the pointer:** the product types them into whatever app is there, which needs Accessibility (asked first). The prototype's two windows are its own.
- **Dictation apps** are found by bundle ID or by name in /Applications.
- **Their words (round two), checked on this Mac by structure only:** table and column names, never a word.
  - **Wispr Flow** keeps them in `~/Library/Application Support/Wispr Flow/flow.sqlite`, table `Dictionary`: `phrase`, `replacement`, `isDeleted`, `isSnippet` and more.
  - **VoiceOS** keeps them in `voiceos.db`, table `dictionary`: `text`, `deleted_at` and more.
  - **Typeless** keeps no dictionary on the Mac, only an on/off setting for it; its words are online.
  - **Superwhisper's** leftover database has none.
  - **Connect** opens the file read-only and immutable (it's never changed or locked), only when clicked. A new version of either app could move them: the reader then says it couldn't read them, and a paste takes over.

## Decisions for review

1. **Clearing the screen:** ask first ("Clear my screen", so a call isn't hidden), do it automatically, or use Fovea's own backdrop?
2. **Permissions:** drag Fovea into the list (tested: one drag and the password or Touch ID, already switched on, seen live; no system alert), or Fovea asks, macOS's alert, find Fovea in the list, flip its switch?
3. **Practice:** Fovea's own practice window (marks are exact), or a real web page in their browser (closer to daily use; the highlighter depends on the browser)?
4. **First send:** a practice chat Fovea answers itself, or a real Claude Code session (needs Automation, and touches their real agent)?

## The hand test (done Oct 8 for Accessibility)

Repeat it with **Open Screen Recording** to check that list and its Quit & Reopen.

1. Open Fovea Probe: `open "/private/tmp/claude-501/-Users-yulunryanwu-Desktop-things-fovea-app-ui-v1/e0ac4c12-a21b-4334-a159-d173a425bb7c/scratchpad/probe/FoveaProbe.app"`.
2. Click **Open Accessibility**.
3. Drag the tile from the notch card into the list, and confirm with Touch ID.
4. **What to watch:** does Fovea Probe appear, and is its switch already on? The probe's log says "live: Accessibility is now allowed — no relaunch" the moment it is.
5. **Optional:** click **Ask: Screen Recording** to see macOS's own prompt, and whether it lists the probe by itself.
6. **Afterwards:** remove Fovea Probe from the lists with −.
