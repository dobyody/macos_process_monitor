import SwiftUI
import AppKit

/// `DevMonitor --shot <main|settings> <light|dark>`: opens the UI in a real
/// window with sample data and prints "WINDOW <id>" so a shell script can
/// capture it with `screencapture -l<id>`. Blocks until killed.
@MainActor
enum ShotMode {
    static func run(kind: String, appearance: String) {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)

        MonitorStore.shared.loadSampleData()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.center()
        window.hasShadow = true
        window.backgroundColor = .windowBackgroundColor

        let content: AnyView
        if kind == "settings" {
            content = AnyView(SettingsView(onDone: {}))
        } else {
            content = AnyView(MenuView())
        }
        window.contentView = NSHostingView(rootView: content)
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)

        FileHandle.standardOutput.write(Data("WINDOW \(window.windowNumber)\n".utf8))
        app.run()
    }
}
