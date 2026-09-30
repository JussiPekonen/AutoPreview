import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import AutoPreviewMacros

@Suite("AutoPreviewMacro")
struct AutoPreviewMacroTests {
    private let testMacros: [String: Macro.Type] = [
        "AutoPreview": AutoPreviewMacro.self
    ]

    // These expect the `#Preview(arguments:)`-based expansion rather than
    // `LegacyAutoPreviewMacro`'s fallback, because `AutoPreviewMacro`'s
    // `#if swift(>=6.4)` is compiled against *this test target's own*
    // Swift toolchain — the same one running these tests. On a toolchain
    // below 6.4, `AutoPreviewMacro` itself would only ever produce the
    // fallback struct, and these two would need to expect that instead.

    @Test("Expands a basic #AutoPreview call into the #Preview(arguments:) form")
    func expansion() {
        assertMacroExpansion(
            """
            #AutoPreview(GreetingCard.self)
            """,
            expandedSource: """
            #Preview("GreetingCard", arguments: GreetingCard.previewData) { item in
                GreetingCard.previewBuilder(data: item.data)
            }
            """,
            macros: testMacros
        )
    }

    @Test("Expands a namespaced type name by referencing it directly, no sanitizing needed")
    func expansionWithNamespacedType() {
        assertMacroExpansion(
            """
            #AutoPreview(Feature.GreetingCard.self)
            """,
            expandedSource: """
            #Preview("Feature.GreetingCard", arguments: Feature.GreetingCard.previewData) { item in
                Feature.GreetingCard.previewBuilder(data: item.data)
            }
            """,
            macros: testMacros
        )
    }

    @Test("A malformed argument emits an error and expands to nothing")
    func missingSelfArgumentEmitsDiagnostic() {
        // The guard fails before any declaration is produced, so the macro
        // returns zero declarations — meaning the call site is removed
        // entirely, not left in place.
        assertMacroExpansion(
            """
            #AutoPreview(GreetingCard())
            """,
            expandedSource: "",
            diagnostics: [
                DiagnosticSpec(
                    message: "#AutoPreview requires a single argument of the form `MyView.self`",
                    line: 1,
                    column: 1
                )
            ],
            macros: testMacros
        )
    }
}
