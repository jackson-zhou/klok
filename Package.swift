// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Klok",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Klok",
            path: "Sources/Klok"
        )
    ]
)
