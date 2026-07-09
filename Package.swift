// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Wield",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "Wield",
            path: "Sources/Wield"
        )
    ],
    swiftLanguageModes: [.v5]
)
