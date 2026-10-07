import SwiftUI

// MARK: - Brand

/// The `</>` brand mark: gradient tile + glyph, drawn with shapes so it
/// scales anywhere (header, empty state) without image assets.
struct LogoMark: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.42, green: 0.36, blue: 0.96),
                             Color(red: 0.61, green: 0.36, blue: 0.96)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            GlyphShape()
                .stroke(style: StrokeStyle(lineWidth: size * 0.085,
                                           lineCap: .round, lineJoin: .round))
                .foregroundStyle(.white)
                .padding(size * 0.24)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.18), radius: size * 0.06, y: size * 0.04)
    }
}

/// `</>` as a single strokeable path.
struct GlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // left chevron
        p.move(to: CGPoint(x: w * 0.34, y: h * 0.30))
        p.addLine(to: CGPoint(x: w * 0.12, y: h * 0.50))
        p.addLine(to: CGPoint(x: w * 0.34, y: h * 0.70))
        // right chevron
        p.move(to: CGPoint(x: w * 0.66, y: h * 0.30))
        p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.50))
        p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.70))
        // slash
        p.move(to: CGPoint(x: w * 0.56, y: h * 0.22))
        p.addLine(to: CGPoint(x: w * 0.44, y: h * 0.78))
        return p
    }
}

/// Stable accent color per project name (djb2 hash → hue).
extension Color {
    static func project(_ name: String) -> Color {
        var hash: UInt64 = 5381
        for scalar in name.unicodeScalars {
            hash = (hash << 5) &+ hash &+ UInt64(scalar.value)
        }
        let hue = Double((hash % 360)) / 360
        return Color(hue: hue, saturation: 0.62, brightness: 0.86)
    }
}

// MARK: - Menu panel

/// The panel shown when clicking the menu bar item.
struct MenuView: View {
    @ObservedObject private var store = MonitorStore.shared
    @State private var query = ""
    @State private var showSettings = false
    @State private var collapsed: Set<String> = []

    var filteredGroups: [ProjectGroup] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return store.groups }
        return store.groups.compactMap { group in
            let groupMatches = group.name.lowercased().contains(q)
                || group.path.lowercased().contains(q)
            let procs = group.processes.filter {
                groupMatches
                    || $0.name.lowercased().contains(q)
                    || $0.command.lowercased().contains(q)
                    || $0.ports.contains { String($0) == q || ":\($0)" == q }
            }
            return procs.isEmpty ? nil : ProjectGroup(name: group.name, path: group.path, processes: procs)
        }
    }

    var body: some View {
        Group {
            if showSettings {
                SettingsView(onDone: { showSettings = false })
            } else {
                mainContent
            }
        }
        .frame(width: 440, height: 520)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.groups.isEmpty {
                emptyState
            } else {
                searchField
                processList
            }
            Divider()
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            LogoMark(size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text("DevMonitor").font(.system(size: 13, weight: .bold))
                Text("\(store.totalCount) processes · \(store.groups.count) projects")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            CircleButton(icon: "arrow.clockwise", help: "Refresh now") { store.refresh() }
            CircleButton(icon: "gearshape", help: "Settings") { showSettings = true }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
            TextField("Filter by name, project, port…", text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var processList: some View {
        List {
            ForEach(filteredGroups) { group in
                Section {
                    if !collapsed.contains(group.name) {
                        ForEach(group.processes) { process in
                            ProcessRow(process: process, tint: .project(group.name))
                                .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 14))
                                .listRowSeparator(.hidden)
                        }
                    }
                } header: {
                    GroupHeader(
                        group: group,
                        isCollapsed: collapsed.contains(group.name)
                    ) {
                        toggleGroup(group.name)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(.easeInOut(duration: 0.18), value: collapsed)
    }

    private func toggleGroup(_ name: String) {
        if collapsed.contains(name) { collapsed.remove(name) } else { collapsed.insert(name) }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            LogoMark(size: 54).opacity(0.9)
            Text("No dev processes detected")
                .font(.system(size: 13, weight: .semibold))
            Text("Node, Python, Go, containers and friends\nwill appear here.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "cpu").font(.system(size: 9))
                Text(totalCPU).monospacedDigit()
            }
            HStack(spacing: 4) {
                Image(systemName: "memorychip").font(.system(size: 9))
                Text(totalMemory).monospacedDigit()
            }
            .help("Total resources used by tracked processes")
            Spacer()
            Text("right-click for actions")
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
            if let updated = store.lastUpdated {
                Text("·  \(updated, style: .time)")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .font(.system(size: 9.5))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private var totalCPU: String {
        let cpu = store.groups.reduce(0.0) { $0 + $1.totalCPU }
        return String(format: "%.1f%%", cpu)
    }

    private var totalMemory: String {
        let mb = store.groups.reduce(0.0) { $0 + $1.totalMemoryMB }
        return mb >= 1024 ? String(format: "%.1f GB", mb / 1024) : String(format: "%.0f MB", mb)
    }
}

// MARK: - Pieces

struct CircleButton: View {
    let icon: String
    let help: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 26, height: 26)
                .background(hovering ? Color.primary.opacity(0.08) : .clear,
                            in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
    }
}

struct GroupHeader: View {
    let group: ProjectGroup
    let isCollapsed: Bool
    let toggle: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .foregroundStyle(.tertiary)
                Circle()
                    .fill(Color.project(group.name))
                    .frame(width: 7, height: 7)
                Text(group.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
                Text("\(group.processes.count)")
                    .font(.system(size: 9, weight: .semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.07), in: Capsule())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f%% · %@", group.totalCPU, formatMem(group.totalMemoryMB)))
                    .font(.system(size: 9.5))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(hovering ? Color.primary.opacity(0.04) : .clear,
                        in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private func formatMem(_ mb: Double) -> String {
        mb >= 1024 ? String(format: "%.1f GB", mb / 1024) : String(format: "%.0f MB", mb)
    }
}

struct ProcessRow: View {
    @ObservedObject private var store = MonitorStore.shared
    let process: DevProcess
    let tint: Color

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint.opacity(hovering ? 1 : 0.55))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(process.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    ForEach(process.ports, id: \.self) { port in
                        Text(":\(port)")
                            .font(.system(size: 9, weight: .bold))
                            .monospacedDigit()
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(tint.opacity(0.16), in: Capsule())
                            .foregroundStyle(tint)
                    }
                }
                Text(process.shortCommand)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 10)
            VStack(alignment: .trailing, spacing: 3) {
                Text(process.cpuText)
                    .font(.system(size: 10.5, weight: .semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(cpuColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(cpuColor)
                Text("\(process.memText) · \(process.uptimeText)")
                    .font(.system(size: 9.5))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(hovering ? Color.primary.opacity(0.045) : .clear,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contextMenu {
            Section(process.name) {
                Button {
                    store.kill(process.pid, force: false)
                } label: {
                    Label("Kill (SIGTERM)", systemImage: "stop.circle")
                }
                Button(role: .destructive) {
                    store.kill(process.pid, force: true)
                } label: {
                    Label("Force Kill (SIGKILL)", systemImage: "xmark.octagon")
                }
                Divider()
                Button {
                    store.copyCommand(process)
                } label: {
                    Label("Copy Full Command", systemImage: "doc.on.doc")
                }
                Button {
                    store.openProjectFolder(process)
                } label: {
                    Label("Open Project Folder", systemImage: "folder")
                }
                .disabled(process.projectPath.isEmpty)
            }
        }
        .onHover { hovering = $0 }
    }

    private var cpuColor: Color {
        if process.cpuPercent >= 50 { return .red }
        if process.cpuPercent >= 10 { return .orange }
        return .green
    }
}
