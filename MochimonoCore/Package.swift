// swift-tools-version: 6.0
import PackageDescription

// UIに一切依存しないロジック層。
// Xcodeを開かなくても `swift test` で回せるようにしてある。
let package = Package(
    name: "MochimonoCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "MochimonoCore", targets: ["MochimonoCore"])
    ],
    targets: [
        .target(name: "MochimonoCore"),
        .testTarget(name: "MochimonoCoreTests", dependencies: ["MochimonoCore"])
    ]
)
