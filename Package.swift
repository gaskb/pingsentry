// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PingSentry",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "PingSentry"
        ),
    ],
    swiftLanguageModes: [.v6]
)
