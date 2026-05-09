//
//  BarnesHutQuadTree.swift
//  Atlas
//
//  Quadtree-based Barnes-Hut approximation for n-body repulsion.
//  Used by ForceDirectedLayout for graphs above the small-graph threshold.
//

import Foundation
import CoreGraphics

// `nonisolated` to opt out of the project-wide MainActor default
// (SWIFT_DEFAULT_ACTOR_ISOLATION). QuadTreeNode is a plain data
// structure; without this, recursive deallocation of [QuadTreeNode]?
// crashes the Swift Concurrency runtime on macOS 26.3 (isolated-deinit
// teardown double-free).
private final nonisolated class QuadTreeNode {
    var bounds: CGRect
    var centerOfMass: CGPoint = .zero
    var totalMass: Double = 0
    var bodies: [(id: UUID, position: CGPoint)] = []
    var children: [QuadTreeNode]?

    init(bounds: CGRect) {
        self.bounds = bounds
    }

    var isLeaf: Bool { children == nil }

    func insert(id: UUID, at position: CGPoint, depth: Int = 0) {
        let oldMass = totalMass
        totalMass += 1
        centerOfMass = CGPoint(
            x: (centerOfMass.x * oldMass + position.x) / totalMass,
            y: (centerOfMass.y * oldMass + position.y) / totalMass
        )

        if isLeaf {
            if oldMass == 0 || depth >= 32 {
                bodies.append((id, position))
                return
            }
            subdivide()
            for existing in bodies {
                child(containing: existing.position)?.insert(id: existing.id, at: existing.position, depth: depth + 1)
            }
            bodies.removeAll(keepingCapacity: false)
        }
        child(containing: position)?.insert(id: id, at: position, depth: depth + 1)
    }

    func force(on queryID: UUID, at queryPosition: CGPoint, theta: Double, repulsionConstant: Double) -> CGVector {
        if totalMass == 0 { return .zero }

        if isLeaf {
            var force = CGVector.zero
            for body in bodies where body.id != queryID {
                let f = Self.repulsion(from: body.position, to: queryPosition, mass: 1, k: repulsionConstant)
                force.dx += f.dx
                force.dy += f.dy
            }
            return force
        }

        let dx = queryPosition.x - centerOfMass.x
        let dy = queryPosition.y - centerOfMass.y
        let dist = max(sqrt(dx * dx + dy * dy), 1)
        let s = max(bounds.width, bounds.height)

        if s / dist < theta {
            return Self.repulsion(from: centerOfMass, to: queryPosition, mass: totalMass, k: repulsionConstant)
        }

        var force = CGVector.zero
        if let children {
            for child in children {
                let f = child.force(on: queryID, at: queryPosition, theta: theta, repulsionConstant: repulsionConstant)
                force.dx += f.dx
                force.dy += f.dy
            }
        }
        return force
    }

    private func subdivide() {
        let halfW = bounds.width / 2
        let halfH = bounds.height / 2
        children = [
            QuadTreeNode(bounds: CGRect(x: bounds.minX, y: bounds.minY, width: halfW, height: halfH)),
            QuadTreeNode(bounds: CGRect(x: bounds.midX, y: bounds.minY, width: halfW, height: halfH)),
            QuadTreeNode(bounds: CGRect(x: bounds.minX, y: bounds.midY, width: halfW, height: halfH)),
            QuadTreeNode(bounds: CGRect(x: bounds.midX, y: bounds.midY, width: halfW, height: halfH))
        ]
    }

    private func child(containing point: CGPoint) -> QuadTreeNode? {
        guard let children else { return nil }
        let east = point.x >= bounds.midX
        let south = point.y >= bounds.midY
        switch (south, east) {
        case (false, false): return children[0]
        case (false, true):  return children[1]
        case (true, false):  return children[2]
        case (true, true):   return children[3]
        }
    }

    private static func repulsion(from source: CGPoint, to target: CGPoint, mass: Double, k: Double) -> CGVector {
        let dx = target.x - source.x
        let dy = target.y - source.y
        let dist = max(sqrt(dx * dx + dy * dy), 1)
        let force = k * mass / (dist * dist)
        return CGVector(dx: (dx / dist) * force, dy: (dy / dist) * force)
    }
}

struct BarnesHutQuadTree {
    private let root: QuadTreeNode

    init(bodies: [(id: UUID, position: CGPoint)]) {
        guard !bodies.isEmpty else {
            self.root = QuadTreeNode(bounds: CGRect(x: 0, y: 0, width: 1, height: 1))
            return
        }
        var minX = Double.infinity, maxX = -Double.infinity
        var minY = Double.infinity, maxY = -Double.infinity
        for body in bodies {
            if body.position.x < minX { minX = body.position.x }
            if body.position.x > maxX { maxX = body.position.x }
            if body.position.y < minY { minY = body.position.y }
            if body.position.y > maxY { maxY = body.position.y }
        }
        let padding = max(1.0, max(maxX - minX, maxY - minY) * 0.01)
        let bounds = CGRect(
            x: minX - padding,
            y: minY - padding,
            width: (maxX - minX) + 2 * padding,
            height: (maxY - minY) + 2 * padding
        )
        let root = QuadTreeNode(bounds: bounds)
        for body in bodies {
            root.insert(id: body.id, at: body.position)
        }
        self.root = root
    }

    func force(on bodyID: UUID, at position: CGPoint, theta: Double, repulsionConstant: Double) -> CGVector {
        root.force(on: bodyID, at: position, theta: theta, repulsionConstant: repulsionConstant)
    }
}
