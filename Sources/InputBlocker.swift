import AppKit
import CoreGraphics

enum KeyCode {
    /// Brightness, volume and media keys don't have key codes. They arrive as
    /// NX_SYSDEFINED events carrying an NX_KEYTYPE_* value, so they get their own number space.
    static func media(_ nxKeyType: Int) -> Int { 1000 + nxKeyType }
    static let capsLock = 57
}

/// Swallows keyboard input system-wide (and optionally trackpad/mouse input) using a
/// Quartz event tap placed at the very front of the HID event stream.
/// Returning `nil` from the tap drops an event before any app or shortcut sees it.
final class InputBlocker {
    enum KeyEvent {
        case down(Int)      // key code, or KeyCode.media(...)
        case up(Int)
        case modifier(Int)  // shift, control, option, command, fn/Globe, caps lock
    }

    /// Called on the main thread for every key event that gets swallowed.
    var onKeyEvent: ((KeyEvent) -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var blocksPointer = false

    // Raw CGEventType values.
    private static let keyboardEventTypes: [UInt32] = [
        10, // keyDown
        11, // keyUp
        12, // flagsChanged: modifiers, fn/Globe, caps lock
        14, // NX_SYSDEFINED: brightness, volume and media keys on the function row
    ]

    private static let pointerEventTypes: [UInt32] = [
        1, 2, 3, 4,      // left/right button down/up (clicks and taps)
        5, 6, 7,         // moved, left/right dragged
        22,              // scroll wheel (two-finger scrolling)
        25, 26, 27,      // other buttons
        18, 19, 20,      // rotate, begin/end gesture
        29, 30, 31, 32,  // gesture, magnify, swipe, smart magnify
        34,              // pressure (Force Touch)
    ]

    /// Returns false if macOS refuses to create the tap (usually a missing permission).
    func start(blockPointer: Bool) -> Bool {
        stop()
        blocksPointer = blockPointer

        let types = Self.keyboardEventTypes + (blockPointer ? Self.pointerEventTypes : [])
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1)) }

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let blocker = Unmanaged<InputBlocker>.fromOpaque(userInfo).takeUnretainedValue()
            return blocker.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = source
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    /// Returning nil swallows the event. Returning it unchanged lets it through.
    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let passThrough = Unmanaged.passUnretained(event)

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS switches a tap off if it ever stalls. Switch it straight back on.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return passThrough

        case .keyDown:
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                onKeyEvent?(.down(Int(event.getIntegerValueField(.keyboardEventKeycode))))
            }
            return nil

        case .keyUp:
            onKeyEvent?(.up(Int(event.getIntegerValueField(.keyboardEventKeycode))))
            return nil

        case .flagsChanged:
            onKeyEvent?(.modifier(Int(event.getIntegerValueField(.keyboardEventKeycode))))
            return nil

        default:
            break
        }

        if type.rawValue == 14 { // NX_SYSDEFINED
            // Subtype 8 = media/brightness/volume keys. Other subtypes (e.g. auxiliary
            // mouse buttons) are only blocked when the trackpad is locked too.
            guard let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 else {
                return blocksPointer ? nil : passThrough
            }
            let data = nsEvent.data1
            let keyType = (data & 0xFFFF0000) >> 16
            let keyState = (data & 0xFF00) >> 8
            let isRepeat = (data & 0x1) == 1
            if keyState == 0xA, !isRepeat { onKeyEvent?(.down(KeyCode.media(keyType))) }
            if keyState == 0xB { onKeyEvent?(.up(KeyCode.media(keyType))) }
            return nil
        }

        // Everything else in the mask is pointer input, which is only in the mask
        // when the trackpad is locked.
        return nil
    }
}
