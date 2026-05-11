import XCTest

@testable import pdf_app1

final class AnnotationGeometryTests: XCTestCase {

    private let page = CGRect(x: 0, y: 0, width: 612, height: 792)
    private let minSize = CGSize(width: 10, height: 10)

    // MARK: - translate

    func testTranslateInsidePageShiftsOriginPreservesSize() {
        let rect = CGRect(x: 100, y: 100, width: 80, height: 40)
        let moved = AnnotationGeometry.translated(rect: rect, by: CGVector(dx: 30, dy: -20), in: page)
        XCTAssertEqual(moved, CGRect(x: 130, y: 80, width: 80, height: 40))
    }

    func testTranslateClampsAtPageEdgesPreservesSize() {
        let rect = CGRect(x: 10, y: 10, width: 80, height: 40)
        let pushedLeft = AnnotationGeometry.translated(rect: rect, by: CGVector(dx: -500, dy: 0), in: page)
        XCTAssertEqual(pushedLeft, CGRect(x: 0, y: 10, width: 80, height: 40))

        let pushedRight = AnnotationGeometry.translated(rect: rect, by: CGVector(dx: 10_000, dy: 0), in: page)
        XCTAssertEqual(pushedRight, CGRect(x: 532, y: 10, width: 80, height: 40))

        let pushedDown = AnnotationGeometry.translated(rect: rect, by: CGVector(dx: 0, dy: -500), in: page)
        XCTAssertEqual(pushedDown, CGRect(x: 10, y: 0, width: 80, height: 40))

        let pushedUp = AnnotationGeometry.translated(rect: rect, by: CGVector(dx: 0, dy: 10_000), in: page)
        XCTAssertEqual(pushedUp, CGRect(x: 10, y: 752, width: 80, height: 40))
    }

    // MARK: - resize

    func testResizeBottomRightGrowsWidthAndHeight() {
        let rect = CGRect(x: 100, y: 100, width: 80, height: 40)
        let resized = AnnotationGeometry.resized(
            rect: rect, handle: .bottomRight, by: CGVector(dx: 20, dy: 15),
            in: page, minSize: minSize)
        XCTAssertEqual(resized, CGRect(x: 100, y: 100, width: 100, height: 55))
    }

    func testResizeTopLeftMovesOriginAndShrinksSize() {
        let rect = CGRect(x: 100, y: 100, width: 80, height: 40)
        let resized = AnnotationGeometry.resized(
            rect: rect, handle: .topLeft, by: CGVector(dx: 15, dy: 10),
            in: page, minSize: minSize)
        XCTAssertEqual(resized, CGRect(x: 115, y: 110, width: 65, height: 30))
    }

    func testResizeTopRightAdjustsTopAndRight() {
        let rect = CGRect(x: 100, y: 100, width: 80, height: 40)
        let resized = AnnotationGeometry.resized(
            rect: rect, handle: .topRight, by: CGVector(dx: 20, dy: 5),
            in: page, minSize: minSize)
        XCTAssertEqual(resized, CGRect(x: 100, y: 105, width: 100, height: 35))
    }

    func testResizeBottomLeftAdjustsLeftAndBottom() {
        let rect = CGRect(x: 100, y: 100, width: 80, height: 40)
        let resized = AnnotationGeometry.resized(
            rect: rect, handle: .bottomLeft, by: CGVector(dx: -10, dy: 5),
            in: page, minSize: minSize)
        XCTAssertEqual(resized, CGRect(x: 90, y: 100, width: 90, height: 45))
    }

    func testResizeGrowingPastPageEdgeClampsAtPageBounds() {
        let rect = CGRect(x: 100, y: 100, width: 80, height: 40)

        // bottomRight pushed far past page: maxX clamps at page.maxX (612), maxY at page.maxY (792)
        let br = AnnotationGeometry.resized(
            rect: rect, handle: .bottomRight, by: CGVector(dx: 10_000, dy: 10_000),
            in: page, minSize: minSize)
        XCTAssertEqual(br, CGRect(x: 100, y: 100, width: 512, height: 692))

        // topLeft pushed past page origin: minX/minY clamp at 0, opposite edges unchanged
        let tl = AnnotationGeometry.resized(
            rect: rect, handle: .topLeft, by: CGVector(dx: -10_000, dy: -10_000),
            in: page, minSize: minSize)
        XCTAssertEqual(tl, CGRect(x: 0, y: 0, width: 180, height: 140))
    }

    func testResizeShrinkingPastMinClampsAtMinAndPinsOppositeEdge() {
        let rect = CGRect(x: 100, y: 100, width: 80, height: 40)

        // bottomRight shrinking: pull inward huge amount → clamp at minSize, opposite edges (top, left) stay
        let br = AnnotationGeometry.resized(
            rect: rect, handle: .bottomRight, by: CGVector(dx: -500, dy: -500),
            in: page, minSize: minSize)
        XCTAssertEqual(br, CGRect(x: 100, y: 100, width: 10, height: 10))

        // topLeft shrinking inward: clamp at minSize, opposite edges (bottom, right) stay
        let tl = AnnotationGeometry.resized(
            rect: rect, handle: .topLeft, by: CGVector(dx: 500, dy: 500),
            in: page, minSize: minSize)
        XCTAssertEqual(tl, CGRect(x: 170, y: 130, width: 10, height: 10))

        // single-axis edge: only that axis clamps, other axis untouched
        let right = AnnotationGeometry.resized(
            rect: rect, handle: .right, by: CGVector(dx: -500, dy: 0),
            in: page, minSize: minSize)
        XCTAssertEqual(right, CGRect(x: 100, y: 100, width: 10, height: 40))
    }

    // MARK: - handle hit-test

    func testHandleAtCornersEdgesBodyAndMiss() {
        let rect = CGRect(x: 100, y: 100, width: 80, height: 40)
        let h: CGFloat = 8

        XCTAssertEqual(AnnotationGeometry.handle(at: CGPoint(x: 100, y: 100), rect: rect, handleSize: h), .topLeft)
        XCTAssertEqual(AnnotationGeometry.handle(at: CGPoint(x: 180, y: 100), rect: rect, handleSize: h), .topRight)
        XCTAssertEqual(AnnotationGeometry.handle(at: CGPoint(x: 100, y: 140), rect: rect, handleSize: h), .bottomLeft)
        XCTAssertEqual(AnnotationGeometry.handle(at: CGPoint(x: 180, y: 140), rect: rect, handleSize: h), .bottomRight)

        XCTAssertEqual(AnnotationGeometry.handle(at: CGPoint(x: 140, y: 100), rect: rect, handleSize: h), .top)
        XCTAssertEqual(AnnotationGeometry.handle(at: CGPoint(x: 140, y: 140), rect: rect, handleSize: h), .bottom)
        XCTAssertEqual(AnnotationGeometry.handle(at: CGPoint(x: 100, y: 120), rect: rect, handleSize: h), .left)
        XCTAssertEqual(AnnotationGeometry.handle(at: CGPoint(x: 180, y: 120), rect: rect, handleSize: h), .right)

        XCTAssertEqual(AnnotationGeometry.handle(at: CGPoint(x: 140, y: 120), rect: rect, handleSize: h), .body)
        XCTAssertNil(AnnotationGeometry.handle(at: CGPoint(x: 50, y: 50), rect: rect, handleSize: h))
    }

    func testResizeEachEdgeAffectsOneAxis() {
        let rect = CGRect(x: 100, y: 100, width: 80, height: 40)
        XCTAssertEqual(
            AnnotationGeometry.resized(rect: rect, handle: .right,
                                       by: CGVector(dx: 10, dy: 99), in: page, minSize: minSize),
            CGRect(x: 100, y: 100, width: 90, height: 40))
        XCTAssertEqual(
            AnnotationGeometry.resized(rect: rect, handle: .left,
                                       by: CGVector(dx: -5, dy: 99), in: page, minSize: minSize),
            CGRect(x: 95, y: 100, width: 85, height: 40))
        XCTAssertEqual(
            AnnotationGeometry.resized(rect: rect, handle: .top,
                                       by: CGVector(dx: 99, dy: 8), in: page, minSize: minSize),
            CGRect(x: 100, y: 108, width: 80, height: 32))
        XCTAssertEqual(
            AnnotationGeometry.resized(rect: rect, handle: .bottom,
                                       by: CGVector(dx: 99, dy: 12), in: page, minSize: minSize),
            CGRect(x: 100, y: 100, width: 80, height: 52))
    }
}
