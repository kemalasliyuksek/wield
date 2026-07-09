import AppKit
import CoreGraphics

/// State machine that turns modifier-qualified mouse gestures into window
/// moves and resizes. Runs entirely on the main thread (the event tap source
/// is attached to the main run loop).
///
/// - Move (left drag): applied live to the real window. The grab offset is
///   preserved by working from a cached initial origin + mouse delta, which
///   also avoids a per-frame Accessibility read.
/// - Resize (right drag): only a translucent overlay follows the cursor; the
///   real window is resized once, on mouse up. This avoids live-resize redraw
///   glitches in the target app.
final class GestureController {
    private enum Mode { case idle, move, resize }

    private let state: AppState
    private let overlay = ResizeOverlay()

    private var mode: Mode = .idle
    private var targetWindow: AccessibilityWindow?
    private var initialMouse: CGPoint = .zero
    private var initialOrigin: CGPoint = .zero
    private var initialFrame: CGRect = .zero
    private var zone = ResizeZone(horizontal: .right, vertical: .bottom)

    private let minSize = CGSize(width: 120, height: 80)

    init(state: AppState) {
        self.state = state
    }

    /// Returns `true` to consume the event so it never reaches other apps.
    func handle(type: CGEventType, event: CGEvent) -> Bool {
        guard state.enabled else { return false }
        let location = event.location

        switch type {
        case .leftMouseDown:
            guard mode == .idle, state.enableMove, modifierMatches(event.flags) else { return false }
            return beginMove(at: location)

        case .leftMouseDragged:
            guard mode == .move else { return false }
            updateMove(to: location)
            return true

        case .leftMouseUp:
            guard mode == .move else { return false }
            finish()
            return true

        case .rightMouseDown:
            guard mode == .idle, state.enableResize, modifierMatches(event.flags) else { return false }
            return beginResize(at: location)

        case .rightMouseDragged:
            guard mode == .resize else { return false }
            updateResize(to: location)
            return true

        case .rightMouseUp:
            guard mode == .resize else { return false }
            commitResize()
            return true

        default:
            return false
        }
    }

    // MARK: - Move

    private func beginMove(at location: CGPoint) -> Bool {
        guard let window = AccessibilityWindow.window(at: location),
              let origin = window.position,
              let size = window.size,
              isGrabbable(window, frame: CGRect(origin: origin, size: size)) else {
            return false
        }
        window.raise()
        targetWindow = window
        initialMouse = location
        initialOrigin = origin
        mode = .move
        return true
    }

    private func updateMove(to location: CGPoint) {
        guard let window = targetWindow else { return }
        let dx = location.x - initialMouse.x
        let dy = location.y - initialMouse.y
        window.position = CGPoint(x: initialOrigin.x + dx, y: initialOrigin.y + dy)
    }

    // MARK: - Resize

    private func beginResize(at location: CGPoint) -> Bool {
        guard let window = AccessibilityWindow.window(at: location),
              let origin = window.position,
              let size = window.size,
              isGrabbable(window, frame: CGRect(origin: origin, size: size)) else {
            return false
        }
        window.raise()
        targetWindow = window
        initialMouse = location
        initialFrame = CGRect(origin: origin, size: size)
        zone = ResizeZone.zone(for: location, in: initialFrame)
        mode = .resize
        overlay.show(axFrame: initialFrame)
        return true
    }

    private func updateResize(to location: CGPoint) {
        let dx = location.x - initialMouse.x
        let dy = location.y - initialMouse.y
        let newFrame = zone.apply(dx: dx, dy: dy, to: initialFrame, minSize: minSize)
        overlay.update(axFrame: newFrame)
    }

    private func commitResize() {
        let finalFrame = overlay.currentAXFrame ?? initialFrame
        targetWindow?.setFrame(finalFrame)
        overlay.hide()
        finish()
    }

    // MARK: - Shared

    private func finish() {
        mode = .idle
        targetWindow = nil
    }

    /// Windows that fill their entire display — native full screen, borderless
    /// full-screen games, full-screen video — are left alone even while the app
    /// is enabled, so a gesture never disturbs an immersive surface. Ordinary
    /// windowed apps (including maximized ones that keep the menu bar visible)
    /// remain grabbable.
    private func isGrabbable(_ window: AccessibilityWindow, frame: CGRect) -> Bool {
        !window.isFullScreen && !ScreenGeometry.coversWholeDisplay(frame)
    }

    /// Exact match on the four main modifiers so a different shortcut (e.g.
    /// the configured key plus Shift) does not accidentally trigger a gesture.
    private func modifierMatches(_ flags: CGEventFlags) -> Bool {
        let mainMask: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
        return flags.intersection(mainMask) == state.modifier.cgFlags
    }
}
