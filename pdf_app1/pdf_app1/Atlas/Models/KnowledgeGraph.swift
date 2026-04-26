//
//  KnowledgeGraph.swift
//  Atlas
//
//  Core knowledge graph model containing concepts, edges, and source anchors
//

import SwiftUI
import PDFKit
import Observation
import os.log

private let log = Logger(subsystem: "com.atlas.pdf", category: "graph")

// MARK: - Source Anchor
struct SourceAnchor: Identifiable, Codable, Hashable {
    let id: UUID
    let documentURL: URL
    let pageIndex: Int
    let boundingBox: CGRect
    let textSnippet: String

    init(id: UUID = UUID(), documentURL: URL, pageIndex: Int, boundingBox: CGRect, textSnippet: String) {
        self.id = id
        self.documentURL = documentURL
        self.pageIndex = pageIndex
        self.boundingBox = boundingBox
        self.textSnippet = textSnippet
    }
}

// MARK: - Concept Node
struct ConceptNode: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String
    var type: ConceptType
    var summary: String?
    var sourceAnchors: [SourceAnchor]
    var readingState: ReadingState
    var expansionState: ExpansionState
    var confidence: Double
    var isPinned: Bool
    var position: CGPoint?
    var parentChapterID: UUID?

    init(
        id: UUID = UUID(),
        label: String,
        type: ConceptType = .concept,
        summary: String? = nil,
        sourceAnchors: [SourceAnchor] = [],
        readingState: ReadingState = .unseen,
        expansionState: ExpansionState = .collapsed,
        confidence: Double = 1.0,
        isPinned: Bool = false,
        position: CGPoint? = nil,
        parentChapterID: UUID? = nil
    ) {
        self.id = id
        self.label = label
        self.type = type
        self.summary = summary
        self.sourceAnchors = sourceAnchors
        self.readingState = readingState
        self.expansionState = expansionState
        self.confidence = confidence
        self.isPinned = isPinned
        self.position = position
        self.parentChapterID = parentChapterID
    }
}

// MARK: - Graph Edge
struct GraphEdge: Identifiable, Codable, Hashable {
    let id: UUID
    var sourceNodeID: UUID
    var targetNodeID: UUID
    var type: EdgeType
    var confidence: Double
    var label: String?

    init(
        id: UUID = UUID(),
        sourceNodeID: UUID,
        targetNodeID: UUID,
        type: EdgeType,
        confidence: Double = 1.0,
        label: String? = nil
    ) {
        self.id = id
        self.sourceNodeID = sourceNodeID
        self.targetNodeID = targetNodeID
        self.type = type
        self.confidence = confidence
        self.label = label
    }
}

// MARK: - Knowledge Graph
@Observable
class KnowledgeGraph {
    var nodes: [UUID: ConceptNode] = [:]
    var edges: [UUID: GraphEdge] = [:]
    var documentProcessingState: [URL: ProcessingState] = [:]

    // Adjacency list: nodeID -> set of edgeIDs
    private(set) var adjacency: [UUID: Set<UUID>] = [:]

    var nodeCount: Int { nodes.count }
    var edgeCount: Int { edges.count }

    var allNodes: [ConceptNode] {
        Array(nodes.values)
    }

    var allEdges: [GraphEdge] {
        Array(edges.values)
    }

    // MARK: - Node Operations

    func addNode(_ node: ConceptNode) {
        nodes[node.id] = node
        if adjacency[node.id] == nil {
            adjacency[node.id] = []
        }
        log.info("[Graph] addNode: \"\(node.label)\" (total: \(self.nodes.count))")
    }

    func removeNode(_ nodeID: UUID) {
        nodes.removeValue(forKey: nodeID)
        // Remove all connected edges
        if let edgeIDs = adjacency[nodeID] {
            for edgeID in edgeIDs {
                if let edge = edges[edgeID] {
                    let otherNodeID = edge.sourceNodeID == nodeID ? edge.targetNodeID : edge.sourceNodeID
                    adjacency[otherNodeID]?.remove(edgeID)
                }
                edges.removeValue(forKey: edgeID)
            }
        }
        adjacency.removeValue(forKey: nodeID)
    }

    func updateNode(_ node: ConceptNode) {
        nodes[node.id] = node
    }

    func node(for id: UUID) -> ConceptNode? {
        nodes[id]
    }

    // MARK: - Edge Operations

    func addEdge(_ edge: GraphEdge) {
        edges[edge.id] = edge
        adjacency[edge.sourceNodeID, default: []].insert(edge.id)
        adjacency[edge.targetNodeID, default: []].insert(edge.id)
    }

    func removeEdge(_ edgeID: UUID) {
        if let edge = edges[edgeID] {
            adjacency[edge.sourceNodeID]?.remove(edgeID)
            adjacency[edge.targetNodeID]?.remove(edgeID)
        }
        edges.removeValue(forKey: edgeID)
    }

    // MARK: - Query Operations

    func edges(for nodeID: UUID) -> [GraphEdge] {
        guard let edgeIDs = adjacency[nodeID] else { return [] }
        return edgeIDs.compactMap { edges[$0] }
    }

    func neighbors(of nodeID: UUID) -> [ConceptNode] {
        let connectedEdges = edges(for: nodeID)
        let neighborIDs = connectedEdges.map { edge in
            edge.sourceNodeID == nodeID ? edge.targetNodeID : edge.sourceNodeID
        }
        return neighborIDs.compactMap { nodes[$0] }
    }

    func degree(of nodeID: UUID) -> Int {
        adjacency[nodeID]?.count ?? 0
    }

    func nodes(forDocument url: URL) -> [ConceptNode] {
        allNodes.filter { node in
            node.sourceAnchors.contains { $0.documentURL == url }
        }
    }

    func nodes(forPage pageIndex: Int, in documentURL: URL) -> [ConceptNode] {
        allNodes.filter { node in
            node.sourceAnchors.contains { $0.documentURL == documentURL && $0.pageIndex == pageIndex }
        }
    }

    // MARK: - Bulk Operations

    func clear() {
        nodes.removeAll()
        edges.removeAll()
        adjacency.removeAll()
        documentProcessingState.removeAll()
    }

    func merge(from other: KnowledgeGraph) {
        for (id, node) in other.nodes {
            nodes[id] = node
        }
        for (id, edge) in other.edges {
            addEdge(edge)
            _ = id // suppress warning
        }
        for (url, state) in other.documentProcessingState {
            documentProcessingState[url] = state
        }
    }
}

// MARK: - Codable Support
extension KnowledgeGraph {
    struct CodableRepresentation: Codable {
        let nodes: [ConceptNode]
        let edges: [GraphEdge]
        let documentProcessingState: [String: ProcessingState]
    }

    func encode() throws -> Data {
        let rep = CodableRepresentation(
            nodes: allNodes,
            edges: allEdges,
            documentProcessingState: documentProcessingState.reduce(into: [:]) { result, pair in
                result[pair.key.absoluteString] = pair.value
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(rep)
    }

    func decode(from data: Data) throws {
        let decoder = JSONDecoder()
        let rep = try decoder.decode(CodableRepresentation.self, from: data)

        clear()
        for node in rep.nodes {
            addNode(node)
        }
        for edge in rep.edges {
            addEdge(edge)
        }
        for (urlString, state) in rep.documentProcessingState {
            if let url = URL(string: urlString) {
                documentProcessingState[url] = state
            }
        }
    }
}
