// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CodexQuotaTouchBar",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CodexQuotaCore", targets: ["CodexQuotaCore"]),
        .executable(name: "CodexQuotaTouchBar", targets: ["CodexQuotaTouchBar"]),
        .executable(name: "codex-quota-cli", targets: ["CodexQuotaCLI"])
    ],
    targets: [
        .target(
            name: "CodexQuotaCore",
            path: "Sources/Core"
        ),
        .executableTarget(
            name: "CodexQuotaTouchBar",
            dependencies: ["CodexQuotaCore"],
            path: "Sources/App"
        ),
        .executableTarget(
            name: "CodexQuotaCLI",
            dependencies: ["CodexQuotaCore"],
            path: "Sources/CLI"
        ),
        .testTarget(
            name: "CodexQuotaCoreTests",
            dependencies: ["CodexQuotaCore"],
            path: "Tests/CodexQuotaCoreTests"
        )
    ]
)
