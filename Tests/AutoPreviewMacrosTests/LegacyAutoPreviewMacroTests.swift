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

            struct __macro_local_21GreetingCard_PreviewsfMu_: PreviewProvider {
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

            struct __macro_local_33Feature_x2E_GreetingCard_PreviewsfMu_: PreviewProvider {
                static var previews: some View {
                    Feature.GreetingCard.autoPreview()
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("Names a backtick-escaped keyword type's struct after its bare name")
    func expansionOnKeywordNamedType() {
        assertMacroExpansion(
            """
            @AutoPreview
            struct `class` {
            }
            """,
            expandedSource: """
            struct `class` {
            }

            struct class_Previews: PreviewProvider {
                static var previews: some View {
                    `class`.autoPreview()
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("Wraps a raw-identifier type's struct name in backticks")
    func expansionOnRawIdentifierType() {
        assertMacroExpansion(
            """
            @AutoPreview
            struct `Greeting Card` {
            }
            """,
            expandedSource: """
            struct `Greeting Card` {
            }

            struct `Greeting Card_Previews`: PreviewProvider {
                static var previews: some View {
                    `Greeting Card`.autoPreview()
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("Escapes generic and sugared extended types into a valid struct name", arguments: [
        ("Wrapper<GreetingCard>", "__macro_local_38Wrapper_x3C_GreetingCard_x3E__PreviewsfMu_"),
        ("[GreetingCard]", "__macro_local_31_x5B_GreetingCard_x5D__PreviewsfMu_"),
        ("Feature.`GreetingCard`", "__macro_local_43Feature_x2E__x60_GreetingCard_x60__PreviewsfMu_"),
    ])
    func expansionOnUnusualExtendedType(extendedType: String, structName: String) {
        assertMacroExpansion(
            """
            @AutoPreview
            extension \(extendedType): AutoPreviewable {
            }
            """,
            expandedSource: """
            extension \(extendedType): AutoPreviewable {
            }

            struct \(structName): PreviewProvider {
                static var previews: some View {
                    \(extendedType).autoPreview()
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("Sanitizes distinct extended-type spellings to distinct names")
    func sanitizingIsOneToOne() {
        let spellings = ["GreetingCard", "[GreetingCard]", "Feature.GreetingCard", "Feature_GreetingCard", "Feature__GreetingCard"]
        let sanitized = spellings.map(AutoPreviewMacroArgument.sanitizedIdentifier(from:))
        #expect(Set(sanitized).count == spellings.count)
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
