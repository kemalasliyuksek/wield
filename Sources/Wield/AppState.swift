import Combine
import CoreGraphics
import Foundation

/// The modifier the user holds to arm move/resize gestures.
enum ModifierChoice: String, CaseIterable, Identifiable {
    case option
    case controlOption
    case command
    case commandOption

    var id: String { rawValue }

    var title: String {
        switch self {
        case .option: return "Option (⌥)"
        case .controlOption: return "Control + Option (⌃⌥)"
        case .command: return "Command (⌘)"
        case .commandOption: return "Command + Option (⌘⌥)"
        }
    }

    var cgFlags: CGEventFlags {
        switch self {
        case .option: return [.maskAlternate]
        case .controlOption: return [.maskControl, .maskAlternate]
        case .command: return [.maskCommand]
        case .commandOption: return [.maskCommand, .maskAlternate]
        }
    }
}

/// Shared, persisted user settings plus live permission status. Mutated and
/// observed on the main thread.
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: Keys.enabled) } }
    @Published var enableMove: Bool { didSet { defaults.set(enableMove, forKey: Keys.enableMove) } }
    @Published var enableResize: Bool { didSet { defaults.set(enableResize, forKey: Keys.enableResize) } }
    @Published var modifier: ModifierChoice { didSet { defaults.set(modifier.rawValue, forKey: Keys.modifier) } }

    /// Reflects whether Accessibility permission is currently granted.
    @Published var isTrusted: Bool

    /// Toggling this registers/unregisters the login item via SMAppService.
    @Published var launchAtLogin: Bool { didSet { LoginItem.setEnabled(launchAtLogin) } }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let enabled = "enabled"
        static let enableMove = "enableMove"
        static let enableResize = "enableResize"
        static let modifier = "modifier"
    }

    private init() {
        // didSet does not fire for assignments made during initialization,
        // so loading persisted values here has no side effects.
        enabled = (defaults.object(forKey: Keys.enabled) as? Bool) ?? true
        enableMove = (defaults.object(forKey: Keys.enableMove) as? Bool) ?? true
        enableResize = (defaults.object(forKey: Keys.enableResize) as? Bool) ?? true
        let rawModifier = defaults.string(forKey: Keys.modifier) ?? ModifierChoice.option.rawValue
        modifier = ModifierChoice(rawValue: rawModifier) ?? .option
        isTrusted = Permissions.isTrusted
        launchAtLogin = LoginItem.isEnabled
    }
}
