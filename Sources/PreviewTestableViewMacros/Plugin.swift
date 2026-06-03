import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct AutoPreviewMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        GeneratePreviewsMacro.self,
    ]
}
