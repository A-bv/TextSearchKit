// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TextSearchKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "TextSearchKit", targets: ["TextSearchKit"]),
    ],
    targets: [
        .target(
            name: "TextSearchKit",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "TextSearchKitTests", dependencies: ["TextSearchKit"]),
    ]
)
