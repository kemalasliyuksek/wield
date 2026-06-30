# Wield

> Wield your windows.

A tiny, fully native (Swift / AppKit / SwiftUI) macOS menu bar tool that brings
the Linux-style "hold a modifier and drag anywhere on a window" behavior to
macOS:

- **Move** — hold the modifier and **left-drag** anywhere inside a window. The
  window follows the cursor live, keeping your exact grab point.
- **Resize** — hold the modifier and **right-drag**. A system-accent preview
  rectangle grows from the nearest edge/corner (8 directions); the window is
  resized once when you release, so there is no live-resize flicker.

Default modifier is **Option (⌥)**; changeable from the menu.

## Requirements

- macOS 26 (Tahoe) or later
- Swift toolchain (Command Line Tools is enough — full Xcode is **not** required)

## Build & run

```bash
./build.sh
open ./Wield.app
```

`build.sh` compiles with SwiftPM and assembles a proper `.app` bundle
(`LSUIElement`, Info.plist, ad-hoc code signature).

### First launch — grant Accessibility

Moving/resizing other apps' windows and consuming global mouse events both
require Accessibility permission. On first launch the app requests it; approve
it under **System Settings ▸ Privacy & Security ▸ Accessibility**, then the tool
starts working (no relaunch needed — it polls for the grant).

### Launch at login

Use **Launch at Login** in the menu. For this to persist, move the app to
`/Applications` first:

```bash
cp -R ./Wield.app /Applications/
open /Applications/Wield.app
```

## Menu

- **Enabled** — master pause/resume.
- **Move / Resize** — enable each gesture independently.
- **Modifier** — Option, Control+Option, Command, or Command+Option.
- **Launch at Login**
- **Quit**

## How it works

| Concern | API |
|---|---|
| Control other apps' windows | Accessibility API (`AXUIElement`, `kAXPositionAttribute`/`kAXSizeAttribute`) |
| Intercept **and consume** global mouse + modifier | `CGEventTap` (a passive `NSEvent` monitor cannot swallow events) |
| Menu bar UI | SwiftUI `MenuBarExtra` |
| Launch at login | `SMAppService` |
| Resize preview | borderless click-through `NSWindow` in the accent color |

Coordinate note: the Accessibility API and Core Graphics events use a top-left
origin, while AppKit windows use bottom-left. The overlay converts between them
using the menu-bar screen height.

## Project layout

```
Wield/
├── Package.swift
├── build.sh
├── Icon/                         # icon source + reproducible generator (see Icon/README.md)
├── Resources/
│   ├── Info.plist
│   ├── AppIcon.icns              # dark app icon (Finder/Launchpad/About)
│   └── MenuBarIcon.png           # simplified monochrome menu bar template
└── Sources/Wield/
    ├── WieldApp.swift            # @main, MenuBarExtra
    ├── AppDelegate.swift         # bootstraps the event tap once trusted
    ├── AppState.swift            # persisted settings + ModifierChoice
    ├── MenuContent.swift         # the menu UI
    ├── Permissions.swift         # Accessibility trust
    ├── LoginItem.swift           # SMAppService launch-at-login
    ├── EventTapController.swift  # CGEventTap create / consume / re-enable
    ├── GestureController.swift   # move (live) + resize (preview) state machine
    ├── AccessibilityWindow.swift # AX window get/set position & size
    ├── ResizeZone.swift          # 8-direction resize math
    └── ResizeOverlay.swift       # accent-colored preview window
```

## Notes / limitations

- **Ad-hoc signing & permission resets:** an ad-hoc signature changes on each
  rebuild, so macOS may ask you to re-grant Accessibility after rebuilding. To
  avoid this during development, sign with a stable self-signed certificate
  (create one in Keychain Access ▸ Certificate Assistant) and replace
  `codesign --sign -` in `build.sh` with `--sign "Your Cert Name"`.
- Some secure/system windows (login window, certain full-screen surfaces)
  cannot be moved via the Accessibility API and are silently ignored.
- Move is applied live; to keep it smooth the window position is derived from a
  cached origin + mouse delta (no per-frame Accessibility read).

## License

MIT — see [LICENSE](LICENSE).
