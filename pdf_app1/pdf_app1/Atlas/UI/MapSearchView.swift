//
//  MapSearchView.swift
//  Atlas
//
//  Search bar for the knowledge map pane
//

import SwiftUI

struct MapSearchView: View {
    var graph: KnowledgeGraph
    @Binding var selectedNodeID: UUID?
    var onNavigateToNode: (UUID) -> Void

    @State private var searchText: String = ""
    @State private var searchResults: [ConceptNode] = []
    @State private var currentResultIndex: Int = 0
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search concepts...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.callout)
                .focused($isSearchFocused)
                .onChange(of: searchText) { _, newValue in
                    performSearch(query: newValue)
                }
                .onSubmit {
                    navigateToNextResult()
                }

            if !searchResults.isEmpty {
                Text("\(currentResultIndex + 1)/\(searchResults.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: { navigateToPreviousResult() }) {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Button(action: { navigateToNextResult() }) {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            if !searchText.isEmpty {
                Button(action: { clearSearch() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
        )
    }

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        let lowered = query.lowercased()
        searchResults = graph.allNodes.filter { node in
            node.label.lowercased().contains(lowered)
            || (node.summary?.lowercased().contains(lowered) ?? false)
            || node.sourceAnchors.contains { $0.textSnippet.lowercased().contains(lowered) }
        }

        currentResultIndex = 0
        if let first = searchResults.first {
            selectedNodeID = first.id
        }
    }

    private func navigateToNextResult() {
        guard !searchResults.isEmpty else { return }
        currentResultIndex = (currentResultIndex + 1) % searchResults.count
        let node = searchResults[currentResultIndex]
        selectedNodeID = node.id
        onNavigateToNode(node.id)
    }

    private func navigateToPreviousResult() {
        guard !searchResults.isEmpty else { return }
        currentResultIndex = currentResultIndex > 0 ? currentResultIndex - 1 : searchResults.count - 1
        let node = searchResults[currentResultIndex]
        selectedNodeID = node.id
        onNavigateToNode(node.id)
    }

    private func clearSearch() {
        searchText = ""
        searchResults = []
        selectedNodeID = nil
    }
}
