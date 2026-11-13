import SwiftDiagnostics
import SwiftParser
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

    /// Turns an extended type's spelling into something usable as part of
    /// a plain identifier. Characters that can't appear in an identifier
    /// (dots, generic brackets, sugar, whitespace, backticks) are escaped
    /// as `_x<hex>_`, and an underscore already in the name is doubled, so
    /// `Namespace.MyView` becomes `Namespace_x2E_MyView` and `[MyView]`
    /// becomes `_x5B_MyView_x5D_`.
    ///
    /// The encoding is deliberately one-to-one rather than just readable,
    /// so two different spellings (e.g. `[MyView]` and `MyView`, or
    /// `Namespace.MyView` and `Namespace_MyView`) never sanitize to the
    /// same name.
    ///
    /// Only needed for an extension's extended type, which (unlike a type
    /// declaration's own name) can be any type spelling at all — and only
    /// when that spelling doesn't end in a plain identifier to name the
    /// generated struct after instead (e.g. sugar like `[MyView]`).
    static func sanitizedIdentifier(from typeName: String) -> String {
        typeName.unicodeScalars.map { scalar in
            if scalar == "_" {
                return "__"
            }
            // Prefixing with a letter checks whether the character can
            // *continue* an identifier; a type spelling always starts with
            // a character that can also start one, or gets escaped here.
            if "a\(scalar)".isValidSwiftIdentifier(for: .variableName) {
                return String(scalar)
            }
            return "_x\(String(scalar.value, radix: 16, uppercase: true))_"
        }
        .joined()
    }

    /// The human-readable title for a type's previews: its spelling with
    /// the backticks removed, so a raw-identifier type `` `My View` ``
    /// (or an extension of `` Feature.`My View` ``) is titled `My View`
    /// (`Feature.My View`) rather than showing the quoting. Backticks in a
    /// type spelling only ever delimit identifiers, so nothing else is
    /// lost. Callers emit the result as a string literal via
    /// `\(literal:)`, which escapes any `"` or `\\` left in it.
    static func previewTitle(forType typeName: String) -> String {
        typeName.replacing("`", with: "")
    }

    /// Renders `name` as a declaration name: as-is if it's a valid plain
    /// identifier, otherwise wrapped in backticks as a raw identifier
    /// (e.g. a type itself declared as `` `My View` ``).
    static func declarationName(_ name: String) -> String {
        name.isValidSwiftIdentifier(for: .variableName) ? name : "`\(name)`"
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
