import SwiftSyntax
import SwiftSyntaxMacros

/// The "normal" implementation of `@AutoPreview`, and the type actually
/// wired up to the public `@AutoPreview` macro declaration: expands to a
/// `#Preview(arguments:)` block driven directly by
/// `AutoPreviewable.previewData` (an array of `PreviewData` — each
/// bundling a name and its `previewBuilder(data:)` input together), named
/// after the templated view itself (its own written name, as the
/// `#Preview`'s `name:` argument) rather than left unnamed.
///
/// `@AutoPreview` is a *peer* macro — attached directly to the type it
/// previews (`@AutoPreview struct SomeView: ... { }`), or to an extension
/// declaring its `AutoPreviewable` conformance (`@AutoPreview extension
/// SomeView: AutoPreviewable { ... }`) — rather than a freestanding one
/// that has to be separately invoked (`#AutoPreview(SomeView.self)`)
/// wherever a preview is wanted. The generated declaration is inserted as
/// a sibling of whichever declaration `@AutoPreview` is attached to, in
/// that declaration's own scope, never inlined into its body.
///
/// Whether `#Preview(arguments:)` exists at all depends on which
/// toolchain compiles the code — it isn't a runtime OS-version question,
/// so `@available`/`if #available` (which gate on the *deployment
/// target's* OS version) are the wrong tool here, and neither is emitting
/// an `#if swift(>=6.4) ... #else ... #endif` pair into the expanded
/// code — that would leave both branches sitting in every call site's
/// expansion forever. Instead, `#if swift(>=6.4)` gates
/// `previewDeclaration(forType:)` *here*, in the macro's own
/// implementation: the language version that matters is the one this
/// compiler plugin itself is built with, so exactly one branch is ever
/// even compiled into the plugin, and `expansion(of:providingPeersOf:in:)`
/// always returns a single, clean declaration — either the
/// `#Preview(arguments:)` block below, or `LegacyAutoPreviewMacro`'s
/// `PreviewProvider` struct — with no `#if` of any kind appearing in the
/// code a call site expands to. (Swift has no way to check the host
/// Xcode version directly in `#if`; `swift(>=6.4)` stands in for "Xcode
/// 27.0 or newer," the language version it's expected to ship.)
///
/// NOTE: confirmed against the iOS 27.0/macOS 27.0 SDKs — `#Preview`
/// does now have an `arguments:` overload:
/// `Preview<T>(_:traits:arguments: [T], body: (T) -> some View)`, gated
/// `@available(iOS 26.0, macOS 27.0, tvOS 26.0, watchOS 26.0, visionOS
/// 26.0, *)`. `arguments:` takes a concrete `[T]` array — which is
/// exactly what `AutoPreviewable.previewData` already is.
///
/// Since `@AutoPreview` is attached rather than freestanding, there's no
/// generic type parameter to constrain the way a freestanding macro's
/// `<T: AutoPreviewable>(_ type: T.Type)` argument could — the compiler
/// no longer rejects a non-conforming attachment before expansion runs.
/// Attaching `@AutoPreview` to a type that doesn't conform to
/// `AutoPreviewable` simply fails to compile once the generated code
/// below references `previewData`/`previewBuilder(data:)` on it.
///
/// This type has no SourceKit/`SourceKittenSupport` dependency, on purpose.
/// An earlier version used it for a secondary "couldn't confirm
/// conformance" warning, but that ran `sourcekitd` *inside* the macro's
/// compiler-plugin host process — and a `sourcekitd` failure there doesn't
/// throw a catchable Swift error, it can crash the plugin process outright,
/// which the compiler reports as `Failed to receive result from plugin`.
/// That's not something a `try?`/fail-open wrapper can guard against, since
/// the whole process is gone. `SourceKittenTypeInspector` is still used
/// elsewhere in this package (`TestablePreviewsGenerator`), which runs as
/// its own plain executable rather than as an in-process compiler plugin,
/// so a SourceKit failure there fails one build step instead of taking
/// down macro expansion itself.
public struct AutoPreviewMacro: PeerMacro, Sendable {
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

    private static func previewDeclaration(forType typeName: String) -> DeclSyntax {
        #if swift(>=6.4)
        return """
        #Preview("\(raw: typeName)", arguments: \(raw: typeName).previewData) { item in
            \(raw: typeName).previewBuilder(data: item.data)
        }
        """
        #else
        return LegacyAutoPreviewMacro.previewDeclaration(forType: typeName)
        #endif
    }
}
