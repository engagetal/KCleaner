import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = AppIcon.image
        NSApp.mainMenu = MainMenu.make(target: self)
        model.appDidLaunch()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Never quit mid-clean from a stray ⌘Q. The emergency exit unlocks first, then quits.
        (model.isCleaning || model.isUninstalling) ? .terminateCancel : .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { model.showMainWindow() }
        return true
    }

    @objc func showAbout(_ sender: Any?) { model.showSection(.about) }
    @objc func showHelp(_ sender: Any?) { model.showSection(.guide) }
    @objc func showSafety(_ sender: Any?) { model.showSection(.safety) }
    @objc func showCleaner(_ sender: Any?) { model.showSection(.clean) }
    @objc func uninstall(_ sender: Any?) { model.showUninstall() }
}

// `KCleaner --render-icon <file.png>` draws the app icon and exits without opening any windows.
// The build script uses it to create the Finder icon.
let arguments = CommandLine.arguments
if let flag = arguments.firstIndex(of: "--render-icon"), arguments.count > flag + 1 {
    exit(AppIcon.writePNG(to: arguments[flag + 1], pixels: 1024) ? 0 : 1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
