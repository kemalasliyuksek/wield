import AppKit
import SwiftUI

@main
struct WieldApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(state)
        } label: {
            Image(nsImage: Self.menuBarImage)
        }
        .menuBarExtraStyle(.menu)
    }

    /// Brand glyph for the menu bar — a monochrome template so it adapts to the
    /// light/dark menu bar automatically. Falls back to an SF Symbol if the
    /// bundled resource is missing (e.g. when run unbundled).
    private static let menuBarImage: NSImage = {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        let fallback = NSImage(systemSymbolName: "macwindow.on.rectangle",
                               accessibilityDescription: "Wield") ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }()
}
