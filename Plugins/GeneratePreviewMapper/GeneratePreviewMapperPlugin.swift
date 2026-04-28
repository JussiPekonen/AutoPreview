import Foundation
import PackagePlugin

@main
struct GeneratePreviewMapperPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let swiftTarget = target as? SwiftSourceModuleTarget else { return [] }
        let tool = try context.tool(named: "GeneratePreviewMapperTool")
        let sourceFiles = swiftTarget.sourceFiles(withSuffix: "swift").map(\.url)
        return commands(tool: tool, sourceFiles: sourceFiles, workDirectory: context.pluginWorkDirectoryURL)
    }

    private func commands(tool: PluginContext.Tool, sourceFiles: [URL], workDirectory: URL) -> [Command] {
        let outputFile = workDirectory.appending(path: "PreviewTestableMapper.swift")
        return [
            .buildCommand(
                displayName: "Generate PreviewTestableMapper",
                executable: tool.url,
                arguments: sourceFiles.map(\.path) + ["--output", outputFile.path],
                inputFiles: sourceFiles,
                outputFiles: [outputFile]
            )
        ]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension GeneratePreviewMapperPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let tool = try context.tool(named: "GeneratePreviewMapperTool")
        let sourceFiles = target.inputFiles
            .filter { $0.url.pathExtension == "swift" }
            .map(\.url)
        return commands(tool: tool, sourceFiles: sourceFiles, workDirectory: context.pluginWorkDirectoryURL)
    }
}
#endif
