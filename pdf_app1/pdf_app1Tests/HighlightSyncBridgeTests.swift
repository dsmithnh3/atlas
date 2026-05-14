import XCTest
import PDFKit

@testable import pdf_app1

final class HighlightSyncBridgeTests: XCTestCase {

    private func makePageWithText(_ text: String) -> PDFPage? {
        let attributed = NSAttributedString(
            string: text,
            attributes: [.font: NSFont.systemFont(ofSize: 12)]
        )
        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: 612, height: 792)
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 540, height: 720))
        textView.textStorage?.setAttributedString(attributed)

        let data = NSMutableData()
        let printOp = NSPrintOperation(view: textView, printInfo: printInfo)
        printOp.showsPrintPanel = false
        printOp.showsProgressPanel = false

        // Use PDF representation from the view directly
        guard let pdfData = textView.dataWithPDF(inside: textView.bounds) as Data?,
              let doc = PDFDocument(data: pdfData),
              let page = doc.page(at: 0) else {
            return nil
        }
        return page
    }

    func testFindPassageRects_snippetNotFound_returnsNil() {
        let text = "Photosynthesis is the process by which plants convert sunlight into energy."
        guard let page = makePageWithText(text) else {
            XCTFail("Could not create test PDF page")
            return
        }

        let rects = HighlightSyncBridge.findPassageRects(snippet: "mitochondria powerhouse", on: page)

        XCTAssertNil(rects, "Should return nil when snippet is not on the page")
    }

    func testFindPassageRects_emptySnippet_returnsNil() {
        let text = "Some content on the page."
        guard let page = makePageWithText(text) else {
            XCTFail("Could not create test PDF page")
            return
        }

        let rects = HighlightSyncBridge.findPassageRects(snippet: "", on: page)

        XCTAssertNil(rects, "Should return nil for empty snippet")
    }

    func testFindPassageRects_snippetFound_returnsNonNilRects() {
        let text = "Photosynthesis is the process by which plants convert sunlight into energy."
        guard let page = makePageWithText(text) else {
            XCTFail("Could not create test PDF page")
            return
        }

        let rects = HighlightSyncBridge.findPassageRects(snippet: "plants convert sunlight", on: page)

        XCTAssertNotNil(rects, "Should find the snippet on the page")
        XCTAssertFalse(rects!.isEmpty, "Should return at least one rect")
        for rect in rects! {
            XCTAssertFalse(rect.isEmpty, "Each rect should be non-empty")
        }
    }

    func testFindPassageRects_multiLineSnippet_returnsMultipleRects() {
        let lines = (1...20).map { "Line \($0): This is filler text that extends the content across multiple lines in the PDF document." }
        let text = lines.joined(separator: " ")
        let snippet = "Line 5: This is filler text that extends the content across multiple lines in the PDF document. Line 6: This is filler text that extends the content across multiple lines in the PDF document."

        guard let page = makePageWithText(text) else {
            XCTFail("Could not create test PDF page")
            return
        }

        let rects = HighlightSyncBridge.findPassageRects(snippet: snippet, on: page)

        XCTAssertNotNil(rects, "Should find multi-line snippet")
        XCTAssertGreaterThan(rects!.count, 1, "Multi-line text should produce multiple rects")
    }

    func testFindPassageRects_caseInsensitive() {
        let text = "Photosynthesis is the process by which plants convert sunlight into energy."
        guard let page = makePageWithText(text) else {
            XCTFail("Could not create test PDF page")
            return
        }

        let rects = HighlightSyncBridge.findPassageRects(snippet: "PLANTS CONVERT SUNLIGHT", on: page)

        XCTAssertNotNil(rects, "Case-insensitive search should find the snippet")
    }
}
