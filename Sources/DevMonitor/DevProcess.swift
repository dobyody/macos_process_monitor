import Foundation

/// A single tracked developer process.
struct DevProcess: Identifiable, Hashable {
    let pid: pid_t
    var name: String          // executable basename, e.g. "node"
    var command: String       // full command line
    var cpuPercent: Double
    var memoryMB: Double
    var uptimeSeconds: Int
    var project: String       // cwd basename, or "(no project)"
    var projectPath: String   // full cwd, empty when unknown
    var ports: [Int]          // listening TCP ports

    var id: pid_t { pid }

    var cpuText: String { String(format: "%.1f%%", cpuPercent) }

    var memText: String {
        memoryMB >= 100 ? String(format: "%.0f MB", memoryMB) : String(format: "%.1f MB", memoryMB)
    }

    var uptimeText: String {
        let s = uptimeSeconds
        if s < 60 { return "\(s)s" }
        let m = s / 60
        if m < 60 { return "\(m)m" }
        let h = m / 60
        if h < 24 { return "\(h)h \(m % 60)m" }
        return "\(h / 24)d \(h % 24)h"
    }

    /// Command line without the executable path, truncated for one-line display.
    var shortCommand: String {
        let tokens = command.split(separator: " ", omittingEmptySubsequences: true)
        let tail = tokens.count > 1 ? tokens.dropFirst().joined(separator: " ") : command
        return tail.count > 72 ? String(tail.prefix(72)) + "…" : tail
    }
}

/// Processes grouped by the project their working directory belongs to.
struct ProjectGroup: Identifiable {
    let name: String
    let path: String
    let processes: [DevProcess]

    var id: String { name }

    var totalMemoryMB: Double { processes.reduce(0) { $0 + $1.memoryMB } }
    var totalCPU: Double { processes.reduce(0) { $0 + $1.cpuPercent } }
}

let noProjectName = "(no project)"

func makeGroups(_ processes: [DevProcess]) -> [ProjectGroup] {
    let dict = Dictionary(grouping: processes, by: \.project)
    return dict
        .map { name, list in
            ProjectGroup(
                name: name,
                path: list.first?.projectPath ?? "",
                processes: list.sorted { $0.cpuPercent > $1.cpuPercent }
            )
        }
        .sorted { a, b in
            if a.name == noProjectName { return false }
            if b.name == noProjectName { return true }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
}
