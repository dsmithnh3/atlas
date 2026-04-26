//
//  MapToolbar.swift
//  Atlas
//
//  Toolbar for the map pane: zoom level, filters, export, analyze
//

import SwiftUI

struct MapToolbar: View {
    @Binding var zoomLevel: SemanticZoomLevel
    @Binding var filterType: ConceptType?
    var graph: KnowledgeGraph
    var onExport: (ExportManager.ExportFormat) -> Void
    var onAnalyze: () -> Void
    var isAnalyzing: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Zoom level
            Menu {
                ForEach(SemanticZoomLevel.allCases, id: \.self) { level in
                    Button(level.displayName) { zoomLevel = level }
                }
            } label: {
                Label(zoomLevel.displayName, systemImage: "viewfinder")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 100)

            Divider().frame(height: 16)

            // Type filter
            Menu {
                Button("All Types") { filterType = nil }
                Divider()
                ForEach(ConceptType.allCases, id: \.self) { type in
                    Button {
                        filterType = type
                    } label: {
                        Label(type.displayName, systemImage: type.icon)
                    }
                }
            } label: {
                Label(filterType?.displayName ?? "Filter", systemImage: "line.3.horizontal.decrease")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 80)

            Divider().frame(height: 16)

            // Stats
            Text("\(graph.nodeCount) concepts")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // Export
            Menu {
                Button("Obsidian (Wikilinks)") { onExport(.obsidian) }
                Button("Markdown") { onExport(.markdown) }
                Button("JSON") { onExport(.json) }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .help("Export Knowledge Map")

            // Analyze
            Button(action: onAnalyze) {
                if isAnalyzing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "brain")
                        .font(.caption)
                }
            }
            .buttonStyle(.borderless)
            .disabled(isAnalyzing)
            .help("Analyze Document")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
