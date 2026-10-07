import Foundation

/// `DevMonitor --scan`: prints the detection table to the terminal and exits.
/// Used for testing the scanner without the GUI.
enum ScanMode {
    static func run() {
        let processes = ProcessScanner.scan(
            extraPatterns: AppSettings.extraPatterns,
            hideNoProject: false
        )
        let groups = makeGroups(processes)
        guard !groups.isEmpty else {
            print("DevMonitor: no dev processes detected.")
            return
        }
        print("DevMonitor scan — \(processes.count) processes in \(groups.count) projects\n")
        for group in groups {
            let location = group.path.isEmpty ? "" : "  —  \(group.path)"
            print("▸ \(group.name) (\(group.processes.count))\(location)")
            for p in group.processes {
                let ports = p.ports.isEmpty ? "" : "  ports: " + p.ports.map { ":\($0)" }.joined(separator: " ")
                print("  pid \(pad(String(p.pid), 7)) \(pad(p.name, 16)) \(pad(p.cpuText, 7)) \(pad(p.memText, 10)) \(pad(p.uptimeText, 8))\(ports)")
                print("      \(p.command)")
            }
            print()
        }
    }

    private static func pad(_ s: String, _ width: Int) -> String {
        s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
    }
}
