// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClueEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ClueEngine", targets: ["ClueEngine"]),
    ],
    targets: [
        .target(name: "ClueEngine"),
        .testTarget(name: "ClueEngineTests", dependencies: ["ClueEngine"]),
    ]
)
