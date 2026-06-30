import CoreGraphics

/// Owns a session-level `CGEventTap` that lets us observe — and crucially
/// *consume* — global mouse events. A passive `NSEvent` monitor cannot swallow
/// events, so the underlying app would still receive the click (e.g. a context
/// menu on right-click). A tap returning `nil` removes the event entirely.
final class EventTapController {
    /// Returns `true` when the event should be consumed (not delivered to apps).
    private let onEvent: (CGEventType, CGEvent) -> Bool

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(onEvent: @escaping (CGEventType, CGEvent) -> Bool) {
        self.onEvent = onEvent
    }

    /// Creates and enables the tap. Returns `false` if the system refuses
    /// (typically because Accessibility permission has not been granted yet).
    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask: CGEventMask =
            (UInt64(1) << CGEventType.leftMouseDown.rawValue) |
            (UInt64(1) << CGEventType.leftMouseDragged.rawValue) |
            (UInt64(1) << CGEventType.leftMouseUp.rawValue) |
            (UInt64(1) << CGEventType.rightMouseDown.rawValue) |
            (UInt64(1) << CGEventType.rightMouseDragged.rawValue) |
            (UInt64(1) << CGEventType.rightMouseUp.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: userInfo
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
    }

    /// Called from the C callback. Handles the system disabling the tap (it
    /// does this if a callback runs too long or on certain user input) by
    /// re-enabling it, otherwise delegates to `onEvent`.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        return onEvent(type, event) ? nil : Unmanaged.passUnretained(event)
    }
}

/// Top-level (non-capturing) trampoline compatible with the C `CGEventTapCallBack`
/// type. The controller is recovered from `userInfo`. Runs on the main run loop.
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<EventTapController>.fromOpaque(userInfo).takeUnretainedValue()
    return controller.handle(type: type, event: event)
}
