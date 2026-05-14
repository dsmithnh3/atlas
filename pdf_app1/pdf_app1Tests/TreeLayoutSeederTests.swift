import XCTest

@testable import pdf_app1

final class TreeLayoutSeederTests: XCTestCase {

    private let canvas = CGSize(width: 1000, height: 800)

    private func concept(_ label: String, level: Int = 1) -> ConceptNode {
        ConceptNode(label: label, hierarchyLevel: level)
    }

    private func subtopic(_ child: UUID, _ parent: UUID) -> GraphEdge {
        GraphEdge(sourceNodeID: child, targetNodeID: parent, type: .subtopicOf)
    }

    func testSeed_emptyForest_returnsEmpty() {
        let forest = HierarchyForest.build(conceptNodes: [], edges: [])
        let positions = TreeLayoutSeeder(canvasSize: canvas).seed(forest: forest) { _ in 0 }
        XCTAssertTrue(positions.isEmpty)
    }

    func testSeed_singleRootNoChildren_centeredHorizontally_topBand() {
        let root = concept("R", level: 0)
        let forest = HierarchyForest.build(conceptNodes: [root], edges: [])

        let seeder = TreeLayoutSeeder(canvasSize: canvas, bandSpacing: 200, siblingSpacing: 240, topMargin: 180)
        let positions = seeder.seed(forest: forest) { _ in 0 }

        guard let pos = positions[root.id] else {
            XCTFail("Root should have a position")
            return
        }
        XCTAssertEqual(pos.x, canvas.width / 2, accuracy: 1, "Single root centered horizontally")
        XCTAssertEqual(pos.y, 180, accuracy: 1, "Level-0 root in top band")
    }

    func testSeed_multipleRoots_spreadHorizontallyAroundMidX() {
        let r1 = concept("R1", level: 0)
        let r2 = concept("R2", level: 0)
        let r3 = concept("R3", level: 0)
        let forest = HierarchyForest.build(conceptNodes: [r1, r2, r3], edges: [])

        // 3 root singletons → 3 width units, spacing 200 → 600px total
        let seeder = TreeLayoutSeeder(canvasSize: canvas, bandSpacing: 200, siblingSpacing: 200, topMargin: 180)
        let positions = seeder.seed(forest: forest) { _ in 0 }

        let xs = forest.roots.compactMap { positions[$0]?.x }.sorted()
        XCTAssertEqual(xs.count, 3)
        XCTAssertEqual(xs[1], canvas.width / 2, accuracy: 1, "Middle root sits at canvas midX")
        XCTAssertEqual(xs[2] - xs[1], 200, accuracy: 1, "Adjacent roots separated by siblingSpacing")
        XCTAssertEqual(xs[1] - xs[0], 200, accuracy: 1)
    }

    func testSeed_rootWithTwoChildren_childrenCenteredBelowRoot() {
        let root = concept("R", level: 0)
        let c1 = concept("c1", level: 1)
        let c2 = concept("c2", level: 1)
        let forest = HierarchyForest.build(
            conceptNodes: [root, c1, c2],
            edges: [subtopic(c1.id, root.id), subtopic(c2.id, root.id)]
        )

        let seeder = TreeLayoutSeeder(canvasSize: canvas, bandSpacing: 200, siblingSpacing: 200, topMargin: 180)
        let positions = seeder.seed(forest: forest) { id in
            id == root.id ? 0 : 1
        }

        let rootX = positions[root.id]!.x
        let c1X = positions[c1.id]!.x
        let c2X = positions[c2.id]!.x

        // Children centered on parent
        XCTAssertEqual((c1X + c2X) / 2, rootX, accuracy: 1, "Children's centroid X equals parent X")
        // Children on the second band (level 1)
        XCTAssertEqual(positions[c1.id]!.y, 380, accuracy: 1)
        XCTAssertEqual(positions[c2.id]!.y, 380, accuracy: 1)
    }

    func testSeed_widerSubtreeGetsMoreHorizontalSpace() {
        // R1 has 4 children, R2 has 1 child. R1's allocated width should be
        // wider so its children don't crowd R2's subtree.
        let r1 = concept("R1", level: 0)
        let r1c1 = concept("a", level: 1)
        let r1c2 = concept("b", level: 1)
        let r1c3 = concept("c", level: 1)
        let r1c4 = concept("d", level: 1)
        let r2 = concept("R2", level: 0)
        let r2c1 = concept("z", level: 1)

        let forest = HierarchyForest.build(
            conceptNodes: [r1, r1c1, r1c2, r1c3, r1c4, r2, r2c1],
            edges: [
                subtopic(r1c1.id, r1.id),
                subtopic(r1c2.id, r1.id),
                subtopic(r1c3.id, r1.id),
                subtopic(r1c4.id, r1.id),
                subtopic(r2c1.id, r2.id),
            ]
        )

        let seeder = TreeLayoutSeeder(canvasSize: CGSize(width: 2000, height: 800), siblingSpacing: 200)
        let positions = seeder.seed(forest: forest) { id in
            id == r1.id || id == r2.id ? 0 : 1
        }

        // R1's subtree gets ~4× the horizontal space of R2's subtree.
        // Check that R1's children remain clustered near R1 (not overlapping
        // R2's territory), regardless of which root sorts first by UUID.
        let r1X = positions[r1.id]!.x
        let r2X = positions[r2.id]!.x
        let r1ChildXs = [r1c1, r1c2, r1c3, r1c4].compactMap { positions[$0.id]?.x }
        let r1ChildSpread = r1ChildXs.max()! - r1ChildXs.min()!
        let r2c1X = positions[r2c1.id]!.x

        XCTAssertGreaterThan(r1ChildSpread, 400, "R1's 4 children span >2 sibling-spacings")
        XCTAssertEqual(r2c1X, r2X, accuracy: 1, "R2's single child is centered directly under R2")

        // R1's subtree and R2's subtree don't overlap horizontally —
        // each root's allocated band is proportional to its subtree width.
        let r1SubtreeMaxX = max(r1X, r1ChildXs.max()!)
        let r1SubtreeMinX = min(r1X, r1ChildXs.min()!)
        let r2SubtreeMaxX = max(r2X, r2c1X)
        let r2SubtreeMinX = min(r2X, r2c1X)
        let nonOverlapping = r1SubtreeMaxX < r2SubtreeMinX || r2SubtreeMaxX < r1SubtreeMinX
        XCTAssertTrue(nonOverlapping, "R1 and R2 subtrees occupy disjoint horizontal bands")
    }

    func testSeed_depthFromOverride_orphanedSubconceptStillBandsAtItsLevel() {
        // A concept with hierarchyLevel = 2 but no parent edge is a root in
        // the forest. The depthFor override should still place it on band 2.
        let orphan = concept("X", level: 2)
        let forest = HierarchyForest.build(conceptNodes: [orphan], edges: [])

        let seeder = TreeLayoutSeeder(canvasSize: canvas, bandSpacing: 200, topMargin: 180)
        let positions = seeder.seed(forest: forest) { _ in 2 }

        XCTAssertEqual(positions[orphan.id]!.y, 580, accuracy: 1, "Band Y respects depthFor, not forest depth")
    }
}
