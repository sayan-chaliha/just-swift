// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "just-swift",
    platforms: [.macOS(.v11)],
    products: [
        .executable(name: "just", targets: ["Just"]),
        .library(name: "JustSwift", type: .static, targets: ["JustSwift"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.0.1"),
        .package(url: "https://github.com/realm/SwiftLint", from: "0.46.2"),
        .package(url: "https://github.com/apple/swift-markdown", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "JustSwift",
            dependencies: [
                "Rainbow",
                .product(name: "SwiftLintFramework", package: "SwiftLint"),
                .product(name: "Markdown", package: "swift-markdown")
            ],
            resources: [
                .copy("Resources/swiftlint.yml"),
            ]),
        .executableTarget(
            name: "Just",
            dependencies: ["JustSwift"]),
        .testTarget(
            name: "JustSwiftTests",
            dependencies: ["JustSwift"]),
    ]
)
