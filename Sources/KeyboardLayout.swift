import CoreGraphics

struct KeyCap: Identifiable {
    let id: String
    let label: String
    let symbol: String?
    let width: CGFloat      // in key units
    let codes: [Int]        // every code this physical key can send
    let caution: Bool       // true for keys software can't block (Touch ID)

    /// Stable number used to scatter the "dust" on this key.
    var seed: Int { id.unicodeScalars.reduce(7) { $0 &* 31 &+ Int($1.value) } }
}

/// An M-series MacBook keyboard, drawn with US labels. Keys are matched by position
/// (key code), so the map still works with other layouts; only the labels differ.
enum KeyboardLayout {
    struct ArrowKeys {
        let up, left, down, right: KeyCap
    }

    static let functionRow: [KeyCap] = [
        key("esc", 53, width: 1.5),
        key("F1", 122, 145, KeyCode.media(3), symbol: "sun.min"),               // brightness down
        key("F2", 120, 144, KeyCode.media(2), symbol: "sun.max"),               // brightness up
        key("F3", 99, 160, symbol: "rectangle.3.group"),                        // Mission Control
        key("F4", 118, 177, 131, symbol: "magnifyingglass"),                    // Spotlight
        key("F5", 96, 176, KeyCode.media(22), symbol: "mic"),                   // Dictation
        key("F6", 97, 178, KeyCode.media(21), symbol: "moon"),                  // Focus
        key("F7", 98, KeyCode.media(20), KeyCode.media(18), symbol: "backward"),
        key("F8", 100, KeyCode.media(16), symbol: "playpause"),
        key("F9", 101, KeyCode.media(19), KeyCode.media(17), symbol: "forward"),
        key("F10", 109, KeyCode.media(7), symbol: "speaker"),
        key("F11", 103, KeyCode.media(1), symbol: "speaker.wave.1"),
        key("F12", 111, KeyCode.media(0), symbol: "speaker.wave.3"),
        KeyCap(id: "touchid", label: "", symbol: "touchid", width: 1, codes: [], caution: true),
    ]

    static let numberRow: [KeyCap] = [
        key("`", 50, 10), key("1", 18), key("2", 19), key("3", 20), key("4", 21),
        key("5", 23), key("6", 22), key("7", 26), key("8", 28), key("9", 25),
        key("0", 29), key("-", 27), key("=", 24), key("delete", 51, width: 1.5),
    ]

    static let tabRow: [KeyCap] = [
        key("tab", 48, width: 1.5), key("Q", 12), key("W", 13), key("E", 14), key("R", 15),
        key("T", 17), key("Y", 16), key("U", 32), key("I", 34), key("O", 31), key("P", 35),
        key("[", 33), key("]", 30), key("\\", 42),
    ]

    static let capsRow: [KeyCap] = [
        key("caps lock", KeyCode.capsLock, width: 1.75), key("A", 0), key("S", 1), key("D", 2),
        key("F", 3), key("G", 5), key("H", 4), key("J", 38), key("K", 40), key("L", 37),
        key(";", 41), key("'", 39), key("return", 36, 76, width: 1.75),
    ]

    static let shiftRow: [KeyCap] = [
        key("shift", 56, width: 2.25), key("Z", 6), key("X", 7), key("C", 8), key("V", 9),
        key("B", 11), key("N", 45), key("M", 46), key(",", 43), key(".", 47), key("/", 44),
        key("shift", 60, width: 2.25),
    ]

    static let bottomRow: [KeyCap] = [
        key("fn", 63, symbol: "globe"), key("control", 59), key("option", 58),
        key("command", 55, width: 1.25), key("", 49, width: 5),
        key("command", 54, width: 1.25), key("option", 61),
    ]

    static let arrows = ArrowKeys(
        up: key("", 126, symbol: "arrowtriangle.up.fill"),
        left: key("", 123, symbol: "arrowtriangle.left.fill"),
        down: key("", 125, symbol: "arrowtriangle.down.fill"),
        right: key("", 124, symbol: "arrowtriangle.right.fill")
    )

    static let topRows: [[KeyCap]] = [functionRow, numberRow, tabRow, capsRow, shiftRow]

    static let allKeys: [KeyCap] =
        topRows.flatMap { $0 } + bottomRow + [arrows.up, arrows.left, arrows.down, arrows.right]

    static let wipeableCount = allKeys.filter { !$0.caution }.count

    private static let idByCode: [Int: String] = {
        var map: [Int: String] = [:]
        for key in allKeys {
            for code in key.codes { map[code] = key.id }
        }
        return map
    }()

    static func keyID(for code: Int) -> String? { idByCode[code] }

    private static func key(_ label: String, _ codes: Int..., width: CGFloat = 1, symbol: String? = nil) -> KeyCap {
        KeyCap(id: "key-\(codes[0])", label: label, symbol: symbol, width: width, codes: codes, caution: false)
    }
}
