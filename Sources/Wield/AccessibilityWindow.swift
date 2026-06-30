import ApplicationServices
import CoreGraphics

/// Thin wrapper around an `AXUIElement` that represents a top-level window of
/// another application. All coordinates are in the global top-left origin space
/// used by the Accessibility API and Core Graphics events (NOT AppKit's
/// bottom-left space).
struct AccessibilityWindow {
    let element: AXUIElement

    private static let systemWide = AXUIElementCreateSystemWide()

    /// Returns the front-most window located under the given global point
    /// (top-left origin), walking up the accessibility hierarchy to the
    /// enclosing window element.
    static func window(at point: CGPoint) -> AccessibilityWindow? {
        var ref: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &ref)
        guard result == .success, let element = ref else { return nil }
        return AccessibilityWindow(element: element).enclosingWindow()
    }

    private func enclosingWindow() -> AccessibilityWindow? {
        var current: AXUIElement? = element
        var depth = 0
        while let candidate = current, depth < 25 {
            if Self.role(of: candidate) == (kAXWindowRole as String) {
                return AccessibilityWindow(element: candidate)
            }
            current = Self.parent(of: candidate)
            depth += 1
        }
        return nil
    }

    // MARK: - Geometry

    var position: CGPoint? {
        get { Self.pointValue(of: element, attribute: kAXPositionAttribute) }
        nonmutating set {
            guard let newValue else { return }
            Self.setPoint(newValue, of: element, attribute: kAXPositionAttribute)
        }
    }

    var size: CGSize? {
        get { Self.sizeValue(of: element, attribute: kAXSizeAttribute) }
        nonmutating set {
            guard let newValue else { return }
            Self.setSize(newValue, of: element, attribute: kAXSizeAttribute)
        }
    }

    /// Applies a full frame in one shot. Position is set, then size, then
    /// position again — this defeats clamping where a window refuses to grow
    /// past its current on-screen bounds before being repositioned.
    func setFrame(_ frame: CGRect) {
        Self.setPoint(frame.origin, of: element, attribute: kAXPositionAttribute)
        Self.setSize(frame.size, of: element, attribute: kAXSizeAttribute)
        Self.setPoint(frame.origin, of: element, attribute: kAXPositionAttribute)
    }

    /// Brings the window to the front of its application.
    func raise() {
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }

    // MARK: - AX helpers

    private static func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private static func parent(of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private static func pointValue(of element: AXUIElement, attribute: String) -> CGPoint? {
        guard let axValue = axValue(of: element, attribute: attribute) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    private static func sizeValue(of element: AXUIElement, attribute: String) -> CGSize? {
        guard let axValue = axValue(of: element, attribute: attribute) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }

    private static func axValue(of element: AXUIElement, attribute: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        return (value as! AXValue)
    }

    private static func setPoint(_ point: CGPoint, of element: AXUIElement, attribute: String) {
        var mutablePoint = point
        guard let value = AXValueCreate(.cgPoint, &mutablePoint) else { return }
        AXUIElementSetAttributeValue(element, attribute as CFString, value)
    }

    private static func setSize(_ size: CGSize, of element: AXUIElement, attribute: String) {
        var mutableSize = size
        guard let value = AXValueCreate(.cgSize, &mutableSize) else { return }
        AXUIElementSetAttributeValue(element, attribute as CFString, value)
    }
}
