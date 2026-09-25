// swift-tools-version: 5.9
import PackageDescription

// Swift 5 言語モードで動かす（tools-version 5.9 の既定）。
// Swift 6 の厳格な並行性チェックへ移行する場合は tools-version を 6.0 に上げ、
// 各ターゲットに .swiftLanguageMode(.v6) を指定してください。
let package = Package(
    name: "PiyoCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // 複数ターゲットからリンクするときに重複が気になる場合は
        // `type: .dynamic` を指定してください。
        .library(name: "PiyoCore", targets: ["PiyoCore"])
    ],
    targets: [
        .target(
            name: "PiyoCore",
            path: "Sources/PiyoCore"
        ),
        .testTarget(
            name: "PiyoCoreTests",
            dependencies: ["PiyoCore"],
            path: "Tests/PiyoCoreTests"
        )
    ]
)
