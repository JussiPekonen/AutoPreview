/// Generates previews for a type conforming to `AutoPreviewable`.
///
/// Usage:
///
///     @AutoPreview
///     struct MyView: View, AutoPreviewable {
///         ...
///     }
///
/// expands — as a peer declaration alongside `MyView`, in the same scope,
/// never inlined into its body — to exactly one of the following, chosen
/// by the Swift language version the `AutoPreviewMacros` compiler plugin
/// itself was built with:
///
/// On Swift 6.4 or newer:
///
///     #Preview("MyView", arguments: MyView.previewData) { item in
///         MyView.previewBuilder(data: item.data)
///     }
///
/// Below Swift 6.4:
///
///     struct MyView_Previews: PreviewProvider {
///         static var previews: some View {
///             MyView.autoPreview()
///         }
///     }
///
/// `@AutoPreview` can be attached to any struct, class, enum, or actor
/// declaration — or to an `extension` declaring the type's
/// `AutoPreviewable` conformance instead, if that's where
/// `previewData`/`previewBuilder(data:)` are actually implemented:
///
///     @AutoPreview
///     extension MyView: AutoPreviewable {
///         ...
///     }
///
/// Unlike a freestanding macro, an attached one has no generic parameter
/// to additionally constrain to `AutoPreviewable` — attaching it to a
/// type (or extension) that doesn't conform simply fails to compile once
/// the generated code above references
/// `previewData`/`previewBuilder(data:)` on it.
@attached(peer, names: suffixed(_Previews))
public macro AutoPreview() =
    #externalMacro(
        module: "AutoPreviewMacros",
        type: "AutoPreviewMacro"
    )
