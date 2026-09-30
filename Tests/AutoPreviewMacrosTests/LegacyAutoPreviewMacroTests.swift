import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import AutoPreviewMacros

@Suite("LegacyAutoPreviewMacro")
struct LegacyAutoPreviewMacroTests {
    private let testMacros: [String: Macro.Type] = [
        "AutoPreview": LegacyAutoPreviewMacro.self
    ]

    @Test("Expands on its own to just the PreviewProvider struct")
    func expansion() {
        assertMacroExpansion(
            """
            #AutoPreview(GreetingCard.self)
            """,
            expandedSource: """
            struct GreetingCard_Previews: PreviewProvider {
                static var previews: some View {
                    GreetingCard.autoPreview()
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("Expands a namespaced type name into a valid, sanitized struct name")
    func expansionWithNamespacedType() {
        assertMacroExpansion(
            """
            #AutoPreview(Feature.GreetingCard.self)
            """,
            expandedSource: """
            struct Feature_GreetingCard_Previews: PreviewProvider {
                static var previews: some View {
                    Feature.GreetingCard.autoPreview()
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("A malformed argument emits an error and expands to nothing")
    func missingSelfArgumentEmitsDiagnostic() {
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
