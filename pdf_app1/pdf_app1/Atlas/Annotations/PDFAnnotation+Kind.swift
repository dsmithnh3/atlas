import PDFKit

// PDFKit's `PDFAnnotation.type` getter strips the leading slash from the
// raw subtype name ("Highlight"), while `PDFAnnotationSubtype.rawValue`
// retains it ("/Highlight"). This asymmetry makes direct comparison
// awkward. These helpers normalize on PDFAnnotationSubtype so that one
// set of typed constants drives both the write-side
// (`PDFAnnotation(bounds:forType:.highlight,...)`) and the read-side
// (`annotation.isKind(.highlight)`).
extension PDFAnnotation {
    var atlasSubtype: PDFAnnotationSubtype? {
        guard let type else { return nil }
        return PDFAnnotationSubtype(rawValue: type.hasPrefix("/") ? type : "/\(type)")
    }

    func isKind(_ subtype: PDFAnnotationSubtype) -> Bool {
        atlasSubtype == subtype
    }
}
