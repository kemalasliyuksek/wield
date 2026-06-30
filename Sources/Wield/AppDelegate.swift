import AppKit

/// Bootstraps the gesture engine: wires the event tap to the gesture controller
/// and waits for Accessibility permission before installing the tap.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var gestureController: GestureController?
    private var eventTapController: EventTapController?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Defensive: LSUIElement already makes this an accessory app.
        NSApp.setActivationPolicy(.accessory)

        let state = AppState.shared
        let gesture = GestureController(state: state)
        gestureController = gesture

        eventTapController = EventTapController { [weak gesture] type, event in
            gesture?.handle(type: type, event: event) ?? false
        }

        // Trigger the system prompt on first launch.
        _ = Permissions.isTrusted(prompt: true)
        state.isTrusted = Permissions.isTrusted

        if !activateTapIfPossible() {
            startPermissionWatcher()
        }
    }

    /// Installs the event tap, but only reports success once the tap is actually
    /// live. Returns false if Accessibility is not granted yet, or if tap
    /// creation fails (which can happen transiently right after the grant).
    @discardableResult
    private func activateTapIfPossible() -> Bool {
        guard Permissions.isTrusted, eventTapController?.start() == true else { return false }
        AppState.shared.isTrusted = true
        return true
    }

    /// Polls until the tap is genuinely live. Crucially it keeps retrying even
    /// when `AXIsProcessTrusted()` already reports true, because the first
    /// `tapCreate` after a fresh grant can fail before the permission fully
    /// propagates — the previous code gave up after one attempt, which looked
    /// like "permission granted but nothing works".
    private func startPermissionWatcher() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            AppState.shared.isTrusted = Permissions.isTrusted
            if self.activateTapIfPossible() {
                timer.invalidate()
                self.permissionTimer = nil
            }
        }
    }
}
