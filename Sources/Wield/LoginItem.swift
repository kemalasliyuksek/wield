import Foundation
import ServiceManagement

/// Wraps `SMAppService` for launch-at-login. Requires a signed app bundle in a
/// stable location (e.g. /Applications) to persist reliably.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("Wield: login item update failed: \(error.localizedDescription)")
        }
    }
}
