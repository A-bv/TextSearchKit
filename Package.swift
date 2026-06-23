// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TextSearchKit",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "TextSearchKit", targets: ["TextSearchKit"]),
    ],
    targets: [
        .target(name: "TextSearchKit"),
        .testTarget(name: "TextSearchKitTests", dependencies: ["TextSearchKit"]),
    ]
)
