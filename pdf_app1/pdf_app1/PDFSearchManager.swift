//
//  PDFSearchManager.swift
//  PDFViewer
//
//  Manages PDF text search functionality
//

import Foundation
import PDFKit
import Combine

/// Manages PDF search operations
class PDFSearchManager: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [PDFSelection] = []
    @Published var currentSearchIndex: Int = -1
    @Published var isSearching: Bool = false
    @Published var searchHistory: [String] = []
    
    private var document: PDFDocument?
    private let searchHistoryKey = "PDFSearchHistory"
    private let maxHistoryCount = 10

    init() {
        loadHistory()
    }
    
    /// Set the document to search
    func setDocument(_ document: PDFDocument) {
        self.document = document
        clearSearch()
    }
    
    /// Perform search in the document
    /// Note: PDFKit's findString only finds the first occurrence.
    /// For a complete "find all" implementation, we use a workaround by
    /// searching page by page using the document's string content.
    func performSearch(_ text: String, in document: PDFDocument) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearSearch()
            return
        }

        addToHistory(trimmed)
        
        isSearching = true
        searchText = trimmed

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // PDFKit already returns all occurrences (on macOS). The previous implementation
            // re-ran findString repeatedly inside loops, which was extremely expensive.
            let selections = document.findString(trimmed, withOptions: .caseInsensitive)

            var uniqueResults: [PDFSelection] = []
            uniqueResults.reserveCapacity(min(selections.count, 200))
            var seenIdentifiers: Set<String> = []
            seenIdentifiers.reserveCapacity(min(selections.count, 200))

            for selection in selections {
                guard let page = selection.pages.first else { continue }
                let identifier = self?.createSelectionIdentifier(selection: selection, page: page, document: document) ?? ""
                if identifier.isEmpty { continue }
                if seenIdentifiers.insert(identifier).inserted {
                    uniqueResults.append(selection)
                    if uniqueResults.count >= 200 { break }
                }
            }

            uniqueResults.sort { sel1, sel2 in
                guard let page1 = sel1.pages.first,
                      let page2 = sel2.pages.first else { return false }
                let idx1 = document.index(for: page1)
                let idx2 = document.index(for: page2)
                if idx1 != idx2 {
                    return idx1 < idx2
                }
                let bounds1 = sel1.bounds(for: page1)
                let bounds2 = sel2.bounds(for: page2)
                return bounds1.origin.y > bounds2.origin.y
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.searchResults = uniqueResults
                self.currentSearchIndex = uniqueResults.isEmpty ? -1 : 0
                self.isSearching = false
            }
        }
    }

    private func addToHistory(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let existingIndex = searchHistory.firstIndex { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        if let existingIndex {
            searchHistory.remove(at: existingIndex)
        }
        searchHistory.insert(trimmed, at: 0)
        if searchHistory.count > maxHistoryCount {
            searchHistory = Array(searchHistory.prefix(maxHistoryCount))
        }
        saveHistory()
    }

    func clearHistory() {
        searchHistory.removeAll()
        saveHistory()
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: searchHistoryKey),
              let history = try? JSONDecoder().decode([String].self, from: data) else {
            searchHistory = []
            return
        }
        searchHistory = history
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(searchHistory) else { return }
        UserDefaults.standard.set(data, forKey: searchHistoryKey)
    }
    
    /// Create a unique identifier for a selection to avoid duplicates
    private func createSelectionIdentifier(selection: PDFSelection, page: PDFPage, document: PDFDocument) -> String {
        let pageIndex = document.index(for: page)
        let bounds = selection.bounds(for: page)
        return "\(pageIndex)-\(bounds.origin.x)-\(bounds.origin.y)-\(bounds.width)-\(bounds.height)"
    }
    
    /// Navigate to next search result
    func nextResult() -> PDFSelection? {
        guard !searchResults.isEmpty else { return nil }
        currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
        return searchResults[currentSearchIndex]
    }
    
    /// Navigate to previous search result
    func previousResult() -> PDFSelection? {
        guard !searchResults.isEmpty else { return nil }
        currentSearchIndex = currentSearchIndex <= 0 ? searchResults.count - 1 : currentSearchIndex - 1
        return searchResults[currentSearchIndex]
    }
    
    /// Clear search results
    func clearSearch() {
        searchText = ""
        searchResults.removeAll()
        currentSearchIndex = -1
        isSearching = false
    }
    
    /// Get current search result
    var currentResult: PDFSelection? {
        guard currentSearchIndex >= 0 && currentSearchIndex < searchResults.count else {
            return nil
        }
        return searchResults[currentSearchIndex]
    }
}
