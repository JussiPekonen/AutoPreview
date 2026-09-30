import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Parsing shared by every `@AutoPreview`-family macro implementation:
/// both `AutoPreviewMacro` (the normal implementation) and
/// `LegacyAutoPreviewMacro` are attached directly to the type (or an
/// extension of it) they preview, and need to diagnose the exact same
/// misuse — attaching to something that names no type at all — so that
/// logic lives here once rather than in each.
enum AutoPreviewMacroArgument {
    /// Extracts the name of the type `@AutoPreview` is attached to,
    /// diagnosing and returning `nil` if it's attached to neither a
    /// struct, class, enum, or actor declaration, nor an extension of one.
    ///
    /// A type declaration's own *simple* name is always enough to refer
    /// to it — a peer macro's generated declarations are inserted as
    /// siblings in the same scope as the attached one, so a type nested
    /// inside e.g. `enum Feature` doesn't need (and can't spell) a
    /// qualified `Feature.GreetingCard` name to refer to itself;
    /// `GreetingCard` alone already resolves correctly from that scope.
    ///
    /// An extension's *extended type*, though, is used exactly as
    /// written: extensions (unlike the type declarations they extend)
    /// are routinely written at a different scope than the type itself —
    /// often top-level, referring to a nested type by its qualified name
    /// (`extension Feature.GreetingCard: AutoPreviewable { ... }`) — and
    /// the peer declaration this macro generates is inserted alongside
    /// the extension, in *that* scope, so it needs whatever spelling
    /// resolves correctly from there. That spelling can contain dots,
    /// which is exactly why `LegacyAutoPreviewMacro` still sanitizes it
    /// before using it as (part of) a generated struct's name.
    static func name(
        of declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) -> String? {
        let name =
            declaration.as(StructDeclSyntax.self)?.name.text
            ?? declaration.as(ClassDeclSyntax.self)?.name.text
            ?? declaration.as(EnumDeclSyntax.self)?.name.text
            ?? declaration.as(ActorDeclSyntax.self)?.name.text
            ?? declaration.as(ExtensionDeclSyntax.self)?.extendedType.trimmedDescription

        guard let name else {
            let diagnostic = Diagnostic(
                node: Syntax(declaration),
                message: AutoPreviewDiagnostic.expectedNamedTypeDeclaration
            )
            context.diagnose(diagnostic)
            return nil
        }

        return name
    }

    /// Turns something like `Namespace.MyView` into `Namespace_MyView`
    /// so a generated struct name is always a valid, unique identifier —
    /// needed only for a name that might contain dots, i.e. one that came
    /// from an extension's extended type rather than a type declaration's
    /// own simple name.
    static func sanitizedIdentifier(from typeName: String) -> String {
        typeName.replacing(".", with: "_")
    }
}

private enum AutoPreviewDiagnostic: String, DiagnosticMessage, Sendable {
    case expectedNamedTypeDeclaration

    var message: String {
        switch self {
        case .expectedNamedTypeDeclaration:
            return "@AutoPreview can only be attached to a struct, class, enum, actor, or extension declaration"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "AutoPreviewMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}
