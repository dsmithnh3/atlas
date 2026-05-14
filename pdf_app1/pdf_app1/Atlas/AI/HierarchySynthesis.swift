//
//  HierarchySynthesis.swift
//  Atlas
//
//  Deterministic post-extraction pass that ensures every concept graph
//  has a usable hierarchy: a handful of "themes" (hierarchyLevel: 0) and
//  `.subtopicOf` edges connecting non-themes to their nearest theme.
//
//  Runs after `ExtractionPipeline.processPages` finishes. Honors any
//  LLM-produced hierarchy (no-op when the existing subtopicOf edges
//  form a non-degenerate forest); synthesizes from graph topology when
//  the LLM didn't comply with the Novak prompt.
//

import Foundation
import os.log

private let log = Logger(subsystem: "com.atlas.pdf", category: "synthesis")

enum HierarchySynthesis {

    /// Mutates `graph` to add `hierarchyLevel: 0` markers on themes and
    /// `.subtopicOf` edges from each non-theme to its nearest theme.
    /// Idempotent — re-running on a synthesized graph is a no-op.
    static func synthesize(graph: KnowledgeGraph) {
        let conceptNodes = graph.allNodes.filter { $0.level == .concept && !$0.isDocumentSummary }

        // Tiny graphs stay flat — hierarchy adds no navigational value.
        guard conceptNodes.count >= 6 else {
            log.info("[Synthesis] skipped — only \(conceptNodes.count) concept(s), too small to need hierarchy")
            return
        }

        // Skip if the LLM already produced a usable forest. We trust the
        // existing tree completely rather than risk perturbing semantics
        // the LLM understood.
        let existingForest = HierarchyForest.build(conceptNodes: conceptNodes, edges: graph.allEdges)
        if !existingForest.isDegenerate {
            log.info("[Synthesis] skipped — LLM produced \(existingForest.parentByChild.count) subtopicOf edge(s) across \(existingForest.roots.count) root(s)")
            return
        }

        let k = desiredThemeCount(forConceptCount: conceptNodes.count)
        log.info("[Synthesis] running on \(conceptNodes.count) concept(s), picking \(k) theme(s)")

        // Pick themes by composite score (graph topology + multi-page presence).
        let scored = conceptNodes.map { (node: $0, score: themeScore(for: $0, in: graph)) }
        let themes = scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                // Stable tiebreaker so the same graph produces the same themes
                return lhs.node.id.uuidString < rhs.node.id.uuidString
            }
            .prefix(k)
            .map(\.node)
        let themeIDs = Set(themes.map(\.id))

        // Promote themes to hierarchyLevel 0
        for theme in themes {
            var updated = theme
            updated.hierarchyLevel = 0
            graph.updateNode(updated)
            log.info("[Synthesis] theme: \"\(theme.label)\" (score=\(themeScore(for: theme, in: graph)))")
        }

        // Build a non-containment adjacency map once for BFS efficiency
        let adjacency = buildAdjacency(for: conceptNodes, in: graph)

        // Assign each non-theme to its nearest theme via BFS over the
        // concept graph (entities/containment ignored).
        let nonThemes = conceptNodes.filter { !themeIDs.contains($0.id) }
        var connected = 0
        var orphans = 0
        for node in nonThemes {
            if let nearestTheme = nearestTheme(from: node.id, themes: themeIDs, adjacency: adjacency) {
                var updated = node
                if updated.hierarchyLevel == 0 {
                    // LLM marked this as level 0 too, but it didn't win a theme slot —
                    // demote so the synthesized edge makes sense.
                    updated.hierarchyLevel = 1
                }
                graph.updateNode(updated)

                let edge = GraphEdge(
                    sourceNodeID: node.id,
                    targetNodeID: nearestTheme,
                    type: .subtopicOf,
                    confidence: 0.7,
                    label: "synthesized"
                )
                graph.addEdge(edge)
                connected += 1
            } else {
                orphans += 1
            }
        }
        log.info("[Synthesis] connected \(connected) non-theme(s) via subtopicOf, \(orphans) orphan(s) left unparented")
    }

    // MARK: - Theme count

    /// Number of themes for a graph of N concepts. Sqrt-based: a 100-node
    /// graph gets 10 themes, a 400-node graph gets 15 (capped). Tunable.
    static func desiredThemeCount(forConceptCount n: Int) -> Int {
        let raw = Int(ceil(sqrt(Double(n))))
        return max(3, min(15, raw))
    }

    // MARK: - Theme scoring

    /// Higher = more theme-like. Weighted combination of:
    /// - generality in-degree: how many other concepts point at this one
    ///   via edges that imply generality (partOf, exampleOf, extends,
    ///   subtopicOf — those targets are more general than their sources).
    /// - total non-containment degree: central concepts have more links.
    /// - multi-page presence: themes typically span more of the document.
    /// - confidence: tiebreaker for borderline cases.
    static func themeScore(for node: ConceptNode, in graph: KnowledgeGraph) -> Double {
        let edges = graph.edges(for: node.id).filter { $0.type != .containsEntity }

        let generalityInDegree = edges.filter { edge in
            edge.targetNodeID == node.id &&
            [EdgeType.partOf, .subtopicOf, .exampleOf, .extends, .defines].contains(edge.type)
        }.count

        let totalDegree = edges.count
        let pageCount = Set(node.sourceAnchors.map { $0.pageIndex }).count

        return Double(generalityInDegree) * 3.0
            + Double(totalDegree) * 1.0
            + Double(pageCount) * 0.5
            + node.confidence * 1.0
    }

    // MARK: - Nearest theme via BFS

    /// Adjacency over concept-to-concept edges only (no containsEntity).
    /// Each entry maps a node to its neighbors regardless of edge direction —
    /// hierarchy synthesis is about topological proximity, not flow.
    private static func buildAdjacency(
        for concepts: [ConceptNode],
        in graph: KnowledgeGraph
    ) -> [UUID: [UUID]] {
        let conceptIDs = Set(concepts.map(\.id))
        var adjacency: [UUID: [UUID]] = [:]
        for concept in concepts { adjacency[concept.id] = [] }

        for edge in graph.allEdges {
            guard edge.type != .containsEntity else { continue }
            guard conceptIDs.contains(edge.sourceNodeID),
                  conceptIDs.contains(edge.targetNodeID) else { continue }
            adjacency[edge.sourceNodeID]?.append(edge.targetNodeID)
            adjacency[edge.targetNodeID]?.append(edge.sourceNodeID)
        }
        return adjacency
    }

    private static func nearestTheme(
        from start: UUID,
        themes: Set<UUID>,
        adjacency: [UUID: [UUID]]
    ) -> UUID? {
        if themes.contains(start) { return start }

        var visited: Set<UUID> = [start]
        var queue: [UUID] = [start]

        while !queue.isEmpty {
            let current = queue.removeFirst()
            for neighbor in adjacency[current] ?? [] {
                if !visited.insert(neighbor).inserted { continue }
                if themes.contains(neighbor) { return neighbor }
                queue.append(neighbor)
            }
        }
        return nil
    }
}
