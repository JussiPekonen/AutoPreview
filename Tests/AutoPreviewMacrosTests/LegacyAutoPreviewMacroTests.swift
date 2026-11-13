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

                struct GreetingCard_Previews: PreviewProvider {
                    static var previews: some View {
                        GreetingCard.autoPreview()
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("Names a qualified extended type's struct <super>_<sub>_PreviewProvider")
    func expansionOnQualifiedExtension() {
        assertMacroExpansion(
            """
            @AutoPreview
            extension Feature.GreetingCard: AutoPreviewable {
            }
            """,
            expandedSource: """
            extension Feature.GreetingCard: AutoPreviewable {

                struct Feature_GreetingCard_PreviewProvider: PreviewProvider {
                    static var previews: some View {
                        Feature.GreetingCard.autoPreview()
                    }
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

    @Test("Names an unusual extended type's struct after its name components, or escapes it if it has none", arguments: [
        ("Wrapper<GreetingCard>", "Wrapper_Previews"),
        ("Feature.`GreetingCard`", "Feature_GreetingCard_PreviewProvider"),
        ("Feature.`Greeting Card`", "`Feature_Greeting Card_PreviewProvider`"),
        ("App.Feature.GreetingCard", "App_Feature_GreetingCard_PreviewProvider"),
        ("[GreetingCard]", "_x5B_GreetingCard_x5D__Previews"),
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

                struct \(structName): PreviewProvider {
                    static var previews: some View {
                        \(extendedType).autoPreview()
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("Counts an enclosing extension's extended type as part of a nested type's name")
    func expansionInsideExtension() {
        assertMacroExpansion(
            """
            extension App.Feature {
                @AutoPreview
                struct GreetingCard {
                }
            }
            """,
            expandedSource: """
            extension App.Feature {
                struct GreetingCard {

                    struct App_Feature_GreetingCard_PreviewProvider: PreviewProvider {
                        static var previews: some View {
                            GreetingCard.autoPreview()
                        }
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("Treats a type declared inside a function as top-level")
    func expansionOnLocalType() {
        assertMacroExpansion(
            """
            enum Feature {
                func makeView() {
                    @AutoPreview
                    struct GreetingCard {
                    }
                }
            }
            """,
            expandedSource: """
            enum Feature {
                func makeView() {
                    struct GreetingCard {
                    }

                    struct GreetingCard_Previews: PreviewProvider {
                        static var previews: some View {
                            GreetingCard.autoPreview()
                        }
                    }
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
