import AppKit
import ApplicationServices
import SwiftUI

struct UninstallPlan {
    let appCopies: [URL]
    let supportFiles: [URL]
    let sourceFolder: URL?

    /// Folders like Downloads are protected by macOS, which may ask before KCleaner can move them.
    var sourceFolderMayPrompt: Bool {
        guard let path = sourceFolder?.standardizedFileURL.path else { return false }
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        return ["Desktop", "Documents", "Downloads"].contains { path.hasPrefix(home + "/" + $0) }
    }
}

struct UninstallReport {
    var removed: [String] = []
    var problems: [String] = []
    var needsSettings = false
}

enum UninstallStage {
    case confirm(UninstallPlan)
    case working
    case done(UninstallReport)
}

/// Removes KCleaner and everything related to it.
///
/// KCleaner never writes files itself, but macOS can create a few for any app it runs
/// (a preferences file, saved window state, caches, crash reports). Those are included.
/// Everything is moved to the Trash rather than deleted outright, so nothing is gone for
/// good until the Trash is emptied. Only files that clearly belong to KCleaner are touched.
enum Uninstaller {
    static let bundleID = Bundle.main.bundleIdentifier ?? "com.engagetal.kcleaner"

    static func makePlan() -> UninstallPlan {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library")

        // The running app, plus any other installed copy that really is KCleaner (same bundle ID).
        var copies = [Bundle.main.bundleURL]
        let appFileName = "\(Brand.appName).app"
        for place in [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")] {
            let candidate = place.appendingPathComponent(appFileName)
            guard candidate.standardizedFileURL != Bundle.main.bundleURL.standardizedFileURL,
                  fm.fileExists(atPath: candidate.path),
                  Bundle(url: candidate)?.bundleIdentifier == bundleID else { continue }
            copies.append(candidate)
        }

        // Places macOS may have created files for this app. Most won't exist.
        var candidates: [URL] = [
            library.appendingPathComponent("Preferences/\(bundleID).plist"),
            library.appendingPathComponent("Saved Application State/\(bundleID).savedState"),
            library.appendingPathComponent("Caches/\(bundleID)"),
            library.appendingPathComponent("HTTPStorages/\(bundleID)"),
            library.appendingPathComponent("Application Support/\(Brand.appName)"),
            library.appendingPathComponent("Application Support/\(bundleID)"),
            library.appendingPathComponent("Logs/\(Brand.appName)"),
        ]
        let crashReports = library.appendingPathComponent("Logs/DiagnosticReports")
        if let names = try? fm.contentsOfDirectory(atPath: crashReports.path) {
            candidates += names
                .filter { $0.hasPrefix(Brand.appName + "-") || $0.hasPrefix(Brand.appName + "_") }
                .map { crashReports.appendingPathComponent($0) }
        }

        return UninstallPlan(
            appCopies: copies,
            supportFiles: candidates.filter { fm.fileExists(atPath: $0.path) },
            sourceFolder: recordedSourceFolder
        )
    }

    static func run(_ plan: UninstallPlan, includeSourceFolder: Bool) -> UninstallReport {
        var report = UninstallReport()
        let fm = FileManager.default
        let hadPermissions = AXIsProcessTrusted() || CGPreflightListenEventAccess()

        // 1. Settings macOS keeps for the app, if any.
        UserDefaults.standard.removePersistentDomain(forName: bundleID)

        // 2. Leftover files.
        var movedLeftovers = 0
        for url in plan.supportFiles where fm.fileExists(atPath: url.path) {
            if moveToTrash(url) {
                movedLeftovers += 1
            } else {
                report.problems.append("Couldn't move \(display(url)) to the Trash. You can drag it there yourself.")
            }
        }
        if movedLeftovers > 0 {
            report.removed.append(movedLeftovers == 1 ? "1 leftover file" : "\(movedLeftovers) leftover files")
        }

        // 3. The app itself, and any other copies.
        for (index, url) in plan.appCopies.enumerated() where fm.fileExists(atPath: url.path) {
            if moveToTrash(url) {
                report.removed.append(index == 0 ? "The \(Brand.appName) app" : "Another copy of the app, in \(display(url.deletingLastPathComponent()))")
            } else {
                report.problems.append("Couldn't move the app at \(display(url)) to the Trash. Please drag it there yourself.")
            }
        }

        // 4. The downloaded folder (if chosen), or at least the copy of the app built inside it.
        //    Only touched if it still looks exactly like KCleaner's folder.
        if let folder = plan.sourceFolder, looksLikeKCleanerFolder(folder) {
            if includeSourceFolder {
                if moveToTrash(folder) {
                    report.removed.append("The \(Brand.appName) folder you downloaded")
                } else {
                    report.problems.append("Couldn't move \(display(folder)) to the Trash. You can drag it there yourself.")
                }
            } else {
                let buildFolder = folder.appendingPathComponent("build")
                if fm.fileExists(atPath: buildFolder.path) {
                    if moveToTrash(buildFolder) {
                        report.removed.append("The copy of the app built inside the \(Brand.appName) folder")
                    } else {
                        report.problems.append("Couldn't move \(display(buildFolder)) to the Trash. You can drag it there yourself.")
                    }
                }
            }
        }

        // 5. Privacy permissions, last, so any folder access macOS granted during step 4 is cleared too.
        if resetAllPermissions() {
            report.removed.append("Its privacy permissions (Accessibility, Input Monitoring and any folder access)")
        } else if hadPermissions {
            report.problems.append("Couldn't clear its permissions automatically. In System Settings > Privacy & Security, select \(Brand.appName) under Accessibility and Input Monitoring and remove it with the minus (–) button.")
            report.needsSettings = true
        }

        return report
    }

    static func display(_ url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }

    // MARK: Helpers

    /// build.sh records the folder the app was built from, so it can be offered for removal.
    private static var recordedSourceFolder: URL? {
        guard let path = Bundle.main.object(forInfoDictionaryKey: "KCSourceFolder") as? String,
              !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// A last check before moving a whole folder: it must still contain KCleaner's own files.
    private static func looksLikeKCleanerFolder(_ folder: URL) -> Bool {
        let fm = FileManager.default
        let path = folder.standardizedFileURL.path
        let home = fm.homeDirectoryForCurrentUser.standardizedFileURL.path
        guard path != "/", path != home else { return false }
        let markers = ["build.sh", "Info.plist", "Sources/InputBlocker.swift", "Sources/EmergencyExit.swift", "Sources/Brand.swift"]
        return markers.allSatisfy { fm.fileExists(atPath: folder.appendingPathComponent($0).path) }
    }

    private static func moveToTrash(_ url: URL) -> Bool {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return true
        } catch {
            return false
        }
    }

    /// Uses macOS's own `tccutil` to forget every privacy permission given to KCleaner.
    private static func resetAllPermissions() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "All", bundleID]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

// MARK: - Uninstall screens

struct UninstallPanel: View {
    let stage: UninstallStage

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
            content
                .padding(26)
                .frame(width: 580, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.forest))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline))
                .shadow(color: Color.black.opacity(0.5), radius: 40, y: 14)
        }
    }

    @ViewBuilder private var content: some View {
        switch stage {
        case .confirm(let plan):
            ConfirmUninstallView(plan: plan)
        case .working:
            HStack(spacing: 14) {
                ProgressView()
                    .controlSize(.small)
                Text("Removing \(Brand.appName)…")
                    .font(Theme.sans(15, .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 80)
        case .done(let report):
            UninstallDoneView(report: report)
        }
    }
}

struct ConfirmUninstallView: View {
    @EnvironmentObject var model: AppModel
    let plan: UninstallPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeader(
                symbol: "trash.fill",
                colors: [Theme.orange, Theme.danger],
                title: "Uninstall \(Brand.appName)?",
                subtitle: "Everything below moves to the Trash, so you can change your mind until you empty it."
            )

            VStack(alignment: .leading, spacing: 14) {
                UninstallLine(
                    symbol: "app",
                    title: plan.appCopies.count == 1
                        ? "The \(Brand.appName) app"
                        : "The \(Brand.appName) app (\(plan.appCopies.count) copies)",
                    details: plan.appCopies.map(Uninstaller.display)
                )
                UninstallLine(
                    symbol: "doc.on.doc",
                    title: plan.supportFiles.isEmpty
                        ? "Leftover files: none found"
                        : "Leftover files macOS made for \(Brand.appName)",
                    details: plan.supportFiles.map(Uninstaller.display)
                )
                UninstallLine(
                    symbol: "hand.raised",
                    title: "Its privacy permissions",
                    details: ["Accessibility, Input Monitoring and any folder access, cleared in System Settings"]
                )
                if let folder = plan.sourceFolder {
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(height: 1)
                    Toggle(isOn: $model.removeSourceFolder) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Also remove the \(Brand.appName) folder you downloaded")
                                .font(Theme.sans(13, .semibold))
                            Text(Uninstaller.display(folder))
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.textFaint)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("The copy of the app built inside it is removed either way.")
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()

            if plan.sourceFolderMayPrompt {
                Label("macOS may ask to let \(Brand.appName) reach that folder. Click OK so it can be moved to the Trash.",
                      systemImage: "info.circle")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") {
                    model.cancelUninstall()
                }
                .buttonStyle(PillButtonStyle())
                .keyboardShortcut(.cancelAction)

                Button("Uninstall") {
                    model.performUninstall(plan)
                }
                .buttonStyle(FilledPillStyle(colors: [Theme.orange, Theme.danger]))
            }
        }
    }
}

struct UninstallDoneView: View {
    let report: UninstallReport

    var body: some View {
        let clean = report.problems.isEmpty
        VStack(alignment: .leading, spacing: 18) {
            PanelHeader(
                symbol: clean ? "checkmark" : "exclamationmark",
                colors: clean ? [Theme.emerald, Theme.teal] : [Theme.amber, Theme.orange],
                title: clean ? "\(Brand.appName) is uninstalled" : "\(Brand.appName) is almost uninstalled",
                subtitle: clean
                    ? "Everything has been moved to the Trash. Empty the Trash whenever you're ready."
                    : "A few things need a hand from you. They're listed below."
            )

            if !report.removed.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(report.removed, id: \.self) { item in
                        Label {
                            Text(item)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.emerald)
                        }
                        .font(Theme.sans(12, .medium))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
            }

            if !report.problems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(report.problems, id: \.self) { problem in
                        Label(problem, systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.sans(12, .medium))
                            .foregroundStyle(Theme.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Text("If you kept \(Brand.appName) in your Dock, drag its icon out. You can also delete \(Brand.appName).zip from your Downloads folder.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                if report.needsSettings {
                    Button("Open Privacy Settings") {
                        Permissions.openAccessibilitySettings()
                    }
                    .buttonStyle(PillButtonStyle())
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(FilledPillStyle(colors: [Theme.emerald, Theme.teal]))
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

struct PanelHeader: View {
    let symbol: String
    let colors: [Color]
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.sans(20, .bold))
                Text(subtitle)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct UninstallLine: View {
    let symbol: String
    let title: String
    let details: [String]

    var body: some View {
        let shown = Array(details.prefix(4))
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.emerald)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.sans(13, .semibold))
                ForEach(shown, id: \.self) { detail in
                    Text(detail)
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.textFaint)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if details.count > shown.count {
                    Text("and \(details.count - shown.count) more")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct FilledPillStyle: ButtonStyle {
    let colors: [Color]

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.sans(13, .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.25)))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Capsule())
    }
}
