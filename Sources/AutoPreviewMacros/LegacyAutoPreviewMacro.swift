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

        return [previewDeclaration(forType: typeName, attachedTo: declaration, in: context)]
    }

    /// Builds the fallback `PreviewProvider` declaration for an
    /// already-parsed type name. `AutoPreviewMacro` calls this directly
    /// (rather than `expansion(of:providingPeersOf:in:)`) once it has
    /// parsed the argument itself, so a malformed attachment is only ever
    /// diagnosed once.
    static func previewDeclaration(
        forType typeName: String,
        attachedTo declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) -> DeclSyntax {
        let previewsStructName = previewsStructName(forType: typeName, attachedTo: declaration, in: context)

        return """
        struct \(raw: previewsStructName): PreviewProvider {
            static var previews: some View {
                \(raw: typeName).autoPreview()
            }
        }
        """
    }

    /// `@AutoPreview` declares its peer as `names: suffixed(_Previews)`,
    /// which only covers `<name>_Previews` for a declaration that *has* a
    /// name of its own. An extension doesn't — so a `<Type>_Previews`
    /// struct generated next to one is rejected as "not covered by macro
    /// 'AutoPreview'". (`names: arbitrary` isn't an option either: peer
    /// macros may not introduce arbitrary names at global scope, which is
    /// exactly where extensions usually live.) Names from
    /// `makeUniqueName(_:)` are exempt from that coverage check, so an
    /// extension gets one of those instead; nothing refers to the struct
    /// by name anyway — each preview's display name comes from
    /// `autoPreview()` itself. The extended type's spelling is sanitized
    /// first, since `makeUniqueName(_:)` embeds it verbatim — a `<`,
    /// space, or backtick in it would break the generated declaration.
    ///
    /// A type declaration's struct, on the other hand, must be named
    /// exactly `<name>_Previews` to be covered, where `<name>` is the
    /// type's *bare* identifier — `` `class` `` covers `class_Previews`,
    /// not `` `class`_Previews ``. That is always a valid identifier
    /// unless the type itself is a raw identifier (`` `My View` ``), in
    /// which case the struct name needs backticks too.
    private static func previewsStructName(
        forType typeName: String,
        attachedTo declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) -> String {
        if let identifier = declaration.asProtocol(NamedDeclSyntax.self)?.name.identifier {
            return AutoPreviewMacroArgument.declarationName("\(identifier.name)_Previews")
        }
        let sanitizedName = "\(AutoPreviewMacroArgument.sanitizedIdentifier(from: typeName))_Previews"
        return context.makeUniqueName(sanitizedName).text
    }
}
