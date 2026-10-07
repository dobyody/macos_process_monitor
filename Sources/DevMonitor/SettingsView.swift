import SwiftUI
import ServiceManagement

struct SettingsView: View {
    /// Dismissal is driven by the parent (inline navigation inside the
    /// menu bar popover — a .sheet here would steal focus and close it).
    var onDone: () -> Void

    @ObservedObject private var store = MonitorStore.shared

    @AppStorage("refreshInterval") private var refreshInterval = 3.0
    @AppStorage("extraPatterns") private var extraPatterns = ""
    @AppStorage("hideNoProject") private var hideNoProject = false

    @State private var loginItemEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    onDone()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .help("Back")
                Text("Settings").font(.system(size: 13, weight: .bold))
                Spacer()
                Button("Done") { onDone() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    card("Scanning") {
                        LabeledRow(label: "Refresh interval") {
                            Picker("", selection: $refreshInterval) {
                                ForEach([2.0, 3.0, 5.0, 10.0, 30.0], id: \.self) { s in
                                    Text("\(Int(s))s").tag(s)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 210)
                            .onChange(of: refreshInterval) { _ in store.refresh() }
                        }
                        Toggle("Hide processes without a project", isOn: $hideNoProject)
                            .onChange(of: hideNoProject) { _ in store.refresh() }
                            .font(.system(size: 11.5))
                        Text("Tip: hide the noise from Docker Desktop, language servers and other tools that run outside any project folder.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }

                    card("Extra process patterns") {
                        TextField("e.g. mytool*, somedaemon, ssh", text: $extraPatterns)
                            .font(.system(size: 11.5, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { store.refresh() }
                        Text("Comma-separated, * wildcards. Already tracked: node, python*, vite, go, cargo, java, docker, postgres, redis…")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }

                    card("Startup") {
                        Toggle("Launch at login", isOn: Binding(
                            get: { loginItemEnabled },
                            set: { enable in setLoginItem(enable) }
                        ))
                        .font(.system(size: 11.5))
                        if let error = loginItemError {
                            Text(error)
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                        }
                    }

                    HStack(spacing: 8) {
                        LogoMark(size: 14)
                        Text("DevMonitor 1.0 — native menu bar process monitor")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
                .padding(14)
            }
        }
        .frame(width: 440, height: 520)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(.tertiary)
                .kerning(0.6)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func setLoginItem(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemEnabled = enable
            loginItemError = nil
        } catch {
            loginItemError = "Could not \(enable ? "enable" : "disable"): \(error.localizedDescription). Add the app manually in System Settings → General → Login Items."
        }
    }
}

struct LabeledRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack {
            Text(label).font(.system(size: 11.5))
            Spacer()
            content
        }
    }
}
