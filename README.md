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

**Full-screen surfaces are left alone.** Native full-screen windows, borderless
full-screen games, and full-screen video are never moved or resized even while
Wield is enabled — a gesture there is passed straight through to the app. Only
windowed apps (including maximized ones that keep the menu bar visible) respond.

## Requirements

- macOS 26 (Tahoe) or later
- Swift toolchain (Command Line Tools is enough — full Xcode is **not** required)

## Build & run

```bash
./build.sh
open ./Wield.app
```

`build.sh` compiles with SwiftPM and assembles a proper `.app` bundle
(`LSUIElement`, Info.plist, code signature). It automatically signs with the
most durable code-signing identity it finds — a **Developer ID Application** or
**Apple Development** certificate — so the Accessibility grant survives rebuilds
(see below). With no certificate installed it falls back to an ad-hoc signature.
Override the choice with `WIELD_SIGN_IDENTITY="<identity name>" ./build.sh`.

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
| Skip full-screen apps | `AXFullScreen` attribute + frame-vs-display comparison |

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
    ├── AccessibilityWindow.swift # AX window get/set position & size, full-screen check
    ├── ScreenGeometry.swift      # display bounds + full-screen-cover detection
    ├── ResizeZone.swift          # 8-direction resize math
    └── ResizeOverlay.swift       # accent-colored preview window
```

## Notes / limitations

- **Signing & permission resets:** an ad-hoc signature changes on every rebuild,
  which resets the Accessibility grant (System Settings keeps showing it ON, but
  it stops working, because the entry points at the old code hash). `build.sh`
  avoids this by preferring a real certificate — with a **Developer ID
  Application** or **Apple Development** identity the designated requirement is
  certificate/team-based and stays constant across rebuilds, so the grant
  persists. Only when no certificate is installed does it fall back to ad-hoc;
  in that case, create a self-signed certificate in Keychain Access ▸
  Certificate Assistant and pass it via `WIELD_SIGN_IDENTITY`.
- Some secure/system windows (login window, certain full-screen surfaces)
  cannot be moved via the Accessibility API and are silently ignored.
- Move is applied live; to keep it smooth the window position is derived from a
  cached origin + mouse delta (no per-frame Accessibility read).

## License

MIT — see [LICENSE](LICENSE).
