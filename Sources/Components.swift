import SwiftUI

// MARK: - Buttons

/// The big round button at the heart of the app.
struct RoundActionButton: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.sans(20, .semibold))
                .foregroundStyle(Color.white)
                .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
                .frame(width: 118, height: 118)
                .background(RoundButtonFace(hovering: hovering))
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .keyboardShortcut(.defaultAction)
        .onHover { hovering = $0 }
    }
}

struct RoundButtonFace: View {
    var hovering = false
    var showsRing = true

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.emerald.opacity(0.3))
                .blur(radius: 22)
                .scaleEffect(1.12)
            if showsRing {
                Circle()
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    .padding(-12)
            }
            Circle()
                .fill(Theme.actionGradient)
            Circle()
                .fill(LinearGradient(colors: [Color.white.opacity(0.35), Color.clear],
                                     startPoint: .top, endPoint: .center))
                .padding(3)
            Circle()
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        }
        .brightness(hovering ? 0.06 : 0)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct PillButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.sans(compact ? 11 : 13, .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 4 : 7)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.24 : 0.14)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18)))
            .contentShape(Capsule())
    }
}

// MARK: - Surfaces

struct GlassCard: ViewModifier {
    var radius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.glass))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.hairline))
    }
}

extension View {
    func glassCard(radius: CGFloat = 16) -> some View {
        modifier(GlassCard(radius: radius))
    }
}

// MARK: - Text pieces

/// A small keycap used when naming a key in text, e.g. [esc].
struct KeyGlyph: View {
    let label: String

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(Theme.sans(12, .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .frame(minWidth: 26, minHeight: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.white.opacity(0.25)))
    }
}

struct EmergencyHint: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(Theme.amber)
            Text("Emergency exit: hold")
                .foregroundStyle(Theme.textSoft)
            KeyGlyph("esc")
            Text("+")
                .foregroundStyle(Theme.textFaint)
            KeyGlyph("delete")
            Text("for 3 seconds")
                .foregroundStyle(Theme.textSoft)
        }
        .font(Theme.sans(12, .medium))
    }
}

struct PageHeader: View {
    let title: String
    let accent: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            (Text(title + " ").font(Theme.sans(28, .bold))
                + Text(accent).font(Theme.serifItalic(28)).foregroundColor(Theme.emerald))
            Text(subtitle)
                .font(Theme.sans(14))
                .foregroundStyle(Theme.textSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct InfoRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.emerald)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.sans(13, .semibold))
                Text(text)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

struct InfoGroup<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.sans(15, .semibold))
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }
}

// MARK: - Illustration

/// Glossy floating keycaps with a sparkle: the main picture on the home screen.
struct HeroArt: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.emerald.opacity(0.28))
                .frame(width: 210, height: 210)
                .blur(radius: 50)
            GlossyKeycap(symbol: nil, letter: "K", size: 74)
                .rotationEffect(.degrees(-12))
                .offset(x: -96, y: 26)
                .opacity(0.85)
            GlossyKeycap(symbol: nil, letter: "C", size: 64)
                .rotationEffect(.degrees(10))
                .offset(x: 96, y: 34)
                .opacity(0.8)
            GlossyKeycap(symbol: "sparkles", letter: nil, size: 124)
            Bubble(size: 16).offset(x: 70, y: -62)
            Bubble(size: 10).offset(x: 94, y: -34)
            Bubble(size: 12).offset(x: -76, y: -54)
        }
        .frame(width: 300, height: 160)
    }
}

struct GlossyKeycap: View {
    let symbol: String?
    let letter: String?
    let size: CGFloat

    var body: some View {
        let radius = size * 0.22
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x1D2B25), Color(hex: 0x070D0A)],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: Color.black.opacity(0.45), radius: size * 0.12, y: size * 0.08)
            RoundedRectangle(cornerRadius: radius * 0.8, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x2A3C34), Color(hex: 0x131D18)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(size * 0.08)
                .offset(y: -size * 0.03)
            RoundedRectangle(cornerRadius: radius * 0.8, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.18), Color.clear],
                                     startPoint: .top, endPoint: .center))
                .padding(size * 0.08)
                .offset(y: -size * 0.03)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Theme.emerald.opacity(0.7), Color.white.opacity(0.05)],
                                             startPoint: .top, endPoint: .bottom),
                              lineWidth: 1.2)
            Group {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.36, weight: .semibold))
                } else if let letter {
                    Text(letter)
                        .font(.system(size: size * 0.36, weight: .semibold))
                }
            }
            .foregroundStyle(LinearGradient(colors: [Color.white, Theme.emerald],
                                            startPoint: .top, endPoint: .bottom))
            .offset(y: -size * 0.03)
        }
        .frame(width: size, height: size)
    }
}

struct Bubble: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color.white.opacity(0.5), Theme.emerald.opacity(0.15)],
                                 center: UnitPoint(x: 0.35, y: 0.3),
                                 startRadius: 0,
                                 endRadius: size * 0.7))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8))
            .frame(width: size, height: size)
    }
}

// MARK: - Emergency exit feedback

/// Shown while esc + delete are held, filling up over three seconds.
struct EmergencyHUD: View {
    let start: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.05)) { context in
            let progress = min(1, max(0, context.date.timeIntervalSince(start) / EmergencyExit.holdTime))
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(Theme.amber, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "escape")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                }
                .frame(width: 84, height: 84)
                Text("Keep holding to exit \(Brand.appName)")
                    .font(Theme.sans(16, .semibold))
                    .foregroundStyle(Theme.text)
                Text("Let go to cancel")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.textSoft)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.forest.opacity(0.95)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline))
            .shadow(color: Color.black.opacity(0.4), radius: 30, y: 10)
        }
    }
}
