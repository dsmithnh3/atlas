import Foundation
import XCTest
import CoreGraphics

@testable import pdf_app1

final class BarnesHutQuadTreeTests: XCTestCase {

    private let k: Double = 25_000  // matches ForceDirectedLayout.repulsionConstant

    func testEmptyTreeReturnsZeroForce() {
        let tree = BarnesHutQuadTree(bodies: [])
        let f = tree.force(on: UUID(), at: CGPoint(x: 0, y: 0), theta: 0.7, repulsionConstant: k)
        XCTAssertEqual(f.dx, 0, accuracy: 1e-9)
        XCTAssertEqual(f.dy, 0, accuracy: 1e-9)
    }

    func testSingleBodyHasNoSelfForce() {
        let id = UUID()
        let tree = BarnesHutQuadTree(bodies: [(id, CGPoint(x: 100, y: 100))])
        let f = tree.force(on: id, at: CGPoint(x: 100, y: 100), theta: 0.7, repulsionConstant: k)
        XCTAssertEqual(f.dx, 0, accuracy: 1e-9)
        XCTAssertEqual(f.dy, 0, accuracy: 1e-9)
    }

    func testTwoBodyForceMatchesClosedForm() {
        let a = UUID()
        let b = UUID()
        let posA = CGPoint(x: 0, y: 0)
        let posB = CGPoint(x: 100, y: 0)
        let tree = BarnesHutQuadTree(bodies: [(a, posA), (b, posB)])

        // Force on A should point in -x direction (away from B), magnitude k / 100²
        let fA = tree.force(on: a, at: posA, theta: 0, repulsionConstant: k)
        let expectedMag = k / (100.0 * 100.0)
        XCTAssertEqual(fA.dx, -expectedMag, accuracy: 1e-6)
        XCTAssertEqual(fA.dy, 0, accuracy: 1e-6)
    }

    func testForceSymmetry() {
        let a = UUID()
        let b = UUID()
        let posA = CGPoint(x: 50, y: 50)
        let posB = CGPoint(x: 150, y: 200)
        let tree = BarnesHutQuadTree(bodies: [(a, posA), (b, posB)])

        let fA = tree.force(on: a, at: posA, theta: 0, repulsionConstant: k)
        let fB = tree.force(on: b, at: posB, theta: 0, repulsionConstant: k)

        XCTAssertEqual(fA.dx, -fB.dx, accuracy: 1e-6)
        XCTAssertEqual(fA.dy, -fB.dy, accuracy: 1e-6)
    }

    func testDistantClusterApproximationWithinTolerance() {
        // 50 bodies tightly clustered far from a probe. With theta=0.5 the cluster
        // should be lumped, producing a force within ~1% of the equivalent point-mass force.
        var bodies: [(id: UUID, position: CGPoint)] = []
        let clusterCenter = CGPoint(x: 1000, y: 1000)
        for i in 0..<50 {
            let angle = Double(i) * 0.13
            let r = 5.0
            bodies.append((UUID(), CGPoint(
                x: clusterCenter.x + cos(angle) * r,
                y: clusterCenter.y + sin(angle) * r
            )))
        }
        let probeID = UUID()
        let probePos = CGPoint(x: 0, y: 0)
        bodies.append((probeID, probePos))

        let tree = BarnesHutQuadTree(bodies: bodies)
        let approx = tree.force(on: probeID, at: probePos, theta: 0.5, repulsionConstant: k)

        // Reference: exact sum
        var exactDX = 0.0, exactDY = 0.0
        for body in bodies where body.id != probeID {
            let dx = probePos.x - body.position.x
            let dy = probePos.y - body.position.y
            let dist = sqrt(dx * dx + dy * dy)
            let force = k / (dist * dist)
            exactDX += (dx / dist) * force
            exactDY += (dy / dist) * force
        }

        let exactMag = sqrt(exactDX * exactDX + exactDY * exactDY)
        let approxMag = sqrt(Double(approx.dx) * Double(approx.dx) + Double(approx.dy) * Double(approx.dy))
        let relativeError = abs(approxMag - exactMag) / exactMag
        XCTAssertLessThan(relativeError, 0.01, "Barnes-Hut approximation should be within 1% for distant cluster")
    }

    func testRandomLargeGraphConstructsAndQueriesWithoutOverflow() {
        var bodies: [(id: UUID, position: CGPoint)] = []
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<1000 {
            bodies.append((UUID(), CGPoint(
                x: Double.random(in: 0...2000, using: &rng),
                y: Double.random(in: 0...2000, using: &rng)
            )))
        }
        let tree = BarnesHutQuadTree(bodies: bodies)

        // Query every body — should complete without crashing or producing NaN
        for body in bodies {
            let f = tree.force(on: body.id, at: body.position, theta: 0.7, repulsionConstant: k)
            XCTAssertFalse(f.dx.isNaN)
            XCTAssertFalse(f.dy.isNaN)
        }
    }

    func testCoincidentBodiesDoNotInfiniteRecurse() {
        // 10 bodies at the same position — would recurse forever without depth cap
        var bodies: [(id: UUID, position: CGPoint)] = []
        for _ in 0..<10 {
            bodies.append((UUID(), CGPoint(x: 100, y: 100)))
        }
        let tree = BarnesHutQuadTree(bodies: bodies)
        // Just verify construction completes; query a probe at a different position
        let f = tree.force(on: UUID(), at: CGPoint(x: 200, y: 100), theta: 0.7, repulsionConstant: k)
        XCTAssertFalse(f.dx.isNaN)
        XCTAssertFalse(f.dy.isNaN)
        // Force should push away (negative-x... actually positive-x since probe is at +200)
        XCTAssertGreaterThan(Double(f.dx), 0)
    }
}
