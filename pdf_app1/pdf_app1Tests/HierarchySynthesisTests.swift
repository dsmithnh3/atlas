import XCTest

@testable import pdf_app1

final class HierarchySynthesisTests: XCTestCase {

    private let docURL = URL(fileURLWithPath: "/tmp/test-doc.pdf")

    private func concept(
        _ label: String,
        level: Int = 1,
        pageIndex: Int = 0,
        confidence: Double = 0.9
    ) -> ConceptNode {
        let anchor = SourceAnchor(
            documentURL: docURL,
            pageIndex: pageIndex,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20),
            textSnippet: label
        )
        return ConceptNode(
            label: label,
            sourceAnchors: [anchor],
            confidence: confidence,
            hierarchyLevel: level
        )
    }

    private func edge(_ src: UUID, _ tgt: UUID, _ type: EdgeType) -> GraphEdge {
        GraphEdge(sourceNodeID: src, targetNodeID: tgt, type: type)
    }

    private func buildGraph(_ nodes: [ConceptNode], _ edges: [GraphEdge]) -> KnowledgeGraph {
        let g = KnowledgeGraph()
        for n in nodes { g.addNode(n) }
        for e in edges { g.addEdge(e) }
        return g
    }

    // MARK: - No-op cases

    func testSynthesize_tinyGraph_doesNothing() {
        let nodes = (0..<3).map { concept("Concept\($0)") }
        let graph = buildGraph(nodes, [])

        HierarchySynthesis.synthesize(graph: graph)

        XCTAssertFalse(graph.allEdges.contains { $0.type == .subtopicOf },
                       "Tiny graph should not gain synthesized subtopicOf edges")
        XCTAssertTrue(graph.allNodes.allSatisfy { $0.hierarchyLevel == 1 },
                      "Tiny graph hierarchy levels untouched")
    }

    func testSynthesize_existingLLMHierarchy_isPreserved() {
        // 10 concepts, with LLM-produced subtopicOf forest already in place.
        // Synthesis should detect the non-degenerate forest and skip.
        let root1 = concept("Root1", level: 0)
        let root2 = concept("Root2", level: 0)
        var nodes = [root1, root2]
        for i in 0..<8 {
            nodes.append(concept("Sub\(i)"))
        }
        // Attach each sub to one of the roots
        var edges: [GraphEdge] = []
        for (idx, sub) in nodes.dropFirst(2).enumerated() {
            let parent = idx % 2 == 0 ? root1 : root2
            edges.append(edge(sub.id, parent.id, .subtopicOf))
        }
        let graph = buildGraph(nodes, edges)
        let edgesBefore = graph.edgeCount

        HierarchySynthesis.synthesize(graph: graph)

        XCTAssertEqual(graph.edgeCount, edgesBefore, "No synthetic edges added when LLM hierarchy present")
        XCTAssertEqual(graph.node(matching: "Root1")?.hierarchyLevel, 0)
        XCTAssertEqual(graph.node(matching: "Root2")?.hierarchyLevel, 0)
    }

    // MARK: - Synthesis cases

    func testSynthesize_flatGraph_producesThemesAndSubtopicEdges() {
        // 10 flat concepts, all level 1, no subtopicOf. Make a chain of
        // partOf edges so one node has high generality-in-degree.
        let hub = concept("Hub", pageIndex: 0, confidence: 0.95)
        var nodes: [ConceptNode] = [hub]
        for i in 0..<9 {
            nodes.append(concept("Leaf\(i)", pageIndex: i % 3))
        }
        // Each leaf points partOf the hub → hub has high generality score
        let edges = nodes.dropFirst().map { edge($0.id, hub.id, .partOf) }
        let graph = buildGraph(nodes, Array(edges))

        HierarchySynthesis.synthesize(graph: graph)

        let themes = graph.allNodes.filter { $0.hierarchyLevel == 0 }
        XCTAssertGreaterThanOrEqual(themes.count, 3, "Should produce at least 3 themes")
        XCTAssertTrue(themes.contains(where: { $0.id == hub.id }),
                      "Hub (highest generality-in-degree) should be one of the themes")

        let synthesizedSubtopics = graph.allEdges.filter { $0.type == EdgeType.subtopicOf }
        XCTAssertGreaterThan(synthesizedSubtopics.count, 0, "Should synthesize subtopicOf edges")
        XCTAssertTrue(synthesizedSubtopics.allSatisfy { $0.label == "synthesized" },
                      "Synthetic edges tagged with 'synthesized' label")
    }

    func testSynthesize_multiPageNodes_scoreHigherAsThemes() {
        // Two candidates with same connectivity but different page coverage —
        // the multi-page one should be chosen.
        let multiPage = ConceptNode(
            label: "MultiPage",
            sourceAnchors: (0..<5).map { i in
                SourceAnchor(
                    documentURL: docURL,
                    pageIndex: i,
                    boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20),
                    textSnippet: "MultiPage on page \(i)"
                )
            },
            confidence: 0.9
        )
        let singlePage = concept("SinglePage", pageIndex: 0)
        var nodes: [ConceptNode] = [multiPage, singlePage]
        for i in 0..<8 {
            nodes.append(concept("Leaf\(i)", pageIndex: i))
        }

        let graph = buildGraph(nodes, [])
        let multiScore = HierarchySynthesis.themeScore(for: multiPage, in: graph)
        let singleScore = HierarchySynthesis.themeScore(for: singlePage, in: graph)

        XCTAssertGreaterThan(multiScore, singleScore,
                             "Multi-page concept should outscore single-page concept")
    }

    func testSynthesize_isIdempotent() {
        let nodes = (0..<10).map { concept("C\($0)", pageIndex: $0 % 3) }
        // Some random connectivity so themes can be picked
        var edges: [GraphEdge] = []
        for i in 1..<10 {
            edges.append(edge(nodes[i].id, nodes[0].id, .partOf))
        }
        let graph = buildGraph(nodes, edges)

        HierarchySynthesis.synthesize(graph: graph)
        let edgesAfterFirst = graph.edgeCount
        let levelsAfterFirst = graph.allNodes.map { ($0.id, $0.hierarchyLevel) }
            .sorted { $0.0.uuidString < $1.0.uuidString }

        HierarchySynthesis.synthesize(graph: graph)
        let edgesAfterSecond = graph.edgeCount
        let levelsAfterSecond = graph.allNodes.map { ($0.id, $0.hierarchyLevel) }
            .sorted { $0.0.uuidString < $1.0.uuidString }

        XCTAssertEqual(edgesAfterFirst, edgesAfterSecond,
                       "Second synthesis pass adds no new edges (idempotent)")
        XCTAssertEqual(levelsAfterFirst.map { $0.1 }, levelsAfterSecond.map { $0.1 },
                       "Second synthesis pass changes no hierarchy levels")
    }

    func testSynthesize_disconnectedComponents_themesPickedFromEachOrLargestOnly() {
        // Two disconnected sub-graphs. Synthesis BFS only finds the theme
        // in the same component — orphans in the smaller component without
        // a theme get left unparented (no synthetic edge added).
        let c1 = concept("C1", pageIndex: 0)
        let c2 = concept("C2", pageIndex: 0)
        let c3 = concept("C3", pageIndex: 0)
        let c4 = concept("C4", pageIndex: 0)
        let c5 = concept("C5", pageIndex: 0)
        let c6 = concept("C6", pageIndex: 0)
        let c7 = concept("C7", pageIndex: 0)
        let c8 = concept("C8", pageIndex: 0)
        // Component A: c1...c6 densely connected; c1 is hub
        var edges: [GraphEdge] = []
        for c in [c2, c3, c4, c5, c6] {
            edges.append(edge(c.id, c1.id, .partOf))
        }
        // Component B: c7, c8 connected to each other but no theme there
        edges.append(edge(c8.id, c7.id, .partOf))

        let graph = buildGraph([c1, c2, c3, c4, c5, c6, c7, c8], edges)
        HierarchySynthesis.synthesize(graph: graph)

        let themeIDs = Set(graph.allNodes.filter { $0.hierarchyLevel == 0 }.map(\.id))
        XCTAssertFalse(themeIDs.isEmpty, "At least one theme produced")
        XCTAssertTrue(themeIDs.contains(c1.id), "c1 (highest score) should be a theme")

        // Every non-theme in component A should have a subtopicOf edge to
        // some theme. K=3 themes for 8 nodes, so 1 of c2-c6 may be the
        // third theme via ID tiebreaker — only count the actual non-themes.
        let aNodes = [c1, c2, c3, c4, c5, c6]
        let aNonThemes = aNodes.filter { !themeIDs.contains($0.id) }
        let aSubs = aNonThemes.compactMap { node in
            graph.allEdges.first { $0.sourceNodeID == node.id && $0.type == EdgeType.subtopicOf }
        }
        XCTAssertEqual(aSubs.count, aNonThemes.count,
                       "Every component-A non-theme connected to a theme")
    }

    // MARK: - Theme count formula

    func testDesiredThemeCount_followsSqrtCurve() {
        XCTAssertEqual(HierarchySynthesis.desiredThemeCount(forConceptCount: 4), 3)   // sqrt(4)=2 → max(3,2)=3
        XCTAssertEqual(HierarchySynthesis.desiredThemeCount(forConceptCount: 25), 5)  // sqrt(25)=5
        XCTAssertEqual(HierarchySynthesis.desiredThemeCount(forConceptCount: 100), 10)
        XCTAssertEqual(HierarchySynthesis.desiredThemeCount(forConceptCount: 400), 15) // capped at 15
        XCTAssertEqual(HierarchySynthesis.desiredThemeCount(forConceptCount: 1000), 15)
    }
}
