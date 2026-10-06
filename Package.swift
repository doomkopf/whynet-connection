// swift-tools-version: 6.3.3
import PackageDescription

let package = Package(
    name: "WhynetConnection",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "WhynetConnection",
            targets: ["WhynetConnection"],
        )
    ],
    dependencies: [
        .package(url: "https://github.com/doomkopf/whynet-commons.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.100.0"),
    ],
    targets: [
        .target(
            name: "WhynetConnection",
            dependencies: [
                .product(name: "WhynetCommons", package: "whynet-commons"),
                .product(name: "NIO", package: "swift-nio"),
            ],
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "UnitTests",
            dependencies: ["WhynetConnection"],
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["WhynetConnection"],
            swiftSettings: swiftSettings,
        ),
    ])

var swiftSettings: [SwiftSetting] {
    [
        .enableExperimentalFeature("StrictConcurrency")
    ]
}
