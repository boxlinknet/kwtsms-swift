// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "KwtSMS",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "KwtSMS",
            targets: ["KwtSMS"]
        )
    ],
    targets: [
        .target(
            name: "KwtSMS",
            path: "Sources/KwtSMS"
        ),
        .testTarget(
            name: "KwtSMSTests",
            dependencies: ["KwtSMS"],
            path: "Tests/KwtSMSTests"
        )
    ]
)
