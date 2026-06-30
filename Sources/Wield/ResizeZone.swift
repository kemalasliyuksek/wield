import CoreGraphics

/// Describes which edges of a window follow the cursor while resizing.
/// The opposite edge(s) stay anchored. Determined once, from where inside the
/// window the drag started.
struct ResizeZone {
    enum Horizontal { case left, right, none }
    enum Vertical { case top, bottom, none }

    let horizontal: Horizontal
    let vertical: Vertical

    /// Splits the window into a 3×3 grid. Outer thirds drive an edge; the very
    /// center falls back to the nearest corner so a grab is never a no-op.
    /// Coordinates are top-left origin (AX/CG space): y increases downward.
    static func zone(for point: CGPoint, in frame: CGRect) -> ResizeZone {
        let rx = frame.width > 0 ? (point.x - frame.minX) / frame.width : 0.5
        let ry = frame.height > 0 ? (point.y - frame.minY) / frame.height : 0.5

        var horizontal: Horizontal = rx < 1.0 / 3.0 ? .left : (rx > 2.0 / 3.0 ? .right : .none)
        var vertical: Vertical = ry < 1.0 / 3.0 ? .top : (ry > 2.0 / 3.0 ? .bottom : .none)

        if horizontal == .none && vertical == .none {
            horizontal = rx < 0.5 ? .left : .right
            vertical = ry < 0.5 ? .top : .bottom
        }
        return ResizeZone(horizontal: horizontal, vertical: vertical)
    }

    /// Produces the new frame given the cumulative mouse delta from the drag
    /// start (top-left origin). Anchored edges remain fixed; a minimum size is
    /// enforced without moving the anchor.
    func apply(dx: CGFloat, dy: CGFloat, to frame: CGRect, minSize: CGSize) -> CGRect {
        var x = frame.minX
        var y = frame.minY
        var width = frame.width
        var height = frame.height

        switch horizontal {
        case .right:
            width = max(minSize.width, frame.width + dx)        // anchor = left edge
        case .left:
            width = max(minSize.width, frame.width - dx)        // anchor = right edge
            x = frame.maxX - width
        case .none:
            break
        }

        switch vertical {
        case .bottom:
            height = max(minSize.height, frame.height + dy)     // anchor = top edge
        case .top:
            height = max(minSize.height, frame.height - dy)     // anchor = bottom edge
            y = frame.maxY - height
        case .none:
            break
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
