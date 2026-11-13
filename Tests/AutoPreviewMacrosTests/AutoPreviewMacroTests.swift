import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import AutoPreviewMacros

// `AutoPreviewMacro`'s own `#if swift(>=6.4)` is compiled against *this
// test target's own* Swift toolchain — the same one running these tests —
// so which expansion it produces is a compile-time fact here too, not
// something a single test body can branch on at runtime. These two test
// types mirror that gate: whichever one matches the compiling toolchain
// is the one that actually gets built and run.

#if swift(>=6.4)

@Suite("AutoPreviewMacro (Swift 6.4+)")
struct AutoPreviewMacroTests {
    private let testMacros: [String: Macro.Type] = [
        "AutoPreview": AutoPreviewMacro.self
    ]

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

    @Test("Titles a raw-identifier type's previews without its backticks")
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

            #Preview("Greeting Card", arguments: `Greeting Card`.previewData) { item in
                `Greeting Card`.previewBuilder(data: item.data)
            }
            """,
            macros: testMacros
        )
    }

    @Test("Titles an extension of a backtick-qualified type without its backticks")
    func expansionOnBacktickedExtension() {
        assertMacroExpansion(
            """
            @AutoPreview
            extension Feature.`Greeting Card`: AutoPreviewable {
            }
            """,
            expandedSource: """
            extension Feature.`Greeting Card`: AutoPreviewable {
            }

            #Preview("Feature.Greeting Card", arguments: Feature.`Greeting Card`.previewData) { item in
                Feature.`Greeting Card`.previewBuilder(data: item.data)
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

#else

@Suite("AutoPreviewMacro (pre-6.4 fallback)")
struct AutoPreviewMacroTests {
    private let testMacros: [String: Macro.Type] = [
        "AutoPreview": AutoPreviewMacro.self
    ]

    @Test("Expands to the legacy PreviewProvider form as a peer declaration on this toolchain")
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

            struct GreetingCard_Previews: PreviewProvider {
                static var previews: some View {
                    GreetingCard.autoPreview()
                }
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

            struct __macro_local_33Feature_x2E_GreetingCard_PreviewsfMu_: PreviewProvider {
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

#endif
