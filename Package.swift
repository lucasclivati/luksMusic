// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "luksMusic",
    platforms: [
        .iOS(.v17)
    ],
    dependencies: [
        .package(url: "https://github.com/AudioKit/AudioKit", from: "5.6.0"),
        .package(url: "https://github.com/AudioKit/Tonic", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "luksMusic",
            dependencies: [
                "AudioKit",
                "Tonic",
            ],
            path: "luksMusic",
            exclude: [
                "Info.plist",
                "Assets.xcassets",
            ],
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
