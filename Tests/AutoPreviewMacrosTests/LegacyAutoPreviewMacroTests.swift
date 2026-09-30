import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import AutoPreviewMacros

@Suite("LegacyAutoPreviewMacro")
struct LegacyAutoPreviewMacroTests {
    private let testMacros: [String: Macro.Type] = [
        "AutoPreview": LegacyAutoPreviewMacro.self
    ]

    @Test("Expands on its own to just the PreviewProvider struct, as a peer declaration")
    func expansion() {
        assertMacroExpansion(
            """
            @AutoPreview
            struct GreetingCard {
            }
            """,
            expandedSource: """
            struct GreetingCard {
            }

            struct GreetingCard_Previews: PreviewProvider {
                static var previews: some View {
                    GreetingCard.autoPreview()
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("Works when attached to an extension declaring AutoPreviewable conformance")
    func expansionOnExtension() {
        assertMacroExpansion(
            """
            @AutoPreview
            extension GreetingCard: AutoPreviewable {
            }
            """,
            expandedSource: """
            extension GreetingCard: AutoPreviewable {
            }

            struct GreetingCard_Previews: PreviewProvider {
                static var previews: some View {
                    GreetingCard.autoPreview()
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("Sanitizes a qualified extended type into a valid, unique struct name")
    func expansionOnQualifiedExtension() {
        assertMacroExpansion(
            """
            @AutoPreview
            extension Feature.GreetingCard: AutoPreviewable {
            }
            """,
            expandedSource: """
            extension Feature.GreetingCard: AutoPreviewable {
            }

            struct Feature_GreetingCard_Previews: PreviewProvider {
                static var previews: some View {
                    Feature.GreetingCard.autoPreview()
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("Attaching to something that names no type at all emits an error and expands to nothing")
    func nonTypeDeclarationEmitsDiagnostic() {
        assertMacroExpansion(
            """
            @AutoPreview
            var greetingCard: Int
            """,
            expandedSource: """
            var greetingCard: Int
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@AutoPreview can only be attached to a struct, class, enum, actor, or extension declaration",
                    line: 1,
                    column: 1
                )
            ],
            macros: testMacros
        )
    }
}
