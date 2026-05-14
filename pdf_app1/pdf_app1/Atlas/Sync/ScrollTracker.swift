//
//  ScrollTracker.swift
//  Atlas
//
//  Monitors visible PDF pages and notifies the sync manager
//

import Foundation
import PDFKit
import Combine

class ScrollTracker {
    private var cancellables = Set<AnyCancellable>()
    private weak var syncManager: BidirectionalSyncManager?

    init(syncManager: BidirectionalSyncManager) {
        self.syncManager = syncManager
    }

    /// Start observing page changes on a PDFView
    func observe(pdfView: PDFView) {
        // .PDFViewPageChanged fires whenever PDFView.currentPage changes —
        // the canonical "active page changed" signal in any display mode.
        // .PDFViewVisiblePagesChanged previously fired in parallel here,
        // but in .singlePageContinuous it duplicated this signal at a
        // slower debounce (200ms vs 100ms) and triggered redundant
        // updateActiveNode → @Observable churn downstream.
        NotificationCenter.default.publisher(for: .PDFViewPageChanged, object: pdfView)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] notification in
                guard let pdfView = notification.object as? PDFView,
                      let currentPage = pdfView.currentPage,
                      let document = pdfView.document else { return }

                let pageIndex = document.index(for: currentPage)
                self?.syncManager?.onPageChanged(pageIndex: pageIndex)
            }
            .store(in: &cancellables)
    }

    /// Stop observing
    func stopObserving() {
        cancellables.removeAll()
    }
}
