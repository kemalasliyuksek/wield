// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Wield",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "Wield",
            path: "Sources/Wield"
        )
    ],
    swiftLanguageModes: [.v5]
)
