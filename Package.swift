// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PingSentry",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "PingSentry",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PingSentryTests",
            dependencies: ["PingSentry"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
