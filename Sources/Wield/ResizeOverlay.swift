import AppKit

/// A borderless, click-through window that previews the target frame while
/// resizing — drawn in the system accent color with a Kali-style hatch, so the
/// real window is only resized once on mouse up.
final class ResizeOverlay {
    private let window: NSWindow

    /// The most recent previewed frame in AX/CG space (top-left origin).
    private(set) var currentAXFrame: CGRect?

    init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = OverlayView()
    }

    func show(axFrame: CGRect) {
        update(axFrame: axFrame)
        window.orderFrontRegardless()
    }

    func update(axFrame: CGRect) {
        currentAXFrame = axFrame
        window.setFrame(Self.appKitFrame(from: axFrame), display: true)
        window.contentView?.needsDisplay = true
    }

    func hide() {
        window.orderOut(nil)
        currentAXFrame = nil
    }

    /// Converts a top-left-origin frame (AX/CG) into AppKit's bottom-left-origin
    /// global space. The menu-bar screen (`screens.first`) defines the origin,
    /// so a single vertical flip is correct across multiple displays.
    private static func appKitFrame(from axFrame: CGRect) -> NSRect {
        guard let primary = NSScreen.screens.first else { return axFrame }
        let flippedY = primary.frame.height - axFrame.origin.y - axFrame.height
        return NSRect(x: axFrame.origin.x, y: flippedY, width: axFrame.width, height: axFrame.height)
    }
}

private final class OverlayView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let accent = NSColor.controlAccentColor

        accent.withAlphaComponent(0.18).setFill()
        bounds.fill()

        // Diagonal hatch ("scanlines").
        accent.withAlphaComponent(0.12).setStroke()
        let hatch = NSBezierPath()
        hatch.lineWidth = 1
        let spacing: CGFloat = 12
        var x = -bounds.height
        while x < bounds.width {
            hatch.move(to: NSPoint(x: x, y: 0))
            hatch.line(to: NSPoint(x: x + bounds.height, y: bounds.height))
            x += spacing
        }
        hatch.stroke()

        // Solid border.
        accent.setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        border.lineWidth = 2
        border.stroke()
    }
}
