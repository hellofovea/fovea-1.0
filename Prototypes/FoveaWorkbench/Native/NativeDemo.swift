import SwiftUI
import AppKit
import FoveaCore

// `--record-native <file.mp4>`: the Native design in motion, cropped to the notch and what drops
// below it, into a movie, then quit (docs/island/NATIVE.md). Voiceflow (the listening bar, the words
// coming, Paste not found), then Dispatch (the aura bar, Choose chat, the board, a session, the whole
// session), on the desktop in Light with the panels attached; the bars, the board and a session
// again in Dark; then Choose chat and the board with the panels floating.

extension WorkbenchModel {
    func recordNative(to url: URL) async {
        var waited = 0
        while stageProbe?.window == nil, waited < 50 {
            try? await Task.sleep(for: .milliseconds(100))
            waited += 1
        }
        guard let window = stageProbe?.window else { print("no window to record"); exit(1) }
        window.setContentSize(WorkbenchTokens.Snapshot.size)
        columnVisibility = .detailOnly
        pointerScripted = true
        design = .native
        nativePanels = .attached
        appearance = .light
        screenContent = .desktop
        try? await Task.sleep(for: .milliseconds(900))
        let width: CGFloat = 960
        let region = CGRect(x: (display.frame.width - width) / 2, y: 0, width: width, height: 640)
        guard let crop = windowRect(forDisplay: region),
              let recorder = WorkbenchRecorder(url: url, window: window, maxWidth: 1600, crop: crop, captionHeight: 64)
        else { print("cannot record to \(url.path)"); exit(1) }
        notchState = .silent
        try? await Task.sleep(for: .milliseconds(400))
        recorder.start()
        func caption(_ text: String) { recorder.caption = text }
        func pause(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }

        caption("Voiceflow: the bar is Liquid Glass, only the notch black; the waveform never a color, ink on light glass")
        voiceflowSelection = .voiceFlow
        await pause(2.4)
        caption("Transcribing: the progress line in the same ink")
        voiceflowSelection = .transcribing
        await pause(2.0)
        caption("Nowhere to paste: the glass grows down from the top edge, as Original's island does")
        voiceflowSelection = .pasteNotFound
        await pause(2.8)
        caption("Dispatch: the aura bar, glass too, in the colors chosen in Make it yours")
        v2Selection = .voice
        await pause(2.4)
        caption("Choose chat: one glass shape with the notch; Send in the accent")
        v2Selection = .send
        await pause(2.8)
        caption("The control board: macOS's own colors for needs you, done and failed; Run Tests says what it does")
        boardStyle = .sections
        v2Selection = .board
        await pause(3.2)
        caption("A session, then the whole session")
        v2Selection = .chat
        await pause(2.8)
        v2Selection = .whole
        await pause(2.8)
        caption("Dark: the same glass, dark; Voiceflow's waveform white")
        appearance = .dark
        voiceflowSelection = .voiceFlow
        await pause(2.0)
        v2Selection = .voice
        await pause(2.0)
        v2Selection = .board
        await pause(2.6)
        v2Selection = .chat
        await pause(2.4)
        caption("At rest: only the notch")
        v2Selection = .silent
        await pause(1.6)
        caption("Floating, the other choice: the same panels a gap under the notch")
        appearance = .light
        nativePanels = .floating
        v2Selection = .send
        await pause(2.6)
        v2Selection = .board
        await pause(2.8)
        v2Selection = .silent
        await pause(1.4)
        nativePanels = .attached
        caption("")
        await pause(0.4)
        await recorder.finish()
        print("wrote \(url.path) (\(recorder.frames) frames)")
        exit(0)
    }
}
