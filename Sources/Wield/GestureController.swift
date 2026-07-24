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
/// - A right *click* (press and release without crossing `clickSlop`) is not
///   a gesture: it is replayed to the app so modifier-aware context menus
///   (e.g. Finder's Option variants) keep working while Wield is enabled.
final class GestureController {
    private enum Mode { case idle, move, resize }

    private let state: AppState
    private let overlay = ResizeOverlay()

    private var mode: Mode = .idle
    private var targetWindow: AccessibilityWindow?
    private var initialMouse: CGPoint = .zero
    private var initialOrigin: CGPoint = .zero
    private var initialFrame: CGRect = .zero
    private var initialFlags: CGEventFlags = []
    private var hasDragged = false
    private var zone = ResizeZone(horizontal: .right, vertical: .bottom)

    private let minSize = CGSize(width: 120, height: 80)
    /// Cursor travel below this many points counts as a click, not a drag.
    private let clickSlop: CGFloat = 4

    init(state: AppState) {
        self.state = state
    }

    /// Returns `true` to consume the event so it never reaches other apps.
    func handle(type: CGEventType, event: CGEvent) -> Bool {
        guard state.enabled, !Self.isSynthetic(event) else { return false }
        let location = event.location

        switch type {
        case .leftMouseDown:
            guard mode == .idle, state.enableMove, modifierMatches(event.flags),
                  !MenuWindows.anyOpen() else { return false }
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
            guard mode == .idle, state.enableResize, modifierMatches(event.flags),
                  !MenuWindows.anyOpen() else { return false }
            return beginResize(at: location, flags: event.flags)

        case .rightMouseDragged:
            guard mode == .resize else { return false }
            updateResize(to: location)
            return true

        case .rightMouseUp:
            guard mode == .resize else { return false }
            if hasDragged {
                commitResize()
            } else {
                replayAsRightClick()
            }
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

    /// Consumes the right-down provisionally. Raising the window and showing
    /// the overlay wait until the cursor actually travels (`updateResize`), so
    /// that a plain click can still be replayed untouched — with no overlay
    /// flash and no z-order change the app never asked for.
    private func beginResize(at location: CGPoint, flags: CGEventFlags) -> Bool {
        guard let window = AccessibilityWindow.window(at: location),
              let origin = window.position,
              let size = window.size,
              isGrabbable(window, frame: CGRect(origin: origin, size: size)) else {
            return false
        }
        targetWindow = window
        initialMouse = location
        initialFlags = flags
        initialFrame = CGRect(origin: origin, size: size)
        zone = ResizeZone.zone(for: location, in: initialFrame)
        hasDragged = false
        mode = .resize
        return true
    }

    private func updateResize(to location: CGPoint) {
        let dx = location.x - initialMouse.x
        let dy = location.y - initialMouse.y
        if !hasDragged {
            guard hypot(dx, dy) > clickSlop else { return }
            hasDragged = true
            targetWindow?.raise()
            overlay.show(axFrame: initialFrame)
        }
        let newFrame = zone.apply(dx: dx, dy: dy, to: initialFrame, minSize: minSize)
        overlay.update(axFrame: newFrame)
    }

    private func commitResize() {
        let finalFrame = overlay.currentAXFrame ?? initialFrame
        targetWindow?.setFrame(finalFrame)
        overlay.hide()
        finish()
    }

    /// The consumed right-down turned out to be a plain click, not a resize:
    /// cancel the gesture and replay the click (original modifiers included)
    /// so the app opens its context menu as if Wield were not there. The
    /// replayed events carry `syntheticMarker`, which `handle` passes through.
    private func replayAsRightClick() {
        let location = initialMouse
        let flags = initialFlags
        finish()

        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        source.userData = Self.syntheticMarker
        for type in [CGEventType.rightMouseDown, .rightMouseUp] {
            guard let click = CGEvent(
                mouseEventSource: source,
                mouseType: type,
                mouseCursorPosition: location,
                mouseButton: .right
            ) else { continue }
            click.flags = flags
            click.setIntegerValueField(.mouseEventClickState, value: 1)
            click.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Shared

    private func finish() {
        mode = .idle
        targetWindow = nil
        hasDragged = false
    }

    private static let syntheticMarker: Int64 = 0x5749_454C_44 // "WIELD"

    private static func isSynthetic(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == syntheticMarker
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
