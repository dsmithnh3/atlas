//
//  HighlightSyncBridge.swift
//  Atlas
//
//  Bridges PDF highlights/annotations with knowledge map nodes
//  Handles the source pulse animation when navigating from map to PDF
//

import Foundation
import PDFKit
import AppKit

class HighlightSyncBridge {

    /// Create a temporary pulse annotation on a PDF page to highlight the source passage
    func showSourcePulse(
        on pdfView: PDFView,
        page: PDFPage,
        boundingBox: CGRect,
        color: NSColor,
        duration: TimeInterval = AppConstants.sourcePulseDuration
    ) {
        // Create a temporary highlight annotation for the pulse
        let annotation = PDFAnnotation(bounds: boundingBox, forType: .highlight, withProperties: nil)
        annotation.color = color.withAlphaComponent(0.4)
        page.addAnnotation(annotation)

        // Navigate to the annotation
        let destination = PDFDestination(page: page, at: CGPoint(x: boundingBox.midX, y: boundingBox.midY))
        pdfView.go(to: destination)

        // Remove after pulse duration with fade
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            page.removeAnnotation(annotation)
            pdfView.setNeedsDisplay(pdfView.bounds)
        }
    }

    /// Navigate the PDF view to a source anchor and pulse
    func navigateAndPulse(
        pdfView: PDFView,
        anchor: SourceAnchor,
        nodeColor: NSColor = .systemBlue
    ) {
        guard let document = pdfView.document,
              anchor.pageIndex < document.pageCount,
              let page = document.page(at: anchor.pageIndex) else { return }

        showSourcePulse(
            on: pdfView,
            page: page,
            boundingBox: anchor.boundingBox,
            color: nodeColor
        )
    }

    /// When a PDF highlight is created, find and mark the corresponding map node
    func syncHighlightToMap(
        annotation: PDFAnnotation,
        page: PDFPage,
        document: PDFDocument,
        documentURL: URL,
        syncManager: BidirectionalSyncManager
    ) {
        let pageIndex = document.index(for: page)
        let bounds = annotation.bounds
        let text = annotation.contents ?? ""

        syncManager.onHighlightCreated(
            pageIndex: pageIndex,
            boundingBox: bounds,
            text: text
        )
    }
}
