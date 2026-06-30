import SwiftUI

/// The menu bar dropdown. Intentionally minimal and English-only.
struct MenuContent: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        if !state.isTrusted {
            Button("Grant Accessibility Permission…") {
                Permissions.openSettings()
            }
            Text("Accessibility access is required.")
            Divider()
        }

        Toggle("Enabled", isOn: $state.enabled)

        Divider()

        Toggle("Move (Modifier + Left Drag)", isOn: $state.enableMove)
        Toggle("Resize (Modifier + Right Drag)", isOn: $state.enableResize)

        Picker("Modifier", selection: $state.modifier) {
            ForEach(ModifierChoice.allCases) { choice in
                Text(choice.title).tag(choice)
            }
        }

        Divider()

        Toggle("Launch at Login", isOn: $state.launchAtLogin)

        Divider()

        Button("Quit Wield") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
