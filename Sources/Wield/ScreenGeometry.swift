import AppKit
import CoreGraphics

/// Helpers for reasoning about displays in the AX/CG top-left origin space
/// (the coordinate space used by the Accessibility API and Core Graphics
/// events — NOT AppKit's bottom-left origin).
enum ScreenGeometry {
    /// Height of the primary (menu-bar) screen. It defines y = 0 for the global
    /// top-left space, so it is the reference for flipping between AppKit's
    /// bottom-left origin and AX/CG's top-left origin.
    private static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// The AX/CG (top-left origin) frame of an `NSScreen`, including the menu
    /// bar area — i.e. the full display bounds, not the visible frame.
    static func axFrame(of screen: NSScreen) -> CGRect {
        let frame = screen.frame
        let flippedY = primaryHeight - frame.origin.y - frame.height
        return CGRect(x: frame.origin.x, y: flippedY, width: frame.width, height: frame.height)
    }

    /// Whether `windowFrame` (AX/CG space) fills the entire display it sits on —
    /// the signature of a real or borderless full-screen surface such as a
    /// game, a native full-screen window, or a full-screen video.
    ///
    /// A *maximized* window that still leaves the menu bar visible does NOT
    /// count (it never reaches the display's top edge), so ordinary large
    /// windows stay movable/resizable.
    static func coversWholeDisplay(_ windowFrame: CGRect) -> Bool {
        guard let screen = display(containing: windowFrame) else { return false }
        let bounds = axFrame(of: screen)

        // A hairline tolerance absorbs apps that inset their full-screen surface
        // by a pixel. It stays well under the menu bar's height, so a maximized
        // window (which stops below the menu bar) is never mistaken for one.
        let tolerance: CGFloat = 2
        return abs(windowFrame.minX - bounds.minX) <= tolerance
            && abs(windowFrame.minY - bounds.minY) <= tolerance
            && abs(windowFrame.width - bounds.width) <= tolerance
            && abs(windowFrame.height - bounds.height) <= tolerance
    }

    /// The display that holds the largest slice of `windowFrame`.
    private static func display(containing windowFrame: CGRect) -> NSScreen? {
        NSScreen.screens.max { lhs, rhs in
            overlapArea(axFrame(of: lhs), windowFrame) < overlapArea(axFrame(of: rhs), windowFrame)
        }
    }

    private static func overlapArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}
