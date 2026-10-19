import AppKit
import SwiftUI

/// Everything that names or describes the product and its maker lives here.
enum Brand {
    static let appName = "KCleaner"
    static let fullName = "Keyboard Cleaner"
    static let tagline = "Lock your keyboard, wipe it clean, unlock."

    static let company = "Engagetal Solutions"
    static let companyLegal = "Engagetal Solutions (OPC) Private Limited"
    static let companyBlurb = "Engagetal connects companies with vetted engineers and go-to-market specialists, and trains new talent through its part-time Fellowships."
    static let website = "engagetal.com"
    static let email = "hello@engagetal.com"
    static let location = "New Delhi, India"
    static let copyright = "© 2026 Engagetal Solutions (OPC) Private Limited. Licensed under the MIT License."

    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    /// The official Engagetal logo, if Branding/engagetal-logo.png was present at build time.
    /// It is read from inside the app itself. Nothing is ever downloaded.
    static let logo: NSImage? = {
        guard let path = Bundle.main.path(forResource: "engagetal-logo", ofType: "png") else { return nil }
        return NSImage(contentsOfFile: path)
    }()
}

enum Theme {
    // Engagetal's site uses a deep forest green (#0B1A13) as its theme colour.
    // The rest of the palette grows out of it: greens for "clean", amber for "careful".
    static let forest    = Color(hex: 0x0B1A13)
    static let pine      = Color(hex: 0x0F2E22)
    static let lagoon    = Color(hex: 0x0A2A2C)
    static let emerald   = Color(hex: 0x34D97A)   // Engagetal's brand green (logo and buttons)
    static let logoTile  = Color(hex: 0x112016)   // the dark tile behind the logo's "e"
    static let jade      = Color(hex: 0x12B886)
    static let teal      = Color(hex: 0x1FB5A8)
    static let sky       = Color(hex: 0x4CC3F5)
    static let royal     = Color(hex: 0x2F6FEB)
    static let amber     = Color(hex: 0xF7B84B)
    static let orange    = Color(hex: 0xF08A3C)
    static let violet    = Color(hex: 0xA98BFA)
    static let grape     = Color(hex: 0x7B5CE0)
    static let danger    = Color(hex: 0xE5484D)

    static let text      = Color.white
    static let textSoft  = Color.white.opacity(0.7)
    static let textFaint = Color.white.opacity(0.45)
    static let glass     = Color.white.opacity(0.07)
    static let hairline  = Color.white.opacity(0.1)

    static let actionGradient = LinearGradient(
        colors: [emerald, teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Engagetal's headlines pair a plain sans with an italic serif phrase. KCleaner does the same.
    static func serifItalic(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif).italic()
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// The deep green backdrop used by the main window and clean mode.
struct BrandBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.forest, Theme.pine, Theme.lagoon],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Theme.emerald.opacity(0.26), Color.clear],
                center: UnitPoint(x: 0.78, y: 0.08),
                startRadius: 0,
                endRadius: 520
            )
            RadialGradient(
                colors: [Theme.teal.opacity(0.2), Color.clear],
                center: UnitPoint(x: 0.1, y: 0.95),
                startRadius: 0,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
    }
}

/// The Engagetal logo: a dark tile with a green italic "e" and a dot, then "engagetal" in a serif.
/// Uses the official PNG when one was bundled at build time; otherwise draws the same thing in code.
struct EngagetalMark: View {
    var size: CGFloat = 13

    var body: some View {
        let tile = size * 1.7
        if let logo = Brand.logo {
            Image(nsImage: logo)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: tile)
        } else {
            HStack(spacing: tile * 0.33) {
                ZStack {
                    RoundedRectangle(cornerRadius: tile * 0.19, style: .continuous)
                        .fill(Theme.logoTile)
                    RoundedRectangle(cornerRadius: tile * 0.19, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    Text("e")
                        .font(.system(size: tile * 0.74, weight: .regular, design: .serif).italic())
                        .foregroundStyle(Theme.emerald)
                        .offset(x: tile * 0.01, y: tile * 0.0)
                    Circle()
                        .fill(Theme.emerald)
                        .frame(width: tile * 0.105, height: tile * 0.105)
                        .offset(x: tile * 0.275, y: -tile * 0.255)
                }
                .frame(width: tile, height: tile)

                Text("engagetal")
                    .font(.system(size: tile * 0.69, weight: .regular, design: .serif))
                    .tracking(-tile * 0.03)
                    .foregroundStyle(Theme.text)
            }
        }
    }
}
