import SwiftSyntax
import SwiftSyntaxMacros

/// The legacy implementation of `@AutoPreview`: expands to a
/// `PreviewProvider` struct built on `AutoPreviewable.autoPreview()`,
/// attached as a peer declaration alongside the type it previews.
///
/// `AutoPreviewMacro` calls `previewDeclaration(forType:)` from its own
/// `#else` branch of a `#if swift(>=6.4)` block, so this one is only ever
/// compiled — and only ever live — on toolchains below that language
/// version.
///
/// Not wired up to any public `macro` declaration on its own.
/// `AutoPreviewMacro` is what `@AutoPreview` actually expands through; on
/// older toolchains it forwards straight to `previewDeclaration(forType:)`
/// to produce `@AutoPreview`'s full expansion. This type still conforms
/// to `PeerMacro` in full — including its own argument parsing and
/// diagnostics via `AutoPreviewMacroArgument` — so it can be exercised on
/// its own (e.g. in `assertMacroExpansion`) independently of
/// `AutoPreviewMacro`.
public struct LegacyAutoPreviewMacro: PeerMacro, Sendable {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let typeName = AutoPreviewMacroArgument.name(of: declaration, in: context) else {
            return []
        }

        return [previewDeclaration(forType: typeName)]
    }

    /// Builds the fallback `PreviewProvider` declaration for an
    /// already-parsed type name. `AutoPreviewMacro` calls this directly
    /// (rather than `expansion(of:providingPeersOf:in:)`) once it has
    /// parsed the argument itself, so a malformed attachment is only ever
    /// diagnosed once.
    static func previewDeclaration(forType typeName: String) -> DeclSyntax {
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
