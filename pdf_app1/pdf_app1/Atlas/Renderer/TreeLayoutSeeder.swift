//
//  TreeLayoutSeeder.swift
//  Atlas
//
//  Lays out a `HierarchyForest` as vertical bands (one per depth) with
//  children X-centered under their canonical parent. Produces initial
//  positions that FDL refines further; the band structure tends to
//  persist after FDL converges because each subtree shares a `groupKey`
//  and its members keep each other in horizontal proximity.
//

import Foundation
import CoreGraphics

struct TreeLayoutSeeder {
    let canvasSize: CGSize
    let bandSpacing: CGFloat
    let siblingSpacing: CGFloat
    let topMargin: CGFloat

    init(
        canvasSize: CGSize,
        bandSpacing: CGFloat = 220,
        siblingSpacing: CGFloat = 240,
        topMargin: CGFloat = 180
    ) {
        self.canvasSize = canvasSize
        self.bandSpacing = bandSpacing
        self.siblingSpacing = siblingSpacing
        self.topMargin = topMargin
    }

    /// Produces a position for every node reachable from a root.
    /// `depthFor(_:)` returns the band depth — typically `node.hierarchyLevel`
    /// so orphaned sub-concepts (a level-1 node with no parent edge) still
    /// land in band 1 rather than being treated as a level-0 root.
    func seed(forest: HierarchyForest, depthFor: (UUID) -> Int) -> [UUID: CGPoint] {
        guard !forest.roots.isEmpty else { return [:] }

        // Pre-compute leaf-width per subtree (in sibling-spacing units)
        var subtreeWidth: [UUID: Int] = [:]
        for root in forest.roots {
            computeWidth(root, forest: forest, widths: &subtreeWidth)
        }

        // Lay out roots side-by-side, centered on canvasMidX
        let totalRootUnits = forest.roots.reduce(0) { $0 + (subtreeWidth[$1] ?? 1) }
        let totalRootPixels = CGFloat(totalRootUnits) * siblingSpacing
        let canvasMidX = canvasSize.width / 2
        var cursorX = canvasMidX - totalRootPixels / 2

        var positions: [UUID: CGPoint] = [:]
        for root in forest.roots {
            let width = subtreeWidth[root] ?? 1
            let rootX = cursorX + CGFloat(width) * siblingSpacing / 2
            place(
                root,
                atX: rootX,
                forest: forest,
                widths: subtreeWidth,
                depthFor: depthFor,
                positions: &positions
            )
            cursorX += CGFloat(width) * siblingSpacing
        }

        return positions
    }

    private func computeWidth(_ node: UUID, forest: HierarchyForest, widths: inout [UUID: Int]) {
        let children = forest.childrenByParent[node] ?? []
        if children.isEmpty {
            widths[node] = 1
            return
        }
        var total = 0
        for child in children {
            computeWidth(child, forest: forest, widths: &widths)
            total += widths[child] ?? 1
        }
        widths[node] = max(total, 1)
    }

    private func place(
        _ node: UUID,
        atX x: CGFloat,
        forest: HierarchyForest,
        widths: [UUID: Int],
        depthFor: (UUID) -> Int,
        positions: inout [UUID: CGPoint]
    ) {
        positions[node] = CGPoint(x: x, y: bandY(forDepth: depthFor(node)))

        let children = forest.childrenByParent[node] ?? []
        guard !children.isEmpty else { return }

        let totalChildUnits = children.reduce(0) { $0 + (widths[$1] ?? 1) }
        let totalChildPixels = CGFloat(totalChildUnits) * siblingSpacing
        var cursorX = x - totalChildPixels / 2

        for child in children {
            let w = widths[child] ?? 1
            let childX = cursorX + CGFloat(w) * siblingSpacing / 2
            place(
                child,
                atX: childX,
                forest: forest,
                widths: widths,
                depthFor: depthFor,
                positions: &positions
            )
            cursorX += CGFloat(w) * siblingSpacing
        }
    }

    private func bandY(forDepth depth: Int) -> CGFloat {
        topMargin + CGFloat(depth) * bandSpacing
    }
}
