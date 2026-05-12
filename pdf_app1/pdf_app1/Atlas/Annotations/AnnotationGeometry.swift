import CoreGraphics

enum AnnotationGeometry {

    enum DragHandle: Equatable {
        case body
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    }

    static func handle(at point: CGPoint, rect: CGRect, handleSize: CGFloat) -> DragHandle? {
        let half = handleSize / 2
        let midX = rect.midX, midY = rect.midY
        let candidates: [(DragHandle, CGPoint)] = [
            (.topLeft,     CGPoint(x: rect.minX, y: rect.minY)),
            (.top,         CGPoint(x: midX,      y: rect.minY)),
            (.topRight,    CGPoint(x: rect.maxX, y: rect.minY)),
            (.right,       CGPoint(x: rect.maxX, y: midY)),
            (.bottomRight, CGPoint(x: rect.maxX, y: rect.maxY)),
            (.bottom,      CGPoint(x: midX,      y: rect.maxY)),
            (.bottomLeft,  CGPoint(x: rect.minX, y: rect.maxY)),
            (.left,        CGPoint(x: rect.minX, y: midY)),
        ]
        for (handle, center) in candidates {
            let square = CGRect(x: center.x - half, y: center.y - half,
                                width: handleSize, height: handleSize)
            if square.contains(point) { return handle }
        }
        if rect.contains(point) { return .body }
        return nil
    }

    static func resized(rect: CGRect, handle: DragHandle, by delta: CGVector,
                        in pageBounds: CGRect, minSize: CGSize) -> CGRect {
        let movesLeft   = handle == .topLeft  || handle == .left   || handle == .bottomLeft
        let movesRight  = handle == .topRight || handle == .right  || handle == .bottomRight
        let movesTop    = handle == .topLeft  || handle == .top    || handle == .topRight
        let movesBottom = handle == .bottomLeft || handle == .bottom || handle == .bottomRight

        var minX = rect.minX, maxX = rect.maxX
        var minY = rect.minY, maxY = rect.maxY

        if movesLeft   { minX = min(max(minX + delta.dx, pageBounds.minX), maxX - minSize.width) }
        if movesRight  { maxX = max(min(maxX + delta.dx, pageBounds.maxX), minX + minSize.width) }
        if movesTop    { minY = min(max(minY + delta.dy, pageBounds.minY), maxY - minSize.height) }
        if movesBottom { maxY = max(min(maxY + delta.dy, pageBounds.maxY), minY + minSize.height) }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func translated(rect: CGRect, by delta: CGVector, in pageBounds: CGRect) -> CGRect {
        let moved = rect.offsetBy(dx: delta.dx, dy: delta.dy)
        let clampedX = min(max(moved.minX, pageBounds.minX), pageBounds.maxX - moved.width)
        let clampedY = min(max(moved.minY, pageBounds.minY), pageBounds.maxY - moved.height)
        return CGRect(x: clampedX, y: clampedY, width: rect.width, height: rect.height)
    }
}
