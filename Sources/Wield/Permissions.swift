import AppKit
import ApplicationServices

/// Accessibility (AX) permission helpers. Both the event tap and window
/// move/resize require the app to be trusted in
/// System Settings ▸ Privacy & Security ▸ Accessibility.
enum Permissions {
    /// Current trust status without prompting.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Checks trust and, when `prompt` is true and not yet trusted, asks the
    /// system to show the standard "grant Accessibility" prompt.
    @discardableResult
    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens the Accessibility pane in System Settings.
    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
