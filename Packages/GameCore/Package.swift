// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GameCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "GameCore",
            targets: ["GameCore"]
        ),
    ],
    dependencies: [
        .package(path: "../CatanProtocol")
    ],
    targets: [
        .target(
            name: "GameCore",
            dependencies: ["CatanProtocol"],
            path: "Sources/GameCore"
        ),
        .testTarget(
            name: "GameCoreTests",
            dependencies: ["GameCore"],
            path: "Tests/GameCoreTests",
            resources: [
                .copy("GoldenGames")
            ]
        ),
    ]
)
