// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TradeRoadsServer",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.8.0"),
        .package(path: "../Packages/CatanProtocol"),
        .package(path: "../Packages/GameCore"),
    ],
    targets: [
        .executableTarget(
            name: "TradeRoadsServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                "CatanProtocol",
                "GameCore",
            ],
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "TradeRoadsServerTests",
            dependencies: [
                "TradeRoadsServer",
                .product(name: "XCTVapor", package: "vapor"),
            ],
            path: "Tests"
        )
    ]
)

