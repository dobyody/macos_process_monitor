import Foundation
import Combine
import AppKit

/// Holds the latest scan results and refreshes them on a timer.
@MainActor
final class MonitorStore: ObservableObject {
    static let shared = MonitorStore()

    @Published private(set) var groups: [ProjectGroup] = []
    @Published private(set) var totalCount = 0
    @Published private(set) var lastUpdated: Date?

    private var timer: Timer?
    private var refreshing = false

    func start() {
        refresh()
        scheduleTimer()
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in MonitorStore.shared.scheduleTimer() }
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: AppSettings.refreshInterval, repeats: true) { _ in
            Task { @MainActor in MonitorStore.shared.refresh() }
        }
    }

    func refresh() {
        guard !refreshing else { return }
        refreshing = true
        let extra = AppSettings.extraPatterns
        let hide = AppSettings.hideNoProject
        Task.detached(priority: .background) {
            let processes = ProcessScanner.scan(extraPatterns: extra, hideNoProject: hide)
            await MainActor.run {
                self.groups = makeGroups(processes)
                self.totalCount = processes.count
                self.lastUpdated = Date()
                self.refreshing = false
            }
        }
    }

    func kill(_ pid: pid_t, force: Bool) {
        Darwin.kill(pid, force ? SIGKILL : SIGTERM)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.refresh()
        }
    }

    func copyCommand(_ process: DevProcess) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(process.command, forType: .string)
    }

    func openProjectFolder(_ process: DevProcess) {
        guard !process.projectPath.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: process.projectPath))
    }

    /// Realistic sample data for the screenshot mode (`--shot`).
    func loadSampleData() {
        func proc(_ name: String, _ command: String, cpu: Double, mem: Double,
                  up: Int, ports: [Int] = [], project: String, path: String) -> DevProcess {
            DevProcess(pid: Int32.random(in: 10_000...99_999), name: name, command: command,
                       cpuPercent: cpu, memoryMB: mem, uptimeSeconds: up,
                       project: project, projectPath: path, ports: ports)
        }

        let cms = "/Users/gheorghe/Desktop/LID/directus/cms"
        let kaggle = "/Users/gheorghe/Desktop/DEV PROJECTS/kaggle"
        let p2p = "/Users/gheorghe/Desktop/DEV PROJECTS/p2p pbl"
        let bot = "/Users/gheorghe/Desktop/DEV PROJECTS/CrazyBot"

        let all = [
            proc("npm run dev", "npm run dev", cpu: 0.4, mem: 3.9, up: 5 * 3600 + 22 * 60, project: "cms", path: cms),
            proc("next", "node /Users/gheorghe/Desktop/LID/directus/cms/node_modules/.bin/next dev", cpu: 1.8, mem: 214.3, up: 5 * 3600 + 22 * 60, project: "cms", path: cms),
            proc("next-server (v16.3.3)", "next-server (v16.3.3)", cpu: 4.1, mem: 486.2, up: 5 * 3600 + 21 * 60, ports: [3000], project: "cms", path: cms),
            proc("train.py", "python train.py --epochs 50 --model xgboost", cpu: 87.3, mem: 1842.0, up: 2 * 3600 + 3 * 60, project: "kaggle", path: kaggle),
            proc("vite", "node /Users/gheorghe/Desktop/DEV PROJECTS/p2p pbl/node_modules/.bin/vite", cpu: 2.2, mem: 156.8, up: 47 * 60, ports: [5173], project: "p2p pbl", path: p2p),
            proc("node", "node server/index.js", cpu: 0.6, mem: 68.4, up: 26 * 3600, ports: [8080], project: "p2p pbl", path: p2p),
            proc("main.py", "python main.py --poll", cpu: 0.9, mem: 42.1, up: 9 * 3600 + 12 * 60, project: "CrazyBot", path: bot),
            proc("com.docker.backend", "/Applications/Docker.app/Contents/MacOS/com.docker.backend services", cpu: 1.4, mem: 107.0, up: 6 * 3600 + 15 * 60, ports: [5433], project: noProjectName, path: ""),
            proc("redis-server", "redis-server --port 6379", cpu: 0.2, mem: 12.6, up: 6 * 3600 + 14 * 60, ports: [6379], project: noProjectName, path: ""),
        ]

        groups = makeGroups(all)
        totalCount = all.count
        lastUpdated = Date()
    }
}
