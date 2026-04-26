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
        // Observe page change notifications
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

        // Observe visible pages change (for continuous scroll modes)
        NotificationCenter.default.publisher(for: .PDFViewVisiblePagesChanged, object: pdfView)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
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
