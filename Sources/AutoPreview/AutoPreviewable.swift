import SwiftUI

public protocol AutoPreviewable {
    associatedtype APTD
    associatedtype APV: View

    /// Preview data for the View. An array of named data stubs, where
    /// each `PreviewData`'s `description` is the "name" of that preview
    /// and `data` is the value to set for it.
    /// `APTD` is a generic class that provides preview test data
    static var previewData: [PreviewData<APTD>] { get }

    /// Preview builder function that takes a
    @ViewBuilder
    static func previewBuilder(data: APTD) -> APV
}

public struct PreviewData<APTD>: CustomStringConvertible {
    public let description: String
    public let data: APTD

    public init(_ description: String, _ data: APTD) {
        self.description = description
        self.data = data
    }
}

extension AutoPreviewable {
    @ViewBuilder
    public static func autoPreview() -> some View {
        let viewIdentifier = String(describing: Self.self)
        ForEach(Self.previewData, id: \.description) { item in
            Self.previewBuilder(data: item.data)
                .previewDisplayName("\(viewIdentifier) / \(item.description)")
        }
    }
}
