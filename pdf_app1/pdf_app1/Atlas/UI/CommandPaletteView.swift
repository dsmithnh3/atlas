//
//  CommandPaletteView.swift
//  Atlas
//
//  Cmd+K command palette for jumping to concepts, pages, or projects
//

import SwiftUI

struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    var graph: KnowledgeGraph
    var onSelectNode: (UUID) -> Void
    var onNavigateToPage: (Int) -> Void

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool

    private var results: [PaletteResult] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()

        var items: [PaletteResult] = []

        // Search concepts
        for node in graph.allNodes {
            if node.label.lowercased().contains(lowered) {
                items.append(PaletteResult(
                    id: node.id.uuidString,
                    icon: node.type.icon,
                    title: node.label,
                    subtitle: node.summary ?? node.type.displayName,
                    action: .navigateToNode(node.id)
                ))
            }
        }

        // Search by page number
        if let pageNum = Int(query) {
            items.append(PaletteResult(
                id: "page_\(pageNum)",
                icon: "doc.text",
                title: "Go to Page \(pageNum)",
                subtitle: "Navigate to page \(pageNum)",
                action: .navigateToPage(pageNum - 1)
            ))
        }

        return Array(items.prefix(20)) // Limit results
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search concepts, pages...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isSearchFocused)
                    .onSubmit { executeSelected() }

                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)

            Divider()

            // Results
            if results.isEmpty && !query.isEmpty {
                Text("No results")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                            PaletteResultRow(
                                result: result,
                                isSelected: index == selectedIndex
                            )
                            .onTapGesture {
                                execute(result)
                            }
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 500)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        )
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(0, selectedIndex - 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectedIndex = min(results.count - 1, selectedIndex + 1)
            return .handled
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }

    private func executeSelected() {
        guard selectedIndex < results.count else { return }
        execute(results[selectedIndex])
    }

    private func execute(_ result: PaletteResult) {
        switch result.action {
        case .navigateToNode(let id):
            onSelectNode(id)
        case .navigateToPage(let page):
            onNavigateToPage(page)
        }
        isPresented = false
    }
}

// MARK: - Palette Result

struct PaletteResult: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let action: PaletteAction
}

enum PaletteAction {
    case navigateToNode(UUID)
    case navigateToPage(Int)
}

struct PaletteResultRow: View {
    let result: PaletteResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: result.icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.body)
                    .lineLimit(1)
                Text(result.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}
