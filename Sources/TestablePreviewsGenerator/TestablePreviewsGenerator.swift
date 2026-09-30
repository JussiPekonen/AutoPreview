import Foundation
import SwiftParser

/// Command-line tool invoked by `TestablePreviewsPlugin`.
///
/// Usage: `TestablePreviewsGenerator --output <path> <sourceFile1> <sourceFile2> ...`
@main
struct TestablePreviewsGenerator {
    static func main() throws {
        let (outputPath, inputPaths) = try parseArguments(Array(CommandLine.arguments.dropFirst()))

        var conformingTypeNames: [String] = []

        for inputPath in inputPaths {
            // Best-effort per file: a single unreadable/unparseable file
            // (e.g. a stale path from an incremental build edge case)
            // shouldn't take down code generation for the whole target.
            guard let source = try? String(contentsOfFile: inputPath, encoding: .utf8) else {
                continue
            }

            // Find every type in this file that conforms to
            // AutoPreviewable, and its fully namespaced name.
            let tree = Parser.parse(source: source)
            let collector = AutoPreviewableConformanceCollector()
            collector.walk(tree)
            conformingTypeNames.append(contentsOf: collector.discoveredConformances.map(\.qualifiedName))
        }

        let generatedSource = GeneratedSourceBuilder.makeSource(conformingTypeNames: conformingTypeNames)
        try generatedSource.write(toFile: outputPath, atomically: true, encoding: .utf8)
    }

    /// Splits `--output <path>` out of the argument list; everything else is
    /// treated as an input source file path.
    private static func parseArguments(_ arguments: [String]) throws -> (outputPath: String, inputPaths: [String]) {
        guard let outputFlagIndex = arguments.firstIndex(of: "--output") else {
            throw GeneratorError.missingOutputFlag
        }
        let outputPathIndex = arguments.index(after: outputFlagIndex)
        guard arguments.indices.contains(outputPathIndex) else {
            throw GeneratorError.missingOutputPath
        }

        var remaining = arguments
        remaining.removeSubrange(outputFlagIndex...outputPathIndex)

        return (outputPath: arguments[outputPathIndex], inputPaths: remaining)
    }
}

enum GeneratorError: Error, CustomStringConvertible {
    case missingOutputFlag
    case missingOutputPath

    var description: String {
        switch self {
        case .missingOutputFlag:
            return "TestablePreviewsGenerator requires an --output <path> argument."
        case .missingOutputPath:
            return "TestablePreviewsGenerator's --output flag is missing its path argument."
        }
    }
}
