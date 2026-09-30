import SwiftParser
import Testing

@testable import TestablePreviewsGenerator

@Suite("AutoPreviewableConformanceCollector")
struct AutoPreviewableConformanceCollectorTests {
    private func collect(_ source: String) -> [AutoPreviewableConformanceCollector.Conformance] {
        let tree = Parser.parse(source: source)
        let collector = AutoPreviewableConformanceCollector()
        collector.walk(tree)
        return collector.discoveredConformances
    }

    @Test("Finds a top-level conforming struct")
    func topLevelStruct() {
        let conformances = collect(
            """
            struct GreetingCard: View, AutoPreviewable {
                var body: some View { EmptyView() }
            }
            """
        )
        #expect(conformances.map(\.simpleName) == ["GreetingCard"])
        #expect(conformances.map(\.qualifiedName) == ["GreetingCard"])
    }

    @Test("Finds conformance declared via a separate extension")
    func conformanceViaExtension() {
        let conformances = collect(
            """
            struct GreetingCard: View {
                var body: some View { EmptyView() }
            }

            extension GreetingCard: AutoPreviewable {
                static var previewData: [String: String] { [:] }
                static func previewBuilder(data: String) -> some View { EmptyView() }
            }
            """
        )
        #expect(conformances.map(\.simpleName) == ["GreetingCard"])
        #expect(conformances.map(\.qualifiedName) == ["GreetingCard"])
    }

    @Test("Reports the fully namespaced name for a nested conforming type")
    func nestedTypeGetsQualifiedName() {
        let conformances = collect(
            """
            enum Feature {
                struct GreetingCard: AutoPreviewable {
                    static var previewData: [String: String] { [:] }
                    static func previewBuilder(data: String) -> some View { EmptyView() }
                }
            }
            """
        )
        #expect(conformances.map(\.simpleName) == ["GreetingCard"])
        #expect(conformances.map(\.qualifiedName) == ["Feature.GreetingCard"])
    }

    @Test("Ignores types that don't conform")
    func nonConformingTypeIsIgnored() {
        let conformances = collect(
            """
            struct PlainView: View {
                var body: some View { EmptyView() }
            }
            """
        )
        #expect(conformances.isEmpty)
    }

    @Test("Finds multiple conforming types across classes, enums, and actors")
    func multipleKindsOfDeclarations() {
        let conformances = collect(
            """
            struct StructView: AutoPreviewable {}
            class ClassView: AutoPreviewable {}
            enum EnumView: AutoPreviewable {}
            actor ActorView: AutoPreviewable {}
            """
        )
        #expect(Set(conformances.map(\.simpleName)) == ["StructView", "ClassView", "EnumView", "ActorView"])
    }
}

@Suite("GeneratedSourceBuilder")
struct GeneratedSourceBuilderTests {
    @Test("Renders a resolveTestPreview that always returns nil when nothing was found")
    func emptyConformances() {
        let source = GeneratedSourceBuilder.makeSource(conformingTypeNames: [])
        #expect(source.contains("import AutoPreview"))
        #expect(source.contains("final class TestablePreviews"))
        #expect(source.contains("static func setContent("))
        #expect(source.contains("private static func resolveTestPreview(viewTag: String, dataTag: String) -> AnyView? {"))
        #expect(source.contains("return nil"))
        #expect(!source.contains("switch viewTag"))
    }

    @Test("Renders a switch case that looks up each conforming type's own previewData by name")
    func nonEmptyConformances() {
        let source = GeneratedSourceBuilder.makeSource(conformingTypeNames: ["Feature.GreetingCard"])
        #expect(source.contains(#"case "Feature.GreetingCard":"#))
        #expect(source.contains(
            "Feature.GreetingCard.previewData.first(where: { $0.description == dataTag })?.data"
        ))
        #expect(source.contains("return AnyView(Feature.GreetingCard.previewBuilder(data: data))"))
    }

    @Test("Deduplicates repeated names into a single switch case")
    func duplicateNamesAreDeduplicated() {
        let source = GeneratedSourceBuilder.makeSource(conformingTypeNames: ["GreetingCard", "GreetingCard"])
        let occurrences = source.components(separatedBy: #"case "GreetingCard":"#).count - 1
        #expect(occurrences == 1)
    }

    @Test("Escapes quotes and backslashes in the switch case label defensively")
    func escapesSpecialCharacters() {
        let source = GeneratedSourceBuilder.makeSource(conformingTypeNames: [#"Weird"Name"#])
        // The generated case label should read `case "Weird\"Name":` — i.e.
        // the embedded quote is backslash-escaped rather than breaking the
        // literal. The value side (`Weird"Name.previewData`, etc.) is raw
        // Swift code, not a string, so it isn't escaped the same way.
        #expect(source.contains(#""Weird\"Name""#))
    }
}
