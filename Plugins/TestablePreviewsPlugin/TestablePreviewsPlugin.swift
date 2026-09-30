import Foundation
import PackagePlugin

@main
struct TestablePreviewsPlugin: BuildToolPlugin {
    /// Entry point for targets in a Swift package.
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let sourceModule = target as? SourceModuleTarget else {
            return []
        }

        let swiftFiles = sourceModule.sourceFiles
            .filter { $0.url.pathExtension == "swift" }
            .map(\.url)

        guard !swiftFiles.isEmpty else {
            return []
        }

        return try [
            makeBuildCommand(
                generatorToolURL: context.tool(named: "TestablePreviewsGenerator").url,
                workDirectoryURL: context.pluginWorkDirectoryURL,
                displayName: "Generating TestablePreviews for \(sourceModule.name)",
                swiftFiles: swiftFiles
            )
        ]
    }

    private func makeBuildCommand(
        generatorToolURL: URL,
        workDirectoryURL: URL,
        displayName: String,
        swiftFiles: [URL]
    ) -> Command {
        let outputFileURL = workDirectoryURL.appending(path: "TestablePreviews.swift")

        return .buildCommand(
            displayName: displayName,
            executable: generatorToolURL,
            arguments: ["--output", outputFileURL.path()] + swiftFiles.map { $0.path() },
            inputFiles: swiftFiles,
            outputFiles: [outputFileURL]
        )
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension TestablePreviewsPlugin: XcodeBuildToolPlugin {
    /// Entry point for targets in a plain Xcode project (added via the
    /// target's "Build Tool Plug-ins" list in Xcode's target editor,
    /// after adding this package as a package dependency).
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let swiftFiles = target.inputFiles
            .filter { $0.type == .source && $0.url.pathExtension == "swift" }
            .map(\.url)

        guard !swiftFiles.isEmpty else {
            return []
        }

        return [
            makeBuildCommand(
                generatorToolURL: try context.tool(named: "TestablePreviewsGenerator").url,
                workDirectoryURL: context.pluginWorkDirectoryURL,
                displayName: "Generating TestablePreviews for \(target.displayName)",
                swiftFiles: swiftFiles
            )
        ]
    }
}
#endif
