// swift-tools-version: 6.3
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "AutoPreview",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9)],
    products: [
        .library(name: "AutoPreview", targets: ["AutoPreview"]),
        .plugin(name: "TestablePreviewsPlugin", targets: ["TestablePreviewsPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "603.0.2")
    ],
    targets: [
        .macro(
            name: "AutoPreviewMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(
            name: "AutoPreview",
            dependencies: ["AutoPreviewMacros"]
        ),
        .executableTarget(
            name: "TestablePreviewsGenerator",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ]
        ),
        .plugin(
            name: "TestablePreviewsPlugin",
            capability: .buildTool(),
            dependencies: ["TestablePreviewsGenerator"]
        ),
        .testTarget(
            name: "AutoPreviewMacrosTests",
            dependencies: [
                "AutoPreviewMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ]
        ),
        .testTarget(
            name: "TestablePreviewsGeneratorTests",
            dependencies: [
                "TestablePreviewsGenerator",
                .product(name: "SwiftParser", package: "swift-syntax")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
