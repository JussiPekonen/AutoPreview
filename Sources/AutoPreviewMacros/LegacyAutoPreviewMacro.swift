import SwiftSyntax
import SwiftSyntaxMacros

/// The legacy implementation of `#AutoPreview(SomeView.self)`: expands to
/// a `PreviewProvider` struct built on `AutoPreviewable.autoPreview()`.
///
/// `AutoPreviewMacro` wraps `declaration(forType:)` in the `#else` branch
/// of a `#if swift(>=6.4)` block alongside its own `#Preview(arguments:)`
/// declaration, so this one is only ever compiled — and only ever live —
/// on toolchains below that language version.
///
/// Not wired up to any public `macro` declaration on its own.
/// `AutoPreviewMacro` is what `#AutoPreview` actually expands through; it
/// composes `declaration(forType:)` alongside its own declaration to
/// produce `#AutoPreview`'s full, combined expansion. This type still
/// conforms to `DeclarationMacro` in full — including its own argument
/// parsing and diagnostics via `AutoPreviewMacroArgument` — so it can be
/// exercised on its own (e.g. in `assertMacroExpansion`) independently of
/// `AutoPreviewMacro`.
public struct LegacyAutoPreviewMacro: DeclarationMacro, Sendable {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let typeName = AutoPreviewMacroArgument.parseTypeName(from: node, in: context) else {
            return []
        }

        return [declaration(forType: typeName)]
    }

    /// Builds the fallback `PreviewProvider` declaration for an
    /// already-parsed type name. `AutoPreviewMacro` calls this directly
    /// (rather than `expansion(of:in:)`) once it has parsed the argument
    /// itself, so a malformed argument is only ever diagnosed once.
    static func declaration(forType typeName: String) -> DeclSyntax {
        let previewsStructName = "\(AutoPreviewMacroArgument.sanitizedIdentifier(from: typeName))_Previews"

        return """
        struct \(raw: previewsStructName): PreviewProvider {
            static var previews: some View {
                \(raw: typeName).autoPreview()
            }
        }
        """
    }
}
