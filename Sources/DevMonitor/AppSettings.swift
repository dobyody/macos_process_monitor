import Foundation

/// UserDefaults-backed settings, editable from the app's Settings sheet.
enum AppSettings {
    static var refreshInterval: TimeInterval {
        let value = UserDefaults.standard.double(forKey: "refreshInterval")
        return (2...30).contains(value) ? value : 3
    }

    static var extraPatterns: [String] {
        let raw = UserDefaults.standard.string(forKey: "extraPatterns") ?? ""
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }

    static var hideNoProject: Bool {
        UserDefaults.standard.bool(forKey: "hideNoProject")
    }
}
