// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PiyoCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "PiyoCore", targets: ["PiyoCore"])
    ],
    targets: [
        .target(
            name: "PiyoCore",
            path: "Sources/PiyoCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PiyoCoreTests",
            dependencies: ["PiyoCore"],
            path: "Tests/PiyoCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
