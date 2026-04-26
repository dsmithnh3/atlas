//
//  BidirectionalSyncManager.swift
//  Atlas
//
//  Coordinates bidirectional sync between PDF viewer and knowledge map:
//  - PDF scroll → active node highlights on map
//  - Map node click → PDF jumps to source passage with pulse
//

import Foundation
import PDFKit
import Observation

@Observable
class BidirectionalSyncManager {
    /// Currently active node (matches visible PDF page)
    var activeNodeID: UUID?

    /// When set, the PDF view should navigate to this anchor and pulse
    var pendingNavigationAnchor: SourceAnchor?

    /// Current visible page index in the PDF
    var currentPageIndex: Int = 0

    /// Document URL being viewed
    var documentURL: URL?

    /// Callback for the PDF view to navigate to a destination
    var navigateToPDFPage: ((Int, CGRect?) -> Void)?

    private weak var graph: KnowledgeGraph?

    func setGraph(_ graph: KnowledgeGraph) {
        self.graph = graph
    }

    func setDocumentURL(_ url: URL?) {
        self.documentURL = url
    }

    // MARK: - PDF → Map Sync

    /// Called when the user scrolls to a new page in the PDF
    func onPageChanged(pageIndex: Int) {
        currentPageIndex = pageIndex
        updateActiveNode()
    }

    /// Find the most relevant node for the current page
    private func updateActiveNode() {
        guard let graph, let documentURL else {
            activeNodeID = nil
            return
        }

        let pageNodes = graph.nodes(forPage: currentPageIndex, in: documentURL)

        if let firstNode = pageNodes.first {
            activeNodeID = firstNode.id
        } else {
            // Try adjacent pages
            let nearbyNodes = graph.allNodes.filter { node in
                node.sourceAnchors.contains { anchor in
                    anchor.documentURL == documentURL
                    && abs(anchor.pageIndex - currentPageIndex) <= 1
                }
            }
            activeNodeID = nearbyNodes.first?.id
        }
    }

    // MARK: - Map → PDF Sync

    /// Called when the user clicks a node on the map
    func navigateToNode(_ nodeID: UUID) {
        guard let graph, let node = graph.node(for: nodeID) else { return }

        // Find the best source anchor for the current document
        let anchor: SourceAnchor?
        if let docURL = documentURL {
            anchor = node.sourceAnchors.first { $0.documentURL == docURL }
                ?? node.sourceAnchors.first
        } else {
            anchor = node.sourceAnchors.first
        }

        guard let sourceAnchor = anchor else { return }

        pendingNavigationAnchor = sourceAnchor
        navigateToPDFPage?(sourceAnchor.pageIndex, sourceAnchor.boundingBox)

        // Clear pending after a short delay (pulse animation duration)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(AppConstants.sourcePulseDuration * 1000)))
            pendingNavigationAnchor = nil
        }
    }

    // MARK: - Highlight Sync

    /// Called when the user highlights text in the PDF
    func onHighlightCreated(pageIndex: Int, boundingBox: CGRect, text: String) {
        guard let graph, let documentURL else { return }

        // Find the node that matches this highlight region
        let matchingNodes = graph.nodes(forPage: pageIndex, in: documentURL)

        for var node in matchingNodes {
            // Check if the highlight overlaps with the node's source anchors
            let overlaps = node.sourceAnchors.contains { anchor in
                anchor.pageIndex == pageIndex && anchor.boundingBox.intersects(boundingBox)
            }

            if overlaps {
                node.readingState = .highlighted
                node.isPinned = true
                graph.updateNode(node)
            }
        }
    }

    /// Called when the user annotates in the PDF
    func onAnnotationCreated(pageIndex: Int, text: String) {
        guard let graph, let documentURL else { return }

        let matchingNodes = graph.nodes(forPage: pageIndex, in: documentURL)
        for var node in matchingNodes {
            node.readingState = .annotated
            graph.updateNode(node)
        }
    }
}
