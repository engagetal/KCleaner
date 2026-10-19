import AppKit
import ApplicationServices
import SwiftUI

// MARK: - Permissions

enum Permissions {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Adds KCleaner to the Accessibility list and shows macOS's own prompt.
    static func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func requestInputMonitoring() {
        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
    }

    /// Opens System Settings on this Mac. This is a local settings link, not a web address.
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Clean-mode window

/// Borderless full-screen window that quietly eats any key event reaching it.
/// A backstop in case something ever slips past the lock: no beeps, no ⌘Q.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func keyDown(with event: NSEvent) {}
    override func keyUp(with event: NSEvent) {}
    override func flagsChanged(with event: NSEvent) {}
    override func performKeyEquivalent(with event: NSEvent) -> Bool { true }
}

// MARK: - Menus

enum MainMenu {
    static func make(target: AnyObject) -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(item("About \(Brand.appName)", #selector(AppDelegate.showAbout(_:)), "", target))
        appMenu.addItem(item("Safety & Privacy", #selector(AppDelegate.showSafety(_:)), "", target))
        appMenu.addItem(.separator())
        appMenu.addItem(item("Uninstall \(Brand.appName)…", #selector(AppDelegate.uninstall(_:)), "", target))
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide \(Brand.appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit \(Brand.appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(item("Clean Keyboard", #selector(AppDelegate.showCleaner(_:)), "1", target))
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        let helpItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(item("\(Brand.appName) Help", #selector(AppDelegate.showHelp(_:)), "?", target))
        helpMenu.addItem(item("Safety & Privacy", #selector(AppDelegate.showSafety(_:)), "", target))
        helpItem.submenu = helpMenu
        main.addItem(helpItem)

        return main
    }

    private static func item(_ title: String, _ action: Selector, _ key: String, _ target: AnyObject) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        return item
    }
}

// MARK: - App icon

/// The app icon is drawn in code: a glossy dark keycap with a sparkle on a forest-green tile.
/// The build script also calls `KCleaner --render-icon` to turn this into the Finder icon.
enum AppIcon {
    static let image: NSImage = NSImage(size: NSSize(width: 512, height: 512), flipped: false) { rect in
        AppIcon.draw(in: rect)
        return true
    }

    static func writePNG(to path: String, pixels: Int) -> Bool {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else {
            return false
        }
        rep.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: URL(fileURLWithPath: path))) != nil
    }

    static func draw(in rect: NSRect) {
        let s = rect.width / 1024
        let tileRect = rect.insetBy(dx: 100 * s, dy: 100 * s)
        let tile = NSBezierPath(roundedRect: tileRect, xRadius: 185 * s, yRadius: 185 * s)

        // Tile with a soft drop shadow
        NSGraphicsContext.saveGraphicsState()
        let tileShadow = NSShadow()
        tileShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        tileShadow.shadowOffset = NSSize(width: 0, height: -12 * s)
        tileShadow.shadowBlurRadius = 28 * s
        tileShadow.set()
        NSColor(Theme.forest).setFill()
        tile.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGradient(colors: [NSColor(Theme.pine), NSColor(Theme.forest), NSColor(Theme.lagoon)])?
            .draw(in: tile, angle: -60)

        // Green glow behind the keycap
        NSGraphicsContext.saveGraphicsState()
        tile.addClip()
        let glowCenter = NSPoint(x: tileRect.midX, y: tileRect.midY + 40 * s)
        NSGradient(colors: [NSColor(Theme.emerald).withAlphaComponent(0.55),
                            NSColor(Theme.emerald).withAlphaComponent(0)])?
            .draw(fromCenter: glowCenter, radius: 0, toCenter: glowCenter, radius: 430 * s, options: [])
        NSGraphicsContext.restoreGraphicsState()

        // Keycap skirt
        let capRect = NSRect(x: rect.midX - 250 * s, y: rect.midY - 240 * s, width: 500 * s, height: 470 * s)
        let skirt = NSBezierPath(roundedRect: capRect, xRadius: 110 * s, yRadius: 110 * s)
        NSGraphicsContext.saveGraphicsState()
        let capShadow = NSShadow()
        capShadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
        capShadow.shadowOffset = NSSize(width: 0, height: -22 * s)
        capShadow.shadowBlurRadius = 40 * s
        capShadow.set()
        NSColor(Color(hex: 0x070D0A)).setFill()
        skirt.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(starting: NSColor(Color(hex: 0x1D2B25)), ending: NSColor(Color(hex: 0x070D0A)))?
            .draw(in: skirt, angle: -90)

        // Keycap top face, with gloss
        let faceRect = capRect.insetBy(dx: 44 * s, dy: 44 * s).offsetBy(dx: 0, dy: 18 * s)
        let face = NSBezierPath(roundedRect: faceRect, xRadius: 80 * s, yRadius: 80 * s)
        NSGradient(starting: NSColor(Color(hex: 0x2A3C34)), ending: NSColor(Color(hex: 0x111A16)))?
            .draw(in: face, angle: -90)
        NSGraphicsContext.saveGraphicsState()
        face.addClip()
        NSGradient(starting: NSColor.white.withAlphaComponent(0.2), ending: NSColor.white.withAlphaComponent(0))?
            .draw(in: NSRect(x: faceRect.minX, y: faceRect.midY, width: faceRect.width, height: faceRect.height / 2),
                  angle: -90)
        NSGraphicsContext.restoreGraphicsState()

        // Green rim light
        NSColor(Theme.emerald).withAlphaComponent(0.6).setStroke()
        skirt.lineWidth = 6 * s
        skirt.stroke()

        // Shine symbol on the keycap
        let config = NSImage.SymbolConfiguration(pointSize: 200 * s, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(Theme.emerald), NSColor.white]))
        if let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            let size = symbol.size
            symbol.draw(in: NSRect(x: faceRect.midX - size.width / 2,
                                   y: faceRect.midY - size.height / 2,
                                   width: size.width,
                                   height: size.height))
        }

        // Soap bubbles
        let bubbles: [(CGFloat, CGFloat, CGFloat)] = [(760, 770, 46), (815, 690, 28), (250, 760, 34)]
        for (x, y, d) in bubbles {
            let bubble = NSBezierPath(ovalIn: NSRect(x: rect.minX + x * s, y: rect.minY + y * s, width: d * s, height: d * s))
            NSColor.white.withAlphaComponent(0.16).setFill()
            bubble.fill()
            NSColor.white.withAlphaComponent(0.5).setStroke()
            bubble.lineWidth = 3 * s
            bubble.stroke()
        }
    }
}

// MARK: - Formatting

enum TimeFormat {
    /// 0:42
    static func clock(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.up)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
