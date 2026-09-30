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

    @Test("Expands to the #Preview(arguments:) form as a peer declaration")
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

            #Preview("GreetingCard", arguments: GreetingCard.previewData) { item in
                GreetingCard.previewBuilder(data: item.data)
            }
            """,
            macros: testMacros
        )
    }

    @Test("Works when attached to a class, enum, or actor declaration too")
    func expansionOnOtherDeclarationKinds() {
        assertMacroExpansion(
            """
            @AutoPreview
            actor GreetingCard {
            }
            """,
            expandedSource: """
            actor GreetingCard {
            }

            #Preview("GreetingCard", arguments: GreetingCard.previewData) { item in
                GreetingCard.previewBuilder(data: item.data)
            }
            """,
            macros: testMacros
        )
    }

    @Test("Refers to a nested type by its simple name, resolved correctly from the enclosing scope")
    func expansionOnNestedType() {
        assertMacroExpansion(
            """
            enum Feature {
                @AutoPreview
                struct GreetingCard {
                }
            }
            """,
            expandedSource: """
            enum Feature {
                struct GreetingCard {
                }

                #Preview("GreetingCard", arguments: GreetingCard.previewData) { item in
                    GreetingCard.previewBuilder(data: item.data)
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

            #Preview("GreetingCard", arguments: GreetingCard.previewData) { item in
                GreetingCard.previewBuilder(data: item.data)
            }
            """,
            macros: testMacros
        )
    }

    @Test("Refers to a type extended by its qualified name, exactly as the extension itself wrote it")
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

            #Preview("Feature.GreetingCard", arguments: Feature.GreetingCard.previewData) { item in
                Feature.GreetingCard.previewBuilder(data: item.data)
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
