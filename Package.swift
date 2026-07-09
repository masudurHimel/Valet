// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Valet",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Valet",
            path: "Sources/Valet",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ValetTests",
            dependencies: ["Valet"],
            path: "Tests/ValetTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
