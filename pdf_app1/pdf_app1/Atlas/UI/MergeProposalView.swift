//
//  MergeProposalView.swift
//  Atlas
//
//  UI for reviewing and accepting/rejecting concept merge proposals
//

import SwiftUI

struct MergeProposalView: View {
    let proposals: [MergeProposal]
    var graph: KnowledgeGraph
    let mergeEngine: GraphMergeEngine
    var onDismiss: () -> Void

    @State private var processedIDs: Set<UUID> = []

    var pendingProposals: [MergeProposal] {
        proposals.filter { !processedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Merge Proposals")
                    .font(.headline)
                Spacer()
                Text("\(pendingProposals.count) remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Dismiss") { onDismiss() }
                    .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            if pendingProposals.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("All proposals reviewed")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(pendingProposals) { proposal in
                            MergeProposalRow(
                                proposal: proposal,
                                onAccept: {
                                    mergeEngine.executeMerge(
                                        sourceNodeID: proposal.sourceNode.id,
                                        targetNodeID: proposal.targetNode.id,
                                        in: graph
                                    )
                                    processedIDs.insert(proposal.id)
                                },
                                onReject: {
                                    processedIDs.insert(proposal.id)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MergeProposalRow: View {
    let proposal: MergeProposal
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    nodeLabel(proposal.sourceNode)
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    nodeLabel(proposal.targetNode)
                }

                Text(proposal.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Similarity: \(Int(proposal.similarity * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Button("Merge") { onAccept() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                Button("Skip") { onReject() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func nodeLabel(_ node: ConceptNode) -> some View {
        HStack(spacing: 4) {
            Image(systemName: node.type.icon)
                .font(.caption)
                .foregroundColor(node.type.color)
            Text(node.label)
                .font(.callout)
                .lineLimit(1)
        }
    }
}
