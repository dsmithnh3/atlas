//
//  HierarchyForest.swift
//  Atlas
//
//  Canonical-parent forest derived from a graph's `.subtopicOf` edges and
//  `hierarchyLevel` markers. Used to seed `ForceDirectedLayout` so the
//  tree structure already present in the data shows up visually as bands
//  and clusters.
//

import Foundation

struct HierarchyForest {
    let roots: [UUID]
    let parentByChild: [UUID: UUID]
    let childrenByParent: [UUID: [UUID]]

    /// True if every node is its own root (no parent-child relationships).
    /// In this case tree seeding wouldn't help and the caller should
    /// fall back to grid layout.
    var isDegenerate: Bool { parentByChild.isEmpty }

    /// Walk up to the root for any node.
    func root(of nodeID: UUID) -> UUID {
        var current = nodeID
        var visited: Set<UUID> = []
        while let parent = parentByChild[current], visited.insert(current).inserted {
            current = parent
        }
        return current
    }
}

extension HierarchyForest {
    /// Build a forest from concept nodes + edges. Only `.subtopicOf` edges
    /// participate; non-concept nodes are excluded (entities cluster around
    /// their `parentConceptID` via FDL's existing parent-attraction, not
    /// in the concept tree).
    ///
    /// Canonical parent = first `.subtopicOf` target encountered, with two
    /// overrides: cycles are broken by skipping back-edges, and any node
    /// with `hierarchyLevel == 0` is forced to be a root (the LLM marker
    /// wins over edge noise).
    static func build(conceptNodes: [ConceptNode], edges: [GraphEdge]) -> HierarchyForest {
        let nodeIDs = Set(conceptNodes.map { $0.id })

        // child → ordered parent candidates from subtopicOf edges
        var parentCandidates: [UUID: [UUID]] = [:]
        for edge in edges where edge.type == .subtopicOf {
            guard nodeIDs.contains(edge.sourceNodeID),
                  nodeIDs.contains(edge.targetNodeID) else { continue }
            parentCandidates[edge.sourceNodeID, default: []].append(edge.targetNodeID)
        }

        // Deterministic node ordering (by UUID string) so tests are stable
        let orderedNodes = conceptNodes.sorted { $0.id.uuidString < $1.id.uuidString }

        var parentByChild: [UUID: UUID] = [:]
        for node in orderedNodes {
            // Level-0 markers are authoritative roots, even if subtopicOf edges exist
            if node.hierarchyLevel == 0 { continue }

            let candidates = parentCandidates[node.id] ?? []
            for candidate in candidates {
                if !wouldCreateCycle(from: node.id, to: candidate, parentByChild: parentByChild) {
                    parentByChild[node.id] = candidate
                    break
                }
            }
        }

        var childrenByParent: [UUID: [UUID]] = [:]
        for (child, parent) in parentByChild {
            childrenByParent[parent, default: []].append(child)
        }
        for parent in childrenByParent.keys {
            childrenByParent[parent]!.sort { $0.uuidString < $1.uuidString }
        }

        let roots = orderedNodes
            .map(\.id)
            .filter { parentByChild[$0] == nil }

        return HierarchyForest(
            roots: roots,
            parentByChild: parentByChild,
            childrenByParent: childrenByParent
        )
    }

    private static func wouldCreateCycle(
        from child: UUID,
        to parent: UUID,
        parentByChild: [UUID: UUID]
    ) -> Bool {
        var current: UUID? = parent
        var visited: Set<UUID> = []
        while let node = current {
            if node == child { return true }
            if !visited.insert(node).inserted { return true }
            current = parentByChild[node]
        }
        return false
    }
}
