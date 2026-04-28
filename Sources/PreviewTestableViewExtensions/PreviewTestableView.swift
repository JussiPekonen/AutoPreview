import SwiftUI

public protocol PreviewTestableView {
    associatedtype PTD
    associatedtype PV: View

    /// Preview data for the View. A `[String: PTD]` map where
    /// - `key` is the "name" of the preview data and
    /// - `value` is the data to the set for the preview data.
    /// `PTD` is a generic class that 
    static var previewData: [String: PTD] { get }

    /// Preview builder function that takes a
    @ViewBuilder
    static func previewBuilder(_ data: PTD) -> PV
}

extension PreviewTestableView {
    @ViewBuilder
    public static func generatePreviews() -> some View {
        let viewIdentifier = String(describing: Self.self)
        let keys = Self.previewData.keys.sorted()
        ForEach(keys, id: \.self) { key in
            if let data = Self.previewData[key] {
                Self.previewBuilder(data)
                    .previewDisplayName("\(viewIdentifier) / \(key)")
            }
        }

    }
}


