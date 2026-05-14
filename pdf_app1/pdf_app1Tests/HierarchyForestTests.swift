import XCTest

@testable import pdf_app1

final class HierarchyForestTests: XCTestCase {

    private func concept(_ label: String, level: Int = 1, id: UUID = UUID()) -> ConceptNode {
        ConceptNode(id: id, label: label, hierarchyLevel: level)
    }

    private func subtopic(_ child: UUID, _ parent: UUID) -> GraphEdge {
        GraphEdge(sourceNodeID: child, targetNodeID: parent, type: .subtopicOf)
    }

    func testBuild_noConcepts_emptyForest() {
        let forest = HierarchyForest.build(conceptNodes: [], edges: [])
        XCTAssertTrue(forest.roots.isEmpty)
        XCTAssertTrue(forest.isDegenerate)
    }

    func testBuild_noEdges_eachConceptIsItsOwnRoot_degenerate() {
        let a = concept("A")
        let b = concept("B")
        let c = concept("C")

        let forest = HierarchyForest.build(conceptNodes: [a, b, c], edges: [])
        XCTAssertEqual(forest.roots.count, 3)
        XCTAssertTrue(forest.parentByChild.isEmpty)
        XCTAssertTrue(forest.isDegenerate, "No edges means tree seeding wouldn't help — degenerate")
    }

    func testBuild_singleTree_oneRootTwoChildren() {
        let root = concept("Root", level: 0)
        let child1 = concept("Child1")
        let child2 = concept("Child2")

        let forest = HierarchyForest.build(
            conceptNodes: [root, child1, child2],
            edges: [subtopic(child1.id, root.id), subtopic(child2.id, root.id)]
        )

        XCTAssertEqual(forest.roots, [root.id])
        XCTAssertEqual(forest.parentByChild[child1.id], root.id)
        XCTAssertEqual(forest.parentByChild[child2.id], root.id)
        XCTAssertEqual(Set(forest.childrenByParent[root.id] ?? []), Set([child1.id, child2.id]))
        XCTAssertFalse(forest.isDegenerate)
    }

    func testBuild_multipleTrees_twoIndependentRoots() {
        let rootA = concept("A", level: 0)
        let childA = concept("a1")
        let rootB = concept("B", level: 0)
        let childB = concept("b1")

        let forest = HierarchyForest.build(
            conceptNodes: [rootA, childA, rootB, childB],
            edges: [subtopic(childA.id, rootA.id), subtopic(childB.id, rootB.id)]
        )

        XCTAssertEqual(Set(forest.roots), Set([rootA.id, rootB.id]))
        XCTAssertEqual(forest.parentByChild[childA.id], rootA.id)
        XCTAssertEqual(forest.parentByChild[childB.id], rootB.id)
    }

    func testBuild_multiParent_picksFirstCandidate() {
        // Stable iteration: subtopicOf edges processed in insertion order.
        let root1 = concept("R1", level: 0)
        let root2 = concept("R2", level: 0)
        let child = concept("C")

        let forest = HierarchyForest.build(
            conceptNodes: [root1, root2, child],
            edges: [subtopic(child.id, root1.id), subtopic(child.id, root2.id)]
        )

        XCTAssertEqual(forest.parentByChild[child.id], root1.id, "First subtopicOf edge wins")
    }

    func testBuild_cycle_breaksBackEdge() {
        // A → B (A's parent is B), then B → A would close the cycle. The
        // second edge is rejected; B stays root.
        let a = concept("A")
        let b = concept("B")

        let forest = HierarchyForest.build(
            conceptNodes: [a, b],
            edges: [subtopic(a.id, b.id), subtopic(b.id, a.id)]
        )

        // Which one ends up the root depends on UUID-sorted iteration in
        // build. Just check that exactly one has a parent and the chain is
        // acyclic.
        let assignedCount = forest.parentByChild.count
        XCTAssertEqual(assignedCount, 1, "Exactly one of the two ends up non-root")
        XCTAssertEqual(forest.roots.count, 1)

        // Walking from any node terminates (no infinite loop).
        XCTAssertNotNil(forest.root(of: a.id))
        XCTAssertNotNil(forest.root(of: b.id))
    }

    func testBuild_level0OverridesSubtopicOf() {
        // LLM noise: a node marked hierarchyLevel=0 AND a subtopicOf edge.
        // The level marker wins — node stays a root.
        let theme = concept("Theme", level: 0)
        let supposedlyParent = concept("OtherTheme", level: 0)

        let forest = HierarchyForest.build(
            conceptNodes: [theme, supposedlyParent],
            edges: [subtopic(theme.id, supposedlyParent.id)]
        )

        XCTAssertNil(forest.parentByChild[theme.id], "Level-0 node ignores subtopicOf")
        XCTAssertTrue(forest.roots.contains(theme.id))
        XCTAssertTrue(forest.roots.contains(supposedlyParent.id))
    }

    func testRoot_walksUpFromDeepDescendant() {
        let root = concept("R", level: 0)
        let mid = concept("M")
        let leaf = concept("L")

        let forest = HierarchyForest.build(
            conceptNodes: [root, mid, leaf],
            edges: [subtopic(mid.id, root.id), subtopic(leaf.id, mid.id)]
        )

        XCTAssertEqual(forest.root(of: leaf.id), root.id)
        XCTAssertEqual(forest.root(of: mid.id), root.id)
        XCTAssertEqual(forest.root(of: root.id), root.id)
    }

    func testBuild_ignoresNonSubtopicEdges() {
        let a = concept("A", level: 0)
        let b = concept("B")

        let forest = HierarchyForest.build(
            conceptNodes: [a, b],
            edges: [GraphEdge(sourceNodeID: b.id, targetNodeID: a.id, type: .dependsOn)]
        )

        XCTAssertTrue(forest.parentByChild.isEmpty, "Non-subtopicOf edges don't participate in the forest")
    }
}
