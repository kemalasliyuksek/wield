# Icon assets

Source of truth for Wield's iconography.

| File | Purpose |
|---|---|
| `wield.icon/` | Apple **Icon Composer** project (the original design source) |
| `glyph.png` | White line-art glyph exported from `wield.icon` (window + move + resize arrows) |
| `make-icons.swift` | Renders the dark app icon + the menu bar template from `glyph.png` |
| `build-icons.sh` | Convenience wrapper: runs `make-icons.swift` |

## Regenerate

```bash
./build-icons.sh
../build.sh        # rebuild the app to embed the new icons
```

This writes:

- `../Resources/AppIcon.icns` — the **dark** squircle app icon (Finder, Launchpad,
  About, login-items / Accessibility lists). A blue-tinted dark gradient with the
  white glyph and a soft accent glow.
- `../Resources/MenuBarIcon.png` — a **simplified monochrome template** (window +
  4-way move arrow) used in the menu bar. Simplified on purpose so it stays legible
  at ~18 px; the full glyph (with the corner resize arrow) is too busy that small.

To change the artwork, edit `wield.icon` in Icon Composer, export the glyph over
`glyph.png`, then regenerate. Tweak colors/sizes directly in `make-icons.swift`.
