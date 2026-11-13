import SwiftSyntax
import SwiftSyntaxMacros

/// The legacy implementation of `@AutoPreview`: expands to a
/// `PreviewProvider` struct built on `AutoPreviewable.autoPreview()`,
/// named `<name>_Previews` for a top-level type, or
/// `<super>_<sub>_PreviewProvider` for a nested one — a peer declaration
/// alongside a top-level type declaration, or a member nested inside an
/// extension or a nested type declaration.
///
/// `AutoPreviewMacro` calls `peerDeclarations(forType:attachedTo:in:)` and
/// `memberDeclarations(attachedTo:in:)` from its own `#else` branches of
/// `#if swift(>=6.4)` blocks, so this one is only ever compiled — and
/// only ever live — on toolchains below that language version.
///
/// Not wired up to any public `macro` declaration on its own.
/// `AutoPreviewMacro` is what `@AutoPreview` actually expands through; on
/// older toolchains it forwards straight to those two functions to
/// produce `@AutoPreview`'s full expansion. This type still conforms
/// to `PeerMacro` and `MemberMacro` in full — including its own argument parsing and
/// diagnostics via `AutoPreviewMacroArgument` — so it can be exercised on
/// its own (e.g. in `assertMacroExpansion`) independently of
/// `AutoPreviewMacro`.
public struct LegacyAutoPreviewMacro: PeerMacro, MemberMacro, Sendable {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let typeName = AutoPreviewMacroArgument.name(of: declaration, in: context) else {
            return []
        }

        return peerDeclarations(forType: typeName, attachedTo: declaration, in: context)
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        memberDeclarations(attachedTo: declaration, in: context)
    }

    /// The peer half of the expansion: the `PreviewProvider` struct for a
    /// top-level type declaration, or nothing for anything else (which
    /// gets its struct as a member instead — see
    /// `memberDeclarations(attachedTo:in:)`). `AutoPreviewMacro` calls
    /// this directly (rather than `expansion(of:providingPeersOf:in:)`)
    /// once it has parsed the argument itself, so a malformed attachment
    /// is only ever diagnosed once.
    ///
    /// `@AutoPreview` declares its peer as `names: suffixed(_Previews)`,
    /// which covers exactly `<name>_Previews`, where `<name>` is the
    /// type's *bare* identifier — `` `class` `` covers `class_Previews`,
    /// not `` `class`_Previews ``. That is always a valid identifier
    /// unless the type itself is a raw identifier (`` `My View` ``), in
    /// which case the struct name needs backticks too.
    static func peerDeclarations(
        forType typeName: String,
        attachedTo declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) -> [DeclSyntax] {
        guard let identifier = declaration.asProtocol(NamedDeclSyntax.self)?.name.identifier,
              enclosingTypeNameComponents(in: context).isEmpty else {
            return []
        }
        return [previewProvider(named: "\(identifier.name)_Previews", forType: typeName)]
    }

    /// The member half of the expansion: the `PreviewProvider` struct
    /// nested inside an extension or a nested type declaration; nothing
    /// for a top-level type declaration, which gets its struct as a peer
    /// instead.
    ///
    /// A nested type — declared inside another (`enum Feature { struct
    /// GreetingCard }`), or extended by its qualified name (`extension
    /// Feature.GreetingCard`) — gets `<super>_<sub>_PreviewProvider`
    /// (`Feature_GreetingCard_PreviewProvider`). An extension of a
    /// top-level type gets `<name>_Previews`, the same name a peer of its
    /// declaration would have.
    ///
    /// Neither can be a *peer*: an extension has no name of its own for
    /// `names: suffixed(_Previews)` to cover, and the qualified name isn't
    /// covered by it either, so the compiler rejects the struct as "not
    /// covered by macro 'AutoPreview'". Peer macros may not introduce
    /// arbitrary names at global scope — exactly where extensions and
    /// top-level types live — but member macros may, so `@AutoPreview`
    /// declares a member role with `names: arbitrary` just for this.
    static func memberDeclarations(
        attachedTo declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) -> [DeclSyntax] {
        if let extensionDecl = declaration.as(ExtensionDeclSyntax.self) {
            let extendedType = extensionDecl.extendedType
            let structName = nameComponents(of: extendedType).map(qualifiedStructName(for:))
                ?? "\(AutoPreviewMacroArgument.sanitizedIdentifier(from: extendedType.trimmedDescription))_Previews"
            return [previewProvider(named: structName, forType: extendedType.trimmedDescription)]
        }

        let enclosingComponents = enclosingTypeNameComponents(in: context)
        guard !enclosingComponents.isEmpty,
              let name = declaration.asProtocol(NamedDeclSyntax.self)?.name else {
            return []
        }
        let components = enclosingComponents + [name.identifier?.name ?? name.text]
        return [previewProvider(named: qualifiedStructName(for: components), forType: name.text)]
    }

    private static func previewProvider(named structName: String, forType typeName: String) -> DeclSyntax {
        """
        struct \(raw: AutoPreviewMacroArgument.declarationName(structName)): PreviewProvider {
            static var previews: some View {
                \(raw: typeName).autoPreview()
            }
        }
        """
    }

    /// `<super>_<sub>_PreviewProvider` for a nested type's name
    /// components, or `<name>_Previews` for a top-level one.
    private static func qualifiedStructName(for components: [String]) -> String {
        components.count > 1
            ? "\(components.joined(separator: "_"))_PreviewProvider"
            : "\(components.joined())_Previews"
    }

    /// The identifiers making up a type's spelling, without backticks or
    /// generic arguments: `["Feature", "GreetingCard"]` for
    /// `Feature.GreetingCard` or `` Feature.`GreetingCard` ``,
    /// `["Wrapper"]` for `Wrapper<GreetingCard>`. `nil` for any other
    /// spelling (e.g. sugar like `[GreetingCard]`), which has no such
    /// identifiers.
    private static func nameComponents(of type: TypeSyntax) -> [String]? {
        if let identifierType = type.as(IdentifierTypeSyntax.self) {
            return [identifierType.name.identifier?.name ?? identifierType.name.text]
        }
        if let memberType = type.as(MemberTypeSyntax.self), let base = nameComponents(of: memberType.baseType) {
            return base + [memberType.name.identifier?.name ?? memberType.name.text]
        }
        return nil
    }

    /// The names of the types the attached declaration is nested in,
    /// outermost first — empty for a top-level one. An enclosing
    /// extension contributes its extended type's name. Only the
    /// directly enclosing run of types counts: a type declared inside a
    /// function is local to it, so it's treated as top-level.
    private static func enclosingTypeNameComponents(in context: some MacroExpansionContext) -> [String] {
        var components: [String] = []
        for enclosing in context.lexicalContext {
            if let extensionDecl = enclosing.as(ExtensionDeclSyntax.self) {
                guard let extendedComponents = nameComponents(of: extensionDecl.extendedType) else {
                    return []
                }
                components.insert(contentsOf: extendedComponents, at: 0)
            } else if let name = enclosing.asProtocol(NamedDeclSyntax.self)?.name, enclosing.isProtocol(DeclGroupSyntax.self) {
                components.insert(name.identifier?.name ?? name.text, at: 0)
            } else {
                break
            }
        }
        return components
    }
}
