// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CatanProtocol",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CatanProtocol",
            targets: ["CatanProtocol"]
        ),
    ],
    targets: [
        .target(
            name: "CatanProtocol",
            path: "Sources/CatanProtocol"
        ),
        .testTarget(
            name: "CatanProtocolTests",
            dependencies: ["CatanProtocol"],
            path: "Tests/CatanProtocolTests",
            resources: [
                .copy("GoldenFiles")
            ]
        ),
    ]
)
