import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `#GeneratePreviews` freestanding declaration macro.
///
/// Expands:
/// ```swift
/// #GeneratePreviews(MyView.self, previewData: MyView.previewData)
/// ```
/// into:
/// ```swift
/// #Preview("MyView") {
///     let _previewData = MyView.previewData
///     ForEach(_previewData.keys.sorted(), id: \.self) { key in
///         if let data = _previewData[key] {
///             MyView.previewBuilder(data)
///                 .previewDisplayName("MyView / " + key)
///         }
///     }
/// }
/// ```
public struct GeneratePreviewsMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let args = node.arguments

        // First argument: TypeName.self — extract the base expression and its text
        guard let firstArg = args.first,
              let memberAccess = firstArg.expression.as(MemberAccessExprSyntax.self),
              memberAccess.declName.baseName.text == "self",
              let base = memberAccess.base else {
            throw MacroExpansionError(
                "First argument must be a type metatype expression, e.g. MyView.self"
            )
        }

        let typeName = base.trimmedDescription  // e.g. "LandmarkList"

        // Second argument (labeled "previewData"): the [String: PTD] expression
        guard let previewDataArg = args.first(where: { $0.label?.text == "previewData" }) else {
            throw MacroExpansionError("Expected a 'previewData:' labeled argument")
        }

        let previewDataExpr = previewDataArg.expression

        // Generate one #Preview declaration that renders all keyed variants.
        // \.self is written as \\.self so the backslash survives into the emitted source.
        let decl: DeclSyntax =
            """
            #Preview(\"\(raw: typeName)\") {
                let _previewData = \(previewDataExpr)
                ForEach(_previewData.keys.sorted(), id: \\.self) { key in
                    if let data = _previewData[key] {
                        \(base).previewBuilder(data)
                            .previewDisplayName(\"\(raw: typeName) / \" + key)
                    }
                }
            }
            """

        return [decl]
    }
}

// MARK: - Error helpers

private struct MacroExpansionError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}
