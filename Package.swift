// swift-tools-version:5.10
import PackageDescription

let package:Package = .init(
    name: "swift-json",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "JSON", targets: ["JSON"]),
        .library(name: "JSONAST", targets: ["JSONAST"]),
        .library(name: "JSONLegacy", targets: ["JSONLegacy"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tayloraswift/swift-grammar", .upToNextMinor(
            from: "0.4.0")),
    ],
    targets: [
        .target(name: "JSONAST"),

        .target(name: "JSONDecoding",
            dependencies: [
                .target(name: "JSONAST"),
                .product(name: "Grammar", package: "swift-grammar"),
            ]),

        .target(name: "JSONEncoding",
            dependencies: [
                .target(name: "JSONAST"),
            ]),

        .target(name: "JSONLegacy",
            dependencies: [
                .target(name: "JSONDecoding"),
            ]),

        .target(name: "JSONParsing",
            dependencies: [
                .target(name: "JSONAST"),
                .product(name: "Grammar", package: "swift-grammar"),
            ]),

        .target(name: "JSON",
            dependencies: [
                .target(name: "JSONDecoding"),
                .target(name: "JSONEncoding"),
                .target(name: "JSONParsing"),
            ]),

        .testTarget(name: "JSONTests",
            dependencies: [
                .target(name: "JSON"),
            ]),

        .testTarget(name: "JSONStressTestST",
            dependencies: [
                .target(name: "JSON"),
            ]),

        .executableTarget(name: "JSONStressTest",
            dependencies: [
                .target(name: "JSON"),
            ]),
    ]
)
