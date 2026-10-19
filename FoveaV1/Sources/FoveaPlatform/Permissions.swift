import AppKit
import AVFoundation
import Speech
import ServiceManagement
import IOKit.hid
import FoveaKit

// The five things Fovea asks for, where each stands, and the System Settings page for each.

public enum Permission: String, CaseIterable, Sendable {
    /// Device Control and Data Access on macOS 27 (Accessibility before): the keys in any app,
    /// typing the words where you are, reading what you highlight.
    case accessibility
    /// Screen & System Audio Recording: what you point at.
    case screenRecording
    case microphone
    case speechRecognition
    /// Input Monitoring (Oct 15, the dev team's review OB-01.5): the shortcuts heard in every app.
    /// Their key engine listens with it; 1.0's own works without it, so 1.0 asks but never waits on it.
    case inputMonitoring

    /// The page's name as macOS 27 writes it.
    public var paneName: String { L(key: englishPaneName) }

    var englishPaneName: String {
        switch self {
        case .accessibility: return "Device Control and Data Access"
        case .screenRecording: return "Screen & System Audio Recording"
        case .microphone: return "Microphone"
        case .speechRecognition: return "Speech Recognition"
        case .inputMonitoring: return "Input Monitoring"
        }
    }

    var anchor: String {
        switch self {
        case .accessibility: return "Privacy_Accessibility"
        case .screenRecording: return "Privacy_ScreenCapture"
        case .microphone: return "Privacy_Microphone"
        case .speechRecognition: return "Privacy_SpeechRecognition"
        case .inputMonitoring: return "Privacy_ListenEvent"
        }
    }

    /// Allowed now. Screen Recording is read as it stood at launch (macOS's rule).
    @MainActor public var granted: Bool {
        switch self {
        case .accessibility: return AXIsProcessTrusted()
        case .screenRecording: return CGPreflightScreenCaptureAccess()
        case .microphone: return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        case .speechRecognition: return SFSpeechRecognizer.authorizationStatus() == .authorized
        case .inputMonitoring: return IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        }
    }

    /// The person said no (rather than not being asked yet).
    @MainActor public var denied: Bool {
        switch self {
        case .accessibility, .screenRecording: return !granted
        case .microphone:
            let s = AVCaptureDevice.authorizationStatus(for: .audio)
            return s == .denied || s == .restricted
        case .speechRecognition:
            let s = SFSpeechRecognizer.authorizationStatus()
            return s == .denied || s == .restricted
        case .inputMonitoring:
            return IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeDenied
        }
    }

    /// Asks macOS for Input Monitoring: the system's own prompt the first time, then nothing (the
    /// person turns it on in System Settings). Returns whether it's allowed now.
    @MainActor @discardableResult public static func requestInputMonitoring() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    /// Opens System Settings at this page's list.
    @MainActor public func openSettings() {
        let modern = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(anchor)")
        let legacy = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")
        if let modern, NSWorkspace.shared.open(modern) { return }
        if let legacy { NSWorkspace.shared.open(legacy) }
    }
}

/// Opens Fovea again: a fresh copy, then this one quits (Screen Recording only counts after a
/// relaunch; macOS's own Quit & Reopen does the same).
public enum Relauncher {
    /// Set while Fovea quits to reopen (the first run's hidden apps stay hidden through it).
    @MainActor public private(set) static var relaunching = false

    @MainActor public static func relaunch() {
        relaunching = true
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.arguments = Array(CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("--step=") && $0 != "--reset-onboarding" && $0 != "--reset-all" })
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}

/// Open at login (macOS shows "Login item added" the first time).
public enum LoginItem {
    @MainActor public static var enabled: Bool { SMAppService.mainApp.status == .enabled }

    @MainActor public static func set(_ on: Bool) {
        // Only the bundled app can be a login item.
        guard Bundle.main.bundleIdentifier != nil else { return }
        do {
            if on, SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            if !on, SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Fovea: login item: \(error.localizedDescription)")
        }
    }

    /// Launched by macOS at login (so Home stays put away).
    public static var launchedAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == kAEOpenApplication
            && event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}

/// "Clear my screen": the other apps hidden for the first run, and exactly those brought back.
public enum AppHider {
    public struct Hidden: Codable, Hashable, Sendable {
        public var bundleID: String
        public var pid: Int32
        public init(bundleID: String, pid: Int32) { self.bundleID = bundleID; self.pid = pid }
    }

    /// Hides every ordinary app that's showing, but Fovea; Finder too, so its windows go (its
    /// desktop's icons stay: `DesktopCover` covers them). Returns what it hid.
    @MainActor public static func hideOthers() -> [Hidden] {
        let me = ProcessInfo.processInfo.processIdentifier
        var hidden: [Hidden] = []
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && !app.isHidden && app.processIdentifier != me {
            // hide() reports "refused" even when it works; what's hidden is checked by listing.
            _ = app.hide()
            hidden.append(Hidden(bundleID: app.bundleIdentifier ?? "", pid: app.processIdentifier))
        }
        return hidden
    }

    /// Brings back the apps that were hidden, the ones still running.
    @MainActor public static func restore(_ apps: [Hidden]) {
        for entry in apps {
            let running = NSRunningApplication(processIdentifier: entry.pid)
                ?? NSRunningApplication.runningApplications(withBundleIdentifier: entry.bundleID).first
            _ = running?.unhide()
        }
    }
}
