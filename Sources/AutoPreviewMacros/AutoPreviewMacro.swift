import SwiftSyntax
import SwiftSyntaxMacros

/// The "normal" implementation of `#AutoPreview(SomeView.self)`, and the
/// type actually wired up to the public `#AutoPreview` macro declaration:
/// expands to a `#Preview(arguments:)` block driven directly by
/// `AutoPreviewable.previewData` (an array of `PreviewData` — each
/// bundling a name and its `previewBuilder(data:)` input together), named
/// after the templated view itself (`SomeView`'s own written name, as the
/// `#Preview`'s `name:` argument) rather than left unnamed.
///
/// Whether `#Preview(arguments:)` exists at all depends on which
/// toolchain compiles the code — it isn't a runtime OS-version question,
/// so `@available`/`if #available` (which gate on the *deployment
/// target's* OS version) are the wrong tool here, and neither is emitting
/// an `#if swift(>=6.4) ... #else ... #endif` pair into the expanded
/// code — that would leave both branches sitting in every call site's
/// expansion forever. Instead, `#if swift(>=6.4)` gates
/// `declaration(forType:)` *here*, in the macro's own implementation: the
/// language version that matters is the one this compiler plugin itself
/// is built with, so exactly one branch is ever even compiled into the
/// plugin, and `expansion(of:in:)` always returns a single, clean
/// declaration — either the `#Preview(arguments:)` block below, or
/// `LegacyAutoPreviewMacro`'s `PreviewProvider` struct — with no `#if` of
/// any kind appearing in the code a call site expands to. (Swift has no
/// way to check the host Xcode version directly in `#if`; `swift(>=6.4)`
/// stands in for "Xcode 27.0 or newer," the language version it's
/// expected to ship.)
///
/// NOTE: as of this writing, no shipping or beta SDK actually declares a
/// `#Preview(arguments:)` overload — only `Preview(_:body:)` and
/// `Preview(_:traits:body:)` exist. The `#if` branch below will not
/// compile even on a Swift 6.4+ toolchain against any real SwiftUI. It's
/// kept in this shape deliberately (at explicit request) for whenever/if
/// such an overload ships.
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
public struct AutoPreviewMacro: DeclarationMacro, Sendable {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // The macro's soundness comes entirely from the `T: AutoPreviewable`
        // generic constraint on its own declaration — the compiler already
        // rejects a non-conforming type before expansion ever runs. No
        // secondary textual check is needed (or safe to run) here.
        guard let typeName = AutoPreviewMacroArgument.parseTypeName(from: node, in: context) else {
            return []
        }

        return [declaration(forType: typeName)]
    }

    private static func declaration(forType typeName: String) -> DeclSyntax {
        #if swift(>=6.4)
        return """
        #Preview("\(raw: typeName)", arguments: \(raw: typeName).previewData) { item in
            \(raw: typeName).previewBuilder(data: item.data)
        }
        """
        #else
        return LegacyAutoPreviewMacro.declaration(forType: typeName)
        #endif
    }
}
