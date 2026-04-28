// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PreviewTestableViewExtensions",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PreviewTestableViewExtensions",
            targets: ["PreviewTestableViewExtensions"]
        ),
        .plugin(
            name: "GeneratePreviewMapper",
            targets: ["GeneratePreviewMapper"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/SourceKitten.git", from: "0.34.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PreviewTestableViewExtensions"
        ),
        .executableTarget(
            name: "GeneratePreviewMapperTool",
            dependencies: [
                .product(name: "SourceKittenFramework", package: "SourceKitten"),
            ],
            // SourceKitten predates Swift 6 strict concurrency; use v5 mode for the tool
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .plugin(
            name: "GeneratePreviewMapper",
            capability: .buildTool(),
            dependencies: ["GeneratePreviewMapperTool"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
