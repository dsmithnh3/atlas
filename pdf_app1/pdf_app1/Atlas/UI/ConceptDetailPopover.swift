//
//  ConceptDetailPopover.swift
//  Atlas
//
//  Popover showing concept details: summary, source passages, connected edges
//

import SwiftUI

struct ConceptDetailPopover: View {
    let node: ConceptNode
    var graph: KnowledgeGraph
    var onNavigateToSource: (SourceAnchor) -> Void
    var onPin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: node.type.icon)
                    .foregroundColor(node.type.color)
                Text(node.label)
                    .font(.headline)
                Spacer()
                confidenceBadge
            }

            // Type badge
            Text(node.type.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(node.type.color.opacity(0.15)))
                .foregroundColor(node.type.color)

            // Summary
            if let summary = node.summary {
                Text(summary)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Source passages
            if !node.sourceAnchors.isEmpty {
                Text("Sources (\(node.sourceAnchors.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(node.sourceAnchors) { anchor in
                    Button(action: { onNavigateToSource(anchor) }) {
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.caption)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(anchor.documentURL.lastPathComponent)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text("Page \(anchor.pageIndex + 1)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                if !anchor.textSnippet.isEmpty {
                                    Text(anchor.textSnippet)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
            }

            // Connected edges
            let edges = graph.edges(for: node.id)
            if !edges.isEmpty {
                Divider()

                Text("Connections (\(edges.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(edges) { edge in
                    let otherNodeID = edge.sourceNodeID == node.id ? edge.targetNodeID : edge.sourceNodeID
                    if let otherNode = graph.node(for: otherNodeID) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(edge.type.color)
                                .frame(width: 6, height: 6)
                            Text(edge.type.displayName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(otherNode.label)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Divider()

            // Actions
            HStack {
                Button(action: onPin) {
                    Label(node.isPinned ? "Unpin" : "Pin", systemImage: node.isPinned ? "pin.slash" : "pin")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Text("Confidence: \(Int(node.confidence * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 320)
    }

    private var confidenceBadge: some View {
        Group {
            if node.confidence < 0.6 {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .font(.caption)
                    .help("Low confidence extraction")
            } else if node.confidence > 0.9 {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
    }
}
