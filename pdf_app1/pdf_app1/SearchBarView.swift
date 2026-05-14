//
//  SearchBarView.swift
//  PDFViewer
//
//  Search bar for PDF text search
//

import SwiftUI
import PDFKit

struct SearchBarView: View {
    @ObservedObject var searchManager: PDFSearchManager
    let pdfView: PDFView
    @Binding var isPresented: Bool
    @State private var searchText: String = ""
    // `searchText` stays bound to the TextField for responsive input.
    // `debouncedSearchText` lags by 250ms (instant when cleared) and
    // drives the actual search, matching macOS-native search bars and
    // the project's other debounced search fields (map search, file
    // search). `.onSubmit` bypasses the debounce for power users who
    // hit Enter.
    @State private var debouncedSearchText: String = ""

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search in PDF", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        performSearch()
                    }
                    .task(id: searchText) {
                        if searchText.isEmpty {
                            debouncedSearchText = ""
                            return
                        }
                        try? await Task.sleep(for: .milliseconds(250))
                        if Task.isCancelled { return }
                        debouncedSearchText = searchText
                    }
                    .onChange(of: debouncedSearchText) { _, newValue in
                        if newValue.isEmpty {
                            searchManager.clearSearch()
                            clearHighlights()
                        } else {
                            performSearch()
                        }
                    }

                Menu {
                    if searchManager.searchHistory.isEmpty {
                        Text("No recent searches")
                    } else {
                        ForEach(searchManager.searchHistory, id: \.self) { term in
                            Button(term) {
                                searchText = term
                                performSearch()
                            }
                        }
                        Divider()
                        Button("Clear History") {
                            searchManager.clearHistory()
                        }
                    }
                } label: {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .help("Search History")
                
                if !searchManager.searchResults.isEmpty {
                    Text("\(searchManager.currentSearchIndex + 1) of \(searchManager.searchResults.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        navigateToPrevious()
                    }) {
                        Image(systemName: "chevron.up")
                    }
                    .help("Previous")
                    
                    Button(action: {
                        navigateToNext()
                    }) {
                        Image(systemName: "chevron.down")
                    }
                    .help("Next")
                }
                
                Button(action: {
                    searchManager.clearSearch()
                    clearHighlights()
                    searchText = ""
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(radius: 4)
            )
        }
        .frame(width: 400)
    }
    
    private func performSearch() {
        guard !searchText.isEmpty, let document = pdfView.document else { return }
        searchManager.performSearch(searchText, in: document)
        highlightSearchResults()
        if let firstResult = searchManager.currentResult {
            navigateToSelection(firstResult)
        }
    }
    
    private func navigateToNext() {
        if let selection = searchManager.nextResult() {
            navigateToSelection(selection)
            highlightSearchResults()
        }
    }
    
    private func navigateToPrevious() {
        if let selection = searchManager.previousResult() {
            navigateToSelection(selection)
            highlightSearchResults()
        }
    }
    
    private func navigateToSelection(_ selection: PDFSelection) {
        pdfView.go(to: selection)
        pdfView.highlightedSelections = [selection]
    }
    
    private func highlightSearchResults() {
        pdfView.highlightedSelections = searchManager.searchResults
    }
    
    private func clearHighlights() {
        pdfView.highlightedSelections = []
    }
}
