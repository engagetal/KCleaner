import SwiftUI

struct CleanModeView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(spacing: 24) {
                LockBadge(locksTrackpad: model.sessionLocksTrackpad)
                VStack(spacing: 2) {
                    Text("Wipe away.")
                        .font(Theme.sans(44, .bold))
                    Text(model.sessionLocksTrackpad
                         ? "Keyboard and trackpad are paused."
                         : "Nothing you press will type.")
                        .font(Theme.serifItalic(26))
                        .foregroundStyle(Theme.emerald)
                }
                KeyboardMapView(wiped: model.wiped, held: model.held)
                ProgressLine(presses: model.presses,
                             wiped: model.wiped.count,
                             total: KeyboardLayout.wipeableCount)
                UnlockControls()
            }
            .padding(40)

            VStack {
                HStack(spacing: 8) {
                    Image(nsImage: AppIcon.image)
                        .resizable()
                        .frame(width: 26, height: 26)
                    Text(Brand.appName)
                        .font(Theme.sans(14, .bold))
                    Text("by")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.textFaint)
                    EngagetalMark(size: 12)
                    Spacer()
                }
                Spacer()
                VStack(spacing: 8) {
                    EmergencyHint()
                    if model.secureInputActive {
                        Label("Another app has Secure Keyboard Entry on, so a few shortcuts may still get through.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.sans(11, .medium))
                            .foregroundStyle(Theme.amber)
                    }
                    Label("The Touch ID button can't be paused. Pressing it ends clean mode.", systemImage: "touchid")
                        .font(Theme.sans(11, .medium))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            .padding(28)

            if let start = model.emergencyHoldStart {
                Color.black.opacity(0.35)
                EmergencyHUD(start: start)
            }
        }
        .foregroundStyle(Theme.text)
        .ignoresSafeArea()
    }
}

// MARK: - Keyboard map

struct KeyboardMapView: View {
    let wiped: Set<String>
    let held: Set<String>
    var unit: CGFloat = 42
    var gap: CGFloat = 6

    var body: some View {
        VStack(spacing: gap) {
            ForEach(Array(KeyboardLayout.topRows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: gap) {
                    ForEach(row) { key in
                        cap(key, height: index == 0 ? unit * 0.72 : unit)
                    }
                }
            }
            HStack(spacing: gap) {
                ForEach(KeyboardLayout.bottomRow) { key in
                    cap(key, height: unit)
                }
                arrowCluster
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08))
                )
        )
    }

    /// Width of a key spanning `units` key widths, including the gaps it covers.
    private func span(_ units: CGFloat) -> CGFloat { units * unit + (units - 1) * gap }

    private func cap(_ key: KeyCap, height: CGFloat) -> some View {
        KeyCapView(key: key, isWiped: wiped.contains(key.id), isHeld: held.contains(key.id))
            .frame(width: span(key.width), height: height)
    }

    /// MacBook-style inverted T with half-height keys.
    private var arrowCluster: some View {
        let half = (unit - gap / 2) / 2
        let arrows = KeyboardLayout.arrows
        return VStack(spacing: gap / 2) {
            HStack(spacing: gap) {
                Color.clear.frame(width: unit, height: half)
                cap(arrows.up, height: half)
                Color.clear.frame(width: unit, height: half)
            }
            HStack(spacing: gap) {
                cap(arrows.left, height: half)
                cap(arrows.down, height: half)
                cap(arrows.right, height: half)
            }
        }
    }
}

struct KeyCapView: View {
    let key: KeyCap
    let isWiped: Bool
    let isHeld: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        ZStack {
            shape.fill(fillColor)

            if !key.caution {
                DustSpecks(seed: key.seed)
                    .clipShape(shape)
                    .opacity(isWiped ? 0 : 1)
            }

            if key.caution {
                shape.strokeBorder(Theme.amber, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            } else if isWiped || isHeld {
                shape.strokeBorder(Theme.emerald.opacity(0.85), lineWidth: 1.5)
            } else {
                shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }

            label.foregroundStyle(labelColor)
        }
        .shadow(color: Theme.emerald.opacity(isHeld ? 0.6 : 0), radius: 8)
        .scaleEffect(isHeld ? 0.93 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHeld)
        .animation(.easeOut(duration: 0.45), value: isWiped)
    }

    @ViewBuilder private var label: some View {
        if let symbol = key.symbol {
            VStack(spacing: 1) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .medium))
                if !key.label.isEmpty {
                    Text(key.label)
                        .font(Theme.sans(7.5, .medium))
                }
            }
        } else if !key.label.isEmpty {
            Text(key.label)
                .font(key.label.count == 1 ? Theme.sans(13, .semibold) : Theme.sans(9.5, .medium))
        }
    }

    private var fillColor: Color {
        if key.caution { return Theme.amber.opacity(0.08) }
        if isHeld { return Theme.emerald }
        return isWiped ? Theme.emerald.opacity(0.2) : Color.white.opacity(0.07)
    }

    private var labelColor: Color {
        if key.caution { return Theme.amber }
        if isHeld { return Theme.forest }
        return isWiped ? Color.white : Color.white.opacity(0.42)
    }
}

/// A few pale specks that make untouched keys look like they need a wipe.
struct DustSpecks: View {
    let seed: Int

    var body: some View {
        Canvas { context, size in
            guard size.width > 10, size.height > 8 else { return }
            var rng = SeededGenerator(seed: UInt64(truncatingIfNeeded: seed))
            for _ in 0..<6 {
                let d = CGFloat.random(in: 1.2...2.6, using: &rng)
                let x = CGFloat.random(in: 3...(size.width - 5), using: &rng)
                let y = CGFloat.random(in: 3...(size.height - 5), using: &rng)
                let alpha = Double.random(in: 0.2...0.45, using: &rng)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)),
                             with: .color(Color.white.opacity(alpha)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// SplitMix64, so each key's dust stays in the same place between redraws.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Status

struct LockBadge: View {
    let locksTrackpad: Bool

    var body: some View {
        Label(locksTrackpad ? "Keyboard and trackpad locked" : "Keyboard locked", systemImage: "lock.fill")
            .font(Theme.sans(13, .semibold))
            .foregroundStyle(Theme.emerald)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(Theme.emerald.opacity(0.14)))
            .overlay(Capsule().strokeBorder(Theme.emerald.opacity(0.35)))
    }
}

struct ProgressLine: View {
    let presses: Int
    let wiped: Int
    let total: Int

    var body: some View {
        Text(message)
            .font(Theme.sans(15, .medium))
            .monospacedDigit()
            .foregroundStyle(Theme.textSoft)
    }

    private var message: String {
        let caught = presses == 1 ? "1 press caught" : "\(presses) presses caught"
        if wiped >= total { return "Every key touched. \(caught)." }
        return "\(wiped) of \(total) keys wiped, \(caught)."
    }
}

// MARK: - Finishing

struct UnlockControls: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            if model.sessionLocksTrackpad {
                if let end = model.endDate {
                    CountdownRing(endDate: end, total: model.sessionDuration)
                    Text("Unlocks by itself")
                        .font(Theme.sans(13, .medium))
                        .foregroundStyle(Theme.textSoft)
                }
            } else {
                HoldToUnlockButton {
                    model.requestUnlock()
                }
                .padding(.top, 8)
                Text("Press and hold to finish")
                    .font(Theme.sans(13, .medium))
                    .foregroundStyle(Theme.textSoft)
                if let end = model.endDate {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("or wait \(TimeFormat.clock(end.timeIntervalSince(context.date)))")
                            .font(Theme.sans(12))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textFaint)
                    }
                }
            }
        }
    }
}

/// Press and hold (not click), so a stray palm on the trackpad can't end clean mode early.
struct HoldToUnlockButton: View {
    let holdDuration: Double
    let action: () -> Void

    @State private var progress: CGFloat = 0
    @State private var isPressing = false

    init(holdDuration: Double = 1.0, action: @escaping () -> Void) {
        self.holdDuration = holdDuration
        self.action = action
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 5)
                .padding(-12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(-12)
            RoundButtonFace(hovering: isPressing, showsRing: false)
            Image(systemName: isPressing ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.white)
        }
        .frame(width: 100, height: 100)
        .scaleEffect(isPressing ? 0.96 : 1)
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: holdDuration, maximumDistance: 40) {
            action()
        } onPressingChanged: { pressing in
            isPressing = pressing
            if pressing {
                withAnimation(.linear(duration: holdDuration)) { progress = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
            }
        }
    }
}

struct CountdownRing: View {
    let endDate: Date
    let total: TimeInterval

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remaining = max(0, endDate.timeIntervalSince(context.date))
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(remaining / max(total, 1)))
                    .stroke(Theme.actionGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(TimeFormat.clock(remaining))
                    .font(Theme.sans(22, .semibold))
                    .monospacedDigit()
            }
            .frame(width: 100, height: 100)
        }
    }
}
