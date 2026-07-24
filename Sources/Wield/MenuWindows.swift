import CoreGraphics

/// Detects whether any menu — a context menu, a menu-bar menu, a status-item
/// menu — is currently open somewhere on screen.
///
/// While a menu is up, every click belongs to the menu-tracking session: it
/// either selects an item or dismisses the menu. Consuming such a click for a
/// gesture would leave the menu stuck and the selection dead, so gestures must
/// not start at all in that state.
enum MenuWindows {
    /// Open menus are the only ordinary windows placed exactly at the pop-up
    /// menu level, so an exact match identifies them without catching floating
    /// panels, the Dock, or overlay windows at other elevated levels.
    private static let menuLayer = Int(CGWindowLevelForKey(.popUpMenuWindow))

    static func anyOpen() -> Bool {
        guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
                as? [[String: Any]] else {
            return false
        }
        return windows.contains { window in
            window[kCGWindowLayer as String] as? Int == menuLayer
                && (window[kCGWindowAlpha as String] as? Double ?? 0) > 0
        }
    }
}
