import SwiftSyntax

/// Walks a parsed source file looking for struct/class/enum/actor
/// declarations — and extensions of any of those — that list
/// `AutoPreviewable` in their inheritance clause.
///
/// Tracks a stack of enclosing type names so nested types are reported with
/// their full dotted path (e.g. a `GreetingCard` nested inside `enum
/// Feature` is reported as `"Feature.GreetingCard"`), matching how
/// `#AutoPreview` and `SourceKittenTypeInspector` already reason about
/// namespaced names elsewhere in this package.
///
/// This is purely syntactic, same as the rest of this package's
/// conformance-checking: it matches on the literal name `AutoPreviewable` in
/// an inheritance clause, not on real type-checked conformance. That's the
/// right tradeoff here — the generator runs as a standalone build-time
/// executable with no access to a type checker, and doesn't need one; any
/// type that doesn't actually satisfy `AutoPreviewable` will fail to compile
/// on its own regardless of what this tool records.
final class AutoPreviewableConformanceCollector: SyntaxVisitor {
    /// One discovered conformance: the type's simple name, and its fully
    /// dotted, namespaced name as written in source.
    struct Conformance {
        let simpleName: String
        let qualifiedName: String
    }

    private(set) var discoveredConformances: [Conformance] = []
    private var nestingStack: [String] = []

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    // MARK: - Nominal type declarations

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        visitNominalType(name: node.name.text, inheritanceClause: node.inheritanceClause)
    }

    override func visitPost(_ node: StructDeclSyntax) {
        nestingStack.removeLast()
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        visitNominalType(name: node.name.text, inheritanceClause: node.inheritanceClause)
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        nestingStack.removeLast()
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        visitNominalType(name: node.name.text, inheritanceClause: node.inheritanceClause)
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        nestingStack.removeLast()
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        visitNominalType(name: node.name.text, inheritanceClause: node.inheritanceClause)
    }

    override func visitPost(_ node: ActorDeclSyntax) {
        nestingStack.removeLast()
    }

    // MARK: - Extensions

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let extendedTypeName = node.extendedType.trimmedDescription
        let qualifiedName = nestingStack.isEmpty
            ? extendedTypeName
            : "\(nestingStack.joined(separator: ".")).\(extendedTypeName)"

        recordIfConforming(
            simpleName: lastComponent(of: extendedTypeName),
            qualifiedName: qualifiedName,
            inheritanceClause: node.inheritanceClause
        )

        // Deliberately not pushing onto `nestingStack` here: extensions
        // don't introduce a new namespace of their own. Members declared
        // inside the extension body belong to the extended type, which
        // `qualifiedName` already captures; anything nested further inside
        // is handled relative to this same stack by its own visit method.
        return .visitChildren
    }

    // MARK: - Private

    private func visitNominalType(
        name: String,
        inheritanceClause: InheritanceClauseSyntax?
    ) -> SyntaxVisitorContinueKind {
        let qualifiedName = (nestingStack + [name]).joined(separator: ".")
        recordIfConforming(simpleName: name, qualifiedName: qualifiedName, inheritanceClause: inheritanceClause)
        nestingStack.append(name)
        return .visitChildren
    }

    private func recordIfConforming(
        simpleName: String,
        qualifiedName: String,
        inheritanceClause: InheritanceClauseSyntax?
    ) {
        guard let inheritanceClause else { return }

        let conformsToAutoPreviewable = inheritanceClause.inheritedTypes.contains { inheritedType in
            lastComponent(of: inheritedType.type.trimmedDescription) == "AutoPreviewable"
        }
        guard conformsToAutoPreviewable else { return }

        discoveredConformances.append(Conformance(simpleName: simpleName, qualifiedName: qualifiedName))
    }

    private func lastComponent(of qualifiedName: String) -> String {
        qualifiedName.split(separator: ".").last.map(String.init) ?? qualifiedName
    }
}
