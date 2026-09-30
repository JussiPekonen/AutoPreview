import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Parsing shared by every `#AutoPreview`-family macro implementation:
/// both `AutoPreviewMacro` (the normal implementation) and
/// `LegacyAutoPreviewMacro` accept the exact same `SomeView.self` argument
/// and need to diagnose the exact same malformed input, so that logic
/// lives here once rather than in each.
enum AutoPreviewMacroArgument {
    /// Extracts `SomeView` from a `#AutoPreview(SomeView.self)`-shaped
    /// call, diagnosing and returning `nil` if the single argument isn't
    /// shaped that way.
    static func parseTypeName(
        from node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> String? {
        guard
            let firstArgument = node.arguments.first?.expression,
            let memberAccess = firstArgument.as(MemberAccessExprSyntax.self),
            memberAccess.declName.baseName.text == "self",
            let base = memberAccess.base
        else {
            let diagnostic = Diagnostic(
                node: Syntax(node),
                message: AutoPreviewDiagnostic.expectedTypeSelfArgument
            )
            context.diagnose(diagnostic)
            return nil
        }

        return base.trimmedDescription
    }

    /// Turns something like `Namespace.MyView` into `Namespace_MyView`
    /// so a generated struct name is always a valid, unique identifier.
    static func sanitizedIdentifier(from typeName: String) -> String {
        typeName.replacing(".", with: "_")
    }
}

private enum AutoPreviewDiagnostic: String, DiagnosticMessage, Sendable {
    case expectedTypeSelfArgument

    var message: String {
        switch self {
        case .expectedTypeSelfArgument:
            return "#AutoPreview requires a single argument of the form `MyView.self`"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "AutoPreviewMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}
