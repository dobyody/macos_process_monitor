// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DevMonitor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DevMonitor",
            path: "Sources/DevMonitor"
        )
    ]
)
