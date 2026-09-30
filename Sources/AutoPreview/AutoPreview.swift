/// Generates previews for a type conforming to `AutoPreviewable`.
///
/// Usage:
///
///     #AutoPreview(MyView.self)
///
/// expands to exactly one of the following, chosen by the Swift language
/// version the `AutoPreviewMacros` compiler plugin itself was built
/// with — never both, and never with an `#if` left in the expanded code.
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
/// The `T: AutoPreviewable` constraint means the compiler rejects
/// `#AutoPreview(SomeUnrelatedType.self)` before the macro
/// even expands.
@freestanding(declaration, names: suffixed(_Previews))
public macro AutoPreview<T: AutoPreviewable>(_ type: T.Type) =
    #externalMacro(
        module: "AutoPreviewMacros",
        type: "AutoPreviewMacro"
    )
