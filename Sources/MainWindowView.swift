import AppKit
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case clean, guide, safety, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clean: return "Clean keyboard"
        case .guide: return "How to use"
        case .safety: return "Safety & privacy"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .clean: return "sparkles"
        case .guide: return "book.fill"
        case .safety: return "lock.shield.fill"
        case .about: return "info.circle.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .clean: return [Theme.emerald, Theme.teal]
        case .guide: return [Theme.sky, Theme.royal]
        case .safety: return [Theme.amber, Theme.orange]
        case .about: return [Theme.violet, Theme.grape]
        }
    }
}

struct MainWindowView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 228)
            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1)
            Group {
                switch model.section {
                case .clean: CleanPage()
                case .guide: GuidePage()
                case .safety: SafetyPage()
                case .about: AboutPage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 940, height: 640)
        .background(BrandBackground())
        .foregroundStyle(Theme.text)
        .overlay {
            if let stage = model.uninstallStage {
                UninstallPanel(stage: stage)
            }
        }
        .overlay {
            if let start = model.emergencyHoldStart {
                ZStack {
                    Color.black.opacity(0.35)
                    EmergencyHUD(start: start)
                }
            }
        }
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: AppIcon.image)
                    .resizable()
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(Brand.appName)
                        .font(Theme.sans(16, .bold))
                    Text(Brand.fullName)
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            .padding(.top, 52)
            .padding(.horizontal, 18)
            .padding(.bottom, 26)

            VStack(spacing: 4) {
                ForEach(AppSection.allCases) { section in
                    SidebarRow(section: section, selected: model.section == section) {
                        model.section = section
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            VStack(alignment: .leading, spacing: 7) {
                Text("Made by")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.textFaint)
                EngagetalMark(size: 13)
            }
            .padding(18)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.black.opacity(0.22))
    }
}

struct SidebarRow: View {
    let section: AppSection
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(LinearGradient(colors: section.colors,
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                Text(section.title)
                    .font(Theme.sans(13, selected ? .semibold : .medium))
                    .foregroundStyle(selected ? Theme.text : Theme.textSoft)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(selected ? 0.12 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Clean keyboard

struct CleanPage: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            HeroArt()
            VStack(spacing: 0) {
                Text("Clean your keyboard,")
                    .font(Theme.sans(28, .bold))
                Text("without typing a thing.")
                    .font(Theme.serifItalic(28))
                    .foregroundStyle(Theme.emerald)
            }
            .padding(.top, 6)
            Text("\(Brand.appName) pauses every key while you wipe, so nothing you press types, clicks or opens anything.")
                .font(Theme.sans(14))
                .foregroundStyle(Theme.textSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
                .padding(.top, 10)

            Group {
                if model.hasPermission {
                    OptionsBar()
                } else {
                    PermissionBanner()
                }
            }
            .padding(.top, 20)

            Spacer(minLength: 18)

            RoundActionButton(model.hasPermission ? "Start" : "Allow") {
                model.start()
            }
            .disabled(model.uninstallStage != nil)

            StatusLine()
                .padding(.top, 22)
            EmergencyHint()
                .padding(.top, 10)
            Spacer(minLength: 18)
        }
        .padding(.horizontal, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OptionsBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "hand.point.up.left.fill")
                    .foregroundStyle(Theme.emerald)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Lock trackpad too")
                        .font(Theme.sans(13, .semibold))
                    Text("To wipe the palm rest")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.textFaint)
                }
                Toggle("Lock trackpad too", isOn: $model.lockTrackpad)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Theme.jade)
            }

            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1, height: 34)

            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .foregroundStyle(Theme.emerald)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Finish")
                        .font(Theme.sans(13, .semibold))
                    Text(model.lockTrackpad ? "Timer needed" : "By hand or timer")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.textFaint)
                }
                Picker("Finish", selection: $model.timerChoice) {
                    ForEach(model.availableTimerChoices) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 124)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassCard()
    }
}

struct PermissionBanner: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("One quick step first")
                    .font(Theme.sans(13, .semibold))
                Text("Switch on \(Brand.appName) under Privacy & Security > Accessibility. You only do this once.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Open Settings") {
                Permissions.requestAccessibility()
                Permissions.openAccessibilitySettings()
            }
            .buttonStyle(PillButtonStyle())
        }
        .padding(14)
        .frame(maxWidth: 540)
        .glassCard()
    }
}

struct StatusLine: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        if let problem = model.problem {
            Label(problem, systemImage: "exclamationmark.triangle.fill")
                .font(Theme.sans(12, .medium))
                .foregroundStyle(Theme.amber)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)
                .fixedSize(horizontal: false, vertical: true)
        } else if let last = model.lastSession {
            Text(last.message)
                .font(Theme.sans(12, .medium))
                .foregroundStyle(last.capsLockFlipped ? Theme.amber : Theme.emerald)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("Press Return or click Start.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.textFaint)
        }
    }
}

// MARK: - How to use

struct GuidePage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "How to use",
                    accent: "in three steps.",
                    subtitle: "No setup and nothing to learn. If you can press a button, you can clean your keyboard."
                )

                VStack(spacing: 10) {
                    GuideStep(number: 1, symbol: "play.fill",
                              title: "Press Start",
                              text: "Your keyboard stops typing and a cleaning screen covers the display. Want to wipe the trackpad too? Switch on \u{201C}Lock trackpad too\u{201D} before you start.")
                    GuideStep(number: 2, symbol: "hand.wave.fill",
                              title: "Wipe the keys",
                              text: "Use a soft cloth. Each key turns green on screen once you've touched it, so you can see what you've missed.")
                    GuideStep(number: 3, symbol: "hand.tap.fill",
                              title: "Hold the round button to finish",
                              text: "Press and hold it with the trackpad for one second. If you picked a timer, you can also just wait. Your keyboard works again straight away.")
                }

                InfoGroup(title: "If you ever get stuck") {
                    ComboRow()
                    InfoRow(symbol: "touchid",
                            title: "Or press the Touch ID button once",
                            text: "Your Mac locks or sleeps, and clean mode ends at the same moment.")
                    InfoRow(symbol: "timer",
                            title: "Or just wait",
                            text: "Clean mode always ends by itself within 10 minutes, whatever you chose.")
                    InfoRow(symbol: "power",
                            title: "Last resort: restart",
                            text: "Hold the Touch ID button until the screen goes dark, then turn your Mac on again. \(Brand.appName) never opens by itself, so your keyboard works right away. Unsaved work in other apps may be lost.")
                }

                InfoGroup(title: "The first time only") {
                    InfoRow(symbol: "hand.raised.fill",
                            title: "Allow Accessibility access",
                            text: "macOS asks you to switch on \(Brand.appName) in System Settings > Privacy & Security > Accessibility. That permission is what lets it pause the keyboard. You only do this once.")
                }

                InfoGroup(title: "Cleaning tips") {
                    InfoRow(symbol: "drop.fill",
                            title: "Slightly damp, never wet",
                            text: "Use a soft, lint-free cloth lightly dampened with water. Never spray anything directly onto the keyboard.")
                    InfoRow(symbol: "xmark.octagon.fill",
                            title: "Skip harsh cleaners",
                            text: "No bleach, aerosol sprays or abrasives. 70% isopropyl alcohol wipes are fine for the keys and palm rest.")
                    InfoRow(symbol: "wind",
                            title: "Crumbs between keys",
                            text: "A soft brush works well. If you use compressed air, keep the can upright and use short bursts.")
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 50)
            .padding(.bottom, 32)
        }
    }
}

struct GuideStep: View {
    let number: Int
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Text("\(number)")
                .font(Theme.sans(18, .bold))
                .foregroundStyle(Theme.forest)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Theme.actionGradient))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.sans(15, .semibold))
                Text(text)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Theme.emerald.opacity(0.55))
                .frame(width: 40)
        }
        .padding(16)
        .glassCard()
    }
}

struct ComboRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "escape")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.amber)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Hold")
                        .font(Theme.sans(13, .semibold))
                    KeyGlyph("esc")
                    Text("+")
                        .foregroundStyle(Theme.textFaint)
                    KeyGlyph("delete")
                    Text("together for 3 seconds")
                        .font(Theme.sans(13, .semibold))
                }
                Text("Press nothing else while you hold them. \(Brand.appName) unlocks everything and quits. This works at any time, even while the keyboard is locked.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Safety & privacy

struct SafetyPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "Safety & privacy:",
                    accent: "nothing leaves your Mac.",
                    subtitle: "\(Brand.appName) is built so it can't harm your Mac and can't share anything about you."
                )

                InfoGroup(title: "It can't harm your Mac") {
                    InfoRow(symbol: "shippingbox",
                            title: "Nothing gets installed",
                            text: "No drivers, system extensions, background helpers or login items. \(Brand.appName) never asks for your password and never changes system settings.")
                    InfoRow(symbol: "bolt.shield",
                            title: "The lock only exists while the app runs",
                            text: "If \(Brand.appName) quits, crashes or stops responding, macOS removes the lock at once.")
                    InfoRow(symbol: "timer",
                            title: "It always lets go",
                            text: "Clean mode ends by itself within 10 minutes. It also ends if your Mac sleeps, locks or switches user.")
                    InfoRow(symbol: "escape",
                            title: "A way out at any moment",
                            text: "Hold esc + delete for 3 seconds to unlock and quit.")
                    InfoRow(symbol: "arrow.clockwise",
                            title: "A restart always clears it",
                            text: "\(Brand.appName) never opens on its own, so after any restart your keyboard works normally.")
                    InfoRow(symbol: "trash",
                            title: "Easy to remove completely",
                            text: "Choose Uninstall \(Brand.appName)… in the \(Brand.appName) menu. It removes the app, anything macOS created for it, and its permissions.")
                }

                InfoGroup(title: "Your data stays on your Mac") {
                    InfoRow(symbol: "wifi.slash",
                            title: "No internet, ever",
                            text: "\(Brand.appName) contains no networking code at all, so it can't send or receive anything.")
                    InfoRow(symbol: "eye.slash",
                            title: "No tracking",
                            text: "No analytics, telemetry, crash reporting, ads, accounts or update checks.")
                    InfoRow(symbol: "keyboard",
                            title: "It doesn't record what you type",
                            text: "It only notices which key positions you touch, to light up the map, and forgets them when clean mode ends.")
                    InfoRow(symbol: "externaldrive.badge.xmark",
                            title: "Nothing is saved",
                            text: "\(Brand.appName) writes no files, logs or settings to your disk.")
                }

                InfoGroup(title: "Check it yourself") {
                    InfoRow(symbol: "chart.bar.xaxis",
                            title: "Activity Monitor",
                            text: "Open Activity Monitor, choose the Network tab and find \(Brand.appName). It should show zero bytes sent and received.")
                    InfoRow(symbol: "doc.text.magnifyingglass",
                            title: "Read the source",
                            text: "The complete source code comes with the app. Its build script refuses to build if network code is ever added.")
                }

                Text("macOS's own crash and analytics sharing follows your choices in Privacy & Security > Analytics & Improvements, as it does for every app.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)
            .padding(.top, 50)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - About

struct AboutPage: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(nsImage: AppIcon.image)
                    .resizable()
                    .frame(width: 112, height: 112)

                VStack(spacing: 5) {
                    Text(Brand.appName)
                        .font(Theme.sans(30, .bold))
                    Text("\(Brand.fullName), version \(Brand.version)")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.textSoft)
                    Text(Brand.tagline)
                        .font(Theme.serifItalic(17))
                        .foregroundStyle(Theme.emerald)
                        .padding(.top, 4)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Text("Made by")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.textFaint)
                        EngagetalMark(size: 15)
                    }
                    Text(Brand.companyBlurb)
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(height: 1)
                    ContactRow(label: "Company", value: Brand.companyLegal, copyable: false)
                    ContactRow(label: "Website", value: Brand.website)
                    ContactRow(label: "Email", value: Brand.email)
                    ContactRow(label: "Based in", value: Brand.location, copyable: false)
                }
                .padding(20)
                .frame(maxWidth: 540)
                .glassCard()

                Text("Addresses aren't clickable on purpose: \(Brand.appName) never opens a connection, not even to its maker's website. Use Copy and paste them wherever you like.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.textFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 4) {
                    Text(Brand.copyright)
                    Text("Built with Apple's AppKit and SwiftUI. No third-party code.")
                }
                .font(Theme.sans(11))
                .foregroundStyle(Theme.textFaint)
                .multilineTextAlignment(.center)

                Button("Uninstall \(Brand.appName)…") {
                    model.showUninstall()
                }
                .buttonStyle(PillButtonStyle(compact: true))
            }
            .padding(.horizontal, 40)
            .padding(.top, 50)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity)
        }
    }
}

struct ContactRow: View {
    let label: String
    let value: String
    let copyable: Bool
    @State private var copied = false

    init(label: String, value: String, copyable: Bool = true) {
        self.label = label
        self.value = value
        self.copyable = copyable
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(Theme.sans(12))
                .foregroundStyle(Theme.textFaint)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(Theme.sans(13, .medium))
                .textSelection(.enabled)
            Spacer(minLength: 8)
            if copyable {
                Button(copied ? "Copied" : "Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                }
                .buttonStyle(PillButtonStyle(compact: true))
            }
        }
    }
}
