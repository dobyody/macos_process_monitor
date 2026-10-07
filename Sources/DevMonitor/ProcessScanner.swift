import Foundation
import Darwin

/// Scans running processes for known developer tooling and resolves,
/// for each match: project (working directory), CPU, memory, uptime, ports.
enum ProcessScanner {

    /// Executable-name patterns matched with fnmatch (case-insensitive).
    static let defaultPatterns: [String] = [
        // JS / TS
        "node", "npm", "npx", "pnpm", "yarn", "bun", "bunx", "deno",
        "vite", "webpack", "webpack-dev-server", "esbuild", "tsc", "tsx",
        "ts-node", "nodemon", "pm2", "next-server", "turbo", "expo",
        // Python
        "python*", "pip*", "uv", "uvicorn", "gunicorn", "celery", "jupyter*",
        "poetry", "streamlit", "hypercorn",
        // Ruby
        "ruby", "rails", "puma", "sidekiq", "rake",
        // PHP
        "php", "artisan", "composer",
        // Go
        "go", "air", "dlv", "gopls",
        // JVM
        "java", "gradle", "mvn", "sbt", "scala", "kotlin",
        // Rust
        "cargo", "rustc", "rust-analyzer",
        // Containers & services
        "docker", "docker-compose", "dockerd", "containerd", "com.docker*",
        "colima", "podman", "redis-server", "postgres",
        "mysqld", "mongod", "nginx", "caddy",
    ]

    // Remembers total CPU time per pid between scans so we can show
    // instantaneous CPU instead of the lifetime average that ps reports.
    static var lastCPU: [pid_t: (at: TimeInterval, total: UInt64)] = [:]

    static func scan(extraPatterns: [String] = [], hideNoProject: Bool = false) -> [DevProcess] {
        let patterns = (defaultPatterns + extraPatterns).map { $0.lowercased() }
        let uid = getuid()
        let myPid = getpid()
        let home = NSHomeDirectory()

        // 1) Metrics + executable path. comm is the last column so paths
        //    containing spaces still parse correctly.
        guard let commOut = run("/bin/ps", ["-axo", "pid=,uid=,pcpu=,rss=,etime=,comm="]) else {
            return []
        }
        // 2) Full command lines (argv), for display and for processes that
        //    rename themselves (node sets its process title, e.g. MCP servers).
        var argsByPid: [pid_t: String] = [:]
        if let argsOut = run("/bin/ps", ["-axo", "pid=,args="]) {
            for line in argsOut.split(separator: "\n") {
                let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
                guard tokens.count >= 2, let pid = Int32(tokens[0]) else { continue }
                argsByPid[pid] = tokens.dropFirst().joined(separator: " ")
            }
        }

        struct Match {
            let pid: pid_t
            let execPath: String
            let comm: String
            let cpu: Double
            let rssKB: Double
            let etime: String
            let args: String
        }
        var matches: [Match] = []

        for line in commOut.split(separator: "\n") {
            let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
            guard tokens.count >= 6,
                  let pid = Int32(tokens[0]),
                  let ownerUid = Int32(tokens[1]),
                  let cpu = Double(tokens[2]),
                  let rssKB = Double(tokens[3]) else { continue }
            guard ownerUid == uid, pid != myPid else { continue }

            let etime = String(tokens[4])
            let comm = tokens.dropFirst(5).joined(separator: " ")
            let args = argsByPid[pid] ?? ""

            // The kernel-visible exec path. node's process.title rewrites the
            // ps view ("next-server (v16.3.3)"), so match on the real binary
            // and keep the more specific title for display.
            let realExec = realExecutablePath(pid: pid) ?? comm
            let execName = URL(fileURLWithPath: realExec).lastPathComponent.lowercased()
            let commName = (comm.contains("/")
                            ? URL(fileURLWithPath: comm).lastPathComponent
                            : comm).lowercased()

            guard matchesPattern(execName, patterns) || matchesPattern(commName, patterns) else {
                continue
            }
            matches.append(Match(
                pid: pid,
                execPath: realExec,
                comm: comm,
                cpu: cpu,
                rssKB: rssKB,
                etime: etime,
                args: args
            ))
        }

        guard !matches.isEmpty else { return [] }

        // 3) Listening TCP ports for the matched pids.
        var portsByPid: [pid_t: Set<Int>] = [:]
        let pidSet = Set(matches.map(\.pid))
        if let lsofOut = run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpn"]) {
            var currentPid: pid_t?
            for rawLine in lsofOut.split(separator: "\n") {
                let line = String(rawLine)
                if line.hasPrefix("p"), let p = Int32(line.dropFirst()) {
                    currentPid = p
                } else if line.hasPrefix("n"), let p = currentPid,
                          let port = Int(line.split(separator: ":").last ?? "") {
                    if pidSet.contains(p) {
                        portsByPid[p, default: []].insert(port)
                    }
                }
            }
        }

        // 4) Assemble with cwd + instantaneous CPU.
        var result: [DevProcess] = []
        for m in matches {
            let cwd = workingDirectory(pid: m.pid)
            let project = projectFor(cwd: cwd, home: home)
            result.append(DevProcess(
                pid: m.pid,
                name: displayName(comm: m.comm, realExec: m.execPath, args: m.args),
                command: m.args.isEmpty ? m.execPath : m.args,
                cpuPercent: instantCPU(pid: m.pid, fallback: m.cpu),
                memoryMB: m.rssKB / 1024.0,
                uptimeSeconds: parseEtime(m.etime) ?? 0,
                project: project?.name ?? noProjectName,
                projectPath: project?.path ?? "",
                ports: (portsByPid[m.pid] ?? []).sorted()
            ))
        }
        if hideNoProject {
            result.removeAll { $0.project == noProjectName }
        }
        return result
    }

    private static func matchesPattern(_ name: String, _ patterns: [String]) -> Bool {
        guard !name.isEmpty else { return false }
        for pattern in patterns {
            if fnmatch(pattern, name, 0) == 0 { return true }
        }
        return false
    }

    /// Real executable path from the kernel; unlike ps output it is not
    /// affected by process title renaming (node's process.title).
    private static func realExecutablePath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(MAXPATHLEN))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    /// Picks the most informative name: a renamed process title
    /// ("next-server (v16.3.3)"), else the script/tool from the command
    /// line ("vite", "next", "server.js", "http.server"), else the binary.
    private static func displayName(comm: String, realExec: String, args: String) -> String {
        let execBase = URL(fileURLWithPath: realExec).lastPathComponent
        let commBase = comm.contains("/")
            ? URL(fileURLWithPath: comm).lastPathComponent
            : comm
        if !commBase.isEmpty && commBase != execBase {
            return commBase
        }
        var iterator = args.split(separator: " ", omittingEmptySubsequences: true).makeIterator()
        var nextIsModule = false
        while let raw = iterator.next() {
            let token = String(raw)
            if nextIsModule { return token }
            if token == "-m" { nextIsModule = true; continue }
            guard !token.hasPrefix("-") else { continue }
            if token.contains("node_modules/") {
                return URL(fileURLWithPath: token).lastPathComponent
            }
            let lower = token.lowercased()
            if [".js", ".ts", ".tsx", ".mjs", ".cjs", ".py", ".rb"].contains(where: { lower.hasSuffix($0) }) {
                return URL(fileURLWithPath: token).lastPathComponent
            }
        }
        return execBase
    }

    /// Working directory of a process, via the native proc_pidinfo call.
    /// Fast (no subprocess); readable for processes owned by the same user.
    private static func workingDirectory(pid: pid_t) -> String {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        let status = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size)
        guard status == size else { return "" }
        let path = withUnsafePointer(to: info.pvi_cdir.vip_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                String(cString: $0)
            }
        }
        return path.isEmpty ? "/" : path
    }

    /// Maps a cwd to a project name. Returns nil for system paths, the
    /// home directory itself and anything outside a sensible project root.
    private static func projectFor(cwd: String, home: String) -> (name: String, path: String)? {
        guard !cwd.isEmpty, cwd != "/" else { return nil }
        let systemPrefixes = ["/System", "/usr", "/private", "/Applications",
                              "/Library", "/bin", "/sbin", "/opt", "/etc", "/var", "/dev"]
        for prefix in systemPrefixes where cwd == prefix || cwd.hasPrefix(prefix + "/") {
            return nil
        }
        if cwd == home { return nil }
        // Support paths inside the home (~/Library containers, caches, Trash)
        // are not projects either.
        for homePrefix in ["/Library", "/.Trash", "/.cache"] {
            if cwd.hasPrefix(home + homePrefix) { return nil }
        }
        let name = (cwd as NSString).lastPathComponent
        guard !name.isEmpty, name != "/" else { return nil }
        return (name, cwd)
    }

    private static func instantCPU(pid: pid_t, fallback: Double) -> Double {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let status = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
        guard status == size else { return fallback }
        let total = info.pti_total_user + info.pti_total_system
        let now = Date().timeIntervalSinceReferenceDate
        defer { lastCPU[pid] = (now, total) }
        if let previous = lastCPU[pid], now > previous.at, total >= previous.total {
            let wall = now - previous.at
            let cpuSeconds = Double(total - previous.total) / 1_000_000_000.0
            if wall > 0.1 { return min(cpuSeconds / wall * 100, 999) }
        }
        return fallback
    }

    /// ps etime formats: "mm:ss", "hh:mm:ss" or "dd-hh:mm:ss".
    private static func parseEtime(_ raw: String) -> Int? {
        var days = 0
        var rest = raw
        if let dash = raw.firstIndex(of: "-") {
            days = Int(raw[raw.startIndex..<dash]) ?? 0
            rest = String(raw[raw.index(after: dash)...])
        }
        let parts = rest.split(separator: ":").compactMap { Int($0) }
        guard !parts.isEmpty else { return nil }
        switch parts.count {
        case 3: return days * 86400 + parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return days * 86400 + parts[0] * 60 + parts[1]
        default: return days * 86400 + parts[0]
        }
    }

    @discardableResult
    private static func run(_ path: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return nil
        }
        // Keep lsof from blocking on a dead pipe if it writes to stderr.
        _ = try? stderr.fileHandleForReading.readToEnd()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
