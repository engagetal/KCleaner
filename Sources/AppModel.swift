import AppKit
import Carbon.HIToolbox
import SwiftUI

enum TimerChoice: Int, CaseIterable, Identifiable {
    case manual = 0
    case thirtySeconds = 30
    case oneMinute = 60
    case twoMinutes = 120
    case fiveMinutes = 300

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .manual: return "By hand"
        case .thirtySeconds: return "After 30 sec"
        case .oneMinute: return "After 1 min"
        case .twoMinutes: return "After 2 min"
        case .fiveMinutes: return "After 5 min"
        }
    }

    var seconds: TimeInterval? { self == .manual ? nil : TimeInterval(rawValue) }
}

struct SessionSummary {
    let presses: Int
    let wipedKeys: Int
    let capsLockFlipped: Bool

    var message: String {
        var text = "All done: \(wipedKeys) of \(KeyboardLayout.wipeableCount) keys wiped."
        if capsLockFlipped {
            text += " Caps Lock got switched while you cleaned, so tap it once to switch it back."
        }
        return text
    }
}

/// Runs clean mode. Every path out of clean mode goes through `stop()`, which removes the
/// keyboard lock first. Safety nets, in order of how often they matter:
///   1. the round "hold to finish" button, or the timer the user picked;
///   2. the emergency exit (esc + delete for 3 s), which also quits the app;
///   3. a hard 10-minute limit that applies whatever was chosen;
///   4. clean mode ends if the Mac sleeps, locks or switches user;
///   5. the lock is an event tap owned by this process, so macOS removes it the moment
///      the app quits or crashes, and switches it off if the app ever stops responding.
final class AppModel: ObservableObject {
    /// Clean mode always ends after this long, whatever else happens.
    static let failsafe: TimeInterval = 10 * 60

    // Choices on the home screen
    @Published var section: AppSection = .clean
    @Published var lockTrackpad = false {
        didSet {
            // With the trackpad locked there is no way to press the finish button, so a timer is required.
            if lockTrackpad && timerChoice == .manual { timerChoice = .oneMinute }
        }
    }
    @Published var timerChoice: TimerChoice = .manual
    @Published private(set) var hasPermission = Permissions.isTrusted
    @Published private(set) var problem: String?

    // Live clean-mode state (kept in memory only, never written anywhere)
    @Published private(set) var isCleaning = false
    @Published private(set) var sessionLocksTrackpad = false
    @Published private(set) var sessionDuration: TimeInterval = 0
    @Published private(set) var endDate: Date?
    @Published private(set) var presses = 0
    @Published private(set) var wiped: Set<String> = []
    @Published private(set) var held: Set<String> = []
    @Published private(set) var lastSession: SessionSummary?
    @Published private(set) var secureInputActive = false
    @Published private(set) var emergencyHoldStart: Date?

    // Uninstall
    @Published private(set) var uninstallStage: UninstallStage?
    @Published var removeSourceFolder = true

    var isUninstalling: Bool {
        if case .some(.working) = uninstallStage { return true }
        return false
    }

    var availableTimerChoices: [TimerChoice] {
        lockTrackpad ? TimerChoice.allCases.filter { $0 != .manual } : TimerChoice.allCases
    }

    private let blocker = InputBlocker()
    private let emergency = EmergencyExit()
    private var mainWindow: NSWindow?
    private var overlayWindows: [NSWindow] = []
    private var unlockTimer: Timer?
    private var permissionTimer: Timer?
    private var activity: NSObjectProtocol?
    private var keyMonitor: Any?
    private var observers: [NSObjectProtocol] = []
    private var capsLockAtStart = false
    private var cursorHidden = false

    init() {
        blocker.onKeyEvent = { [weak self] event in self?.handleBlockedKey(event) }
        emergency.onHoldChanged = { [weak self] start in self?.emergencyHoldStart = start }
        emergency.onTrigger = { [weak self] in self?.emergencyQuit() }
    }

    func appDidLaunch() {
        installKeyMonitor()
        installSafetyObservers()

        // Notice when Accessibility access is switched on in System Settings.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refreshPermission() }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer

        showMainWindow()
    }

    // MARK: - Clean mode

    func start() {
        guard !isCleaning, uninstallStage == nil else { return }
        problem = nil

        guard Permissions.isTrusted else {
            hasPermission = false
            Permissions.requestAccessibility()
            Permissions.openAccessibilitySettings()
            return
        }

        presses = 0
        wiped = []
        held = []
        lastSession = nil
        emergency.reset()
        sessionLocksTrackpad = lockTrackpad

        guard blocker.start(blockPointer: lockTrackpad) else {
            Permissions.requestInputMonitoring()
            problem = "macOS didn't allow the keyboard lock. Quit and reopen \(Brand.appName), then check it's switched on under Privacy & Security > Accessibility and Input Monitoring."
            return
        }

        isCleaning = true
        secureInputActive = Bool(IsSecureEventInputEnabled())
        capsLockAtStart = Self.capsLockIsOn

        let limit = min(timerChoice.seconds ?? Self.failsafe, Self.failsafe)
        sessionDuration = limit
        endDate = timerChoice.seconds.map { Date().addingTimeInterval($0) }
        let timer = Timer(timeInterval: limit, repeats: false) { [weak self] _ in self?.stop() }
        RunLoop.main.add(timer, forMode: .common)
        unlockTimer = timer

        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleDisplaySleepDisabled],
            reason: "Keyboard cleaning in progress"
        )

        showOverlays()
        mainWindow?.orderOut(nil)

        if sessionLocksTrackpad {
            NSCursor.hide()
            cursorHidden = true
        }
    }

    func stop(returnToWindow: Bool = true) {
        guard isCleaning else { return }

        // Unlock first, before anything else can go wrong.
        blocker.stop()
        emergency.reset()
        unlockTimer?.invalidate()
        unlockTimer = nil
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        if cursorHidden {
            NSCursor.unhide()
            cursorHidden = false
        }

        lastSession = SessionSummary(
            presses: presses,
            wipedKeys: wiped.count,
            capsLockFlipped: Self.capsLockIsOn != capsLockAtStart
        )
        isCleaning = false
        endDate = nil
        held = []

        if returnToWindow {
            section = .clean
            showMainWindow() // before closing the overlays, so a window is always open
        }
        let closing = overlayWindows
        overlayWindows = []
        closing.forEach { $0.close() }
    }

    /// Called from the overlay's own button, so let the gesture finish before its window closes.
    func requestUnlock() {
        DispatchQueue.main.async { [weak self] in self?.stop() }
    }

    private func emergencyQuit() {
        guard !isUninstalling else { return } // never interrupt an uninstall halfway
        stop(returnToWindow: false)
        NSApp.terminate(nil)
    }

    // MARK: - Uninstall

    func showUninstall() {
        guard !isCleaning, !isUninstalling else { return }
        removeSourceFolder = true
        showMainWindow()
        uninstallStage = .confirm(Uninstaller.makePlan())
    }

    func cancelUninstall() {
        guard !isUninstalling else { return }
        uninstallStage = nil
    }

    func performUninstall(_ plan: UninstallPlan) {
        guard !isCleaning, !isUninstalling else { return }
        uninstallStage = .working
        let includeSourceFolder = removeSourceFolder
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let report = Uninstaller.run(plan, includeSourceFolder: includeSourceFolder)
            DispatchQueue.main.async {
                self?.uninstallStage = .done(report)
            }
        }
    }

    // MARK: - Keys

    private func handleBlockedKey(_ event: InputBlocker.KeyEvent) {
        switch event {
        case .down(let code): emergency.keyDown(code)
        case .up(let code): emergency.keyUp(code)
        case .modifier: emergency.otherKeyPressed()
        }
        record(event)
    }

    /// Keys that reach KCleaner's own windows: normally only outside clean mode. During clean
    /// mode this is a backstop for when another app's Secure Keyboard Entry hides keys from the
    /// lock. Either way the emergency exit keeps working, and during clean mode the key is dropped.
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            let code = Int(event.keyCode)
            switch event.type {
            case .keyDown:
                if !event.isARepeat {
                    self.emergency.keyDown(code)
                    if self.isCleaning { self.record(.down(code)) }
                }
            case .keyUp:
                self.emergency.keyUp(code)
                if self.isCleaning { self.record(.up(code)) }
            case .flagsChanged:
                self.emergency.otherKeyPressed()
                if self.isCleaning { self.record(.modifier(code)) }
            default:
                break
            }
            return self.isCleaning ? nil : event
        }
    }

    private func record(_ event: InputBlocker.KeyEvent) {
        guard isCleaning else { return }
        switch event {
        case .down(let code):
            presses += 1
            guard let id = KeyboardLayout.keyID(for: code) else { return }
            markWiped(id)
            held.insert(id)

        case .up(let code):
            guard let id = KeyboardLayout.keyID(for: code) else { return }
            held.remove(id)

        case .modifier(let code):
            guard let id = KeyboardLayout.keyID(for: code) else { return }
            markWiped(id)
            if code == KeyCode.capsLock {
                presses += 1 // caps lock reports each press once, with no release
                return
            }
            if held.contains(id) {
                held.remove(id)
            } else {
                held.insert(id)
                presses += 1
            }
        }
    }

    private func markWiped(_ id: String) {
        if !wiped.contains(id) { wiped.insert(id) }
    }

    private static var capsLockIsOn: Bool {
        CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
    }

    // MARK: - Safety observers

    private func installSafetyObservers() {
        let workspace = NSWorkspace.shared.notificationCenter
        let endingEvents: [Notification.Name] = [
            NSWorkspace.willSleepNotification,
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification,
        ]
        for name in endingEvents {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.stop()
            })
        }

        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in
            self?.stop()
        })

        // A display was added or removed: redraw the cover so no screen is left without it.
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.isCleaning else { return }
            self.showOverlays()
        })
    }

    // MARK: - Windows

    func showMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 940, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = Brand.appName
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = NSColor(Theme.forest)
            window.contentView = NSHostingView(rootView: MainWindowView().environmentObject(self))
            window.setContentSize(NSSize(width: 940, height: 640))
            window.center()
            mainWindow = window
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSection(_ section: AppSection) {
        guard !isCleaning else { return }
        self.section = section
        showMainWindow()
    }

    private func showOverlays() {
        NSApp.activate(ignoringOtherApps: true)
        let previous = overlayWindows
        overlayWindows = NSScreen.screens.map { makeOverlay(for: $0) }
        previous.forEach { $0.close() }
    }

    private func makeOverlay(for screen: NSScreen) -> NSWindow {
        let window = OverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.setFrame(screen.frame, display: false)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.isOpaque = true
        window.hasShadow = false
        window.backgroundColor = NSColor(Theme.forest)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = NSHostingView(rootView: CleanModeView().environmentObject(self))
        window.makeKeyAndOrderFront(nil)
        return window
    }

    private func refreshPermission() {
        let trusted = Permissions.isTrusted
        guard trusted != hasPermission else { return }
        hasPermission = trusted
        if trusted && !isCleaning {
            problem = nil
            showMainWindow() // bring KCleaner back to the front after access is granted
        }
    }
}
