import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MonitorStore.shared.start()
    }
}

@main
struct DevMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let args = CommandLine.arguments
        if args.contains("--scan") {
            ScanMode.run()
            exit(0)
        }
        if let index = args.firstIndex(of: "--shot"), args.count > index + 2 {
            MainActor.assumeIsolated {
                ShotMode.run(kind: args[index + 1], appearance: args[index + 2])
            }
            exit(0)
        }
        // Menu-bar-only app: no Dock icon, no menu bar takeover.
        NSApplication.shared.setActivationPolicy(.accessory)
        quitIfAlreadyRunning()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(MonitorStore.shared)
        } label: {
            StatusBarLabel()
        }
        .menuBarExtraStyle(.window)
    }

    private func quitIfAlreadyRunning() {
        let bundleId = Bundle.main.bundleIdentifier ?? "dev.local.DevMonitor"
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .filter { $0.processIdentifier != getpid() }
        if let existing = others.first {
            FileHandle.standardError.write(
                Data("DevMonitor is already running (pid \(existing.processIdentifier)); exiting.\n".utf8)
            )
            exit(0)
        }
    }
}

/// The menu bar item: code icon + live process count.
struct StatusBarLabel: View {
    @ObservedObject private var store = MonitorStore.shared

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
            Text("\(store.totalCount)")
                .monospacedDigit()
        }
    }
}
