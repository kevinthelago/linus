# Contract: system packages

> **Owned by:** the `packaging` stream. This file is the authoritative locked package list for
> the linus trixie base. Other streams read it; only the packaging stream edits it.

## Trixie snapshot pin

```
https://snapshot.debian.org/archive/debian/20260601T000000Z/
```

All base packages are resolved from this snapshot. The pin is also recorded in `snapshot.pin`
in the repo root. See [docs/build.md](../docs/build.md#pins) for how it is applied.

## Package set

### Required (pulled by `linus-desktop` `Depends`)

| Package | Version constraint | Notes |
|---|---|---|
| `mantle` | `= linus epoch` | Built from `mantle.pin`; see [mantle-integration.md](mantle-integration.md) |
| `sway` | `>= 1.9` | Default compositor |
| `hyprland` | `>= 0.41` | Alt compositor; backport/vendor if trixie ships older |
| `greetd` | `>= 0.10` | Display manager daemon |
| `gtkgreet` | `>= 0.8` | GTK4 greeter for greetd |
| `cage` | `>= 0.1.5` | Wayland kiosk compositor for running gtkgreet |
| `pipewire` | `>= 1.0` | Audio/media server |
| `wireplumber` | `>= 0.5` | PipeWire session manager |
| `networkmanager` | `>= 1.44` | Network management |
| `upower` | `>= 1.90` | Power/battery D-Bus service |
| `xdg-desktop-portal` | `>= 1.18` | XDG portal dispatcher |
| `xdg-desktop-portal-wlr` | `>= 0.7` | wlroots portal backend (screen share etc.) |
| `xdg-desktop-portal-gtk` | `>= 1.15` | GTK portal backend (file dialogs) |
| `libwebkit2gtk-4.1-0` | `>= 2.44` | mantle Tauri 2 webview runtime |
| `libayatana-appindicator3-1` | any | mantle tray indicator library |
| `calamares` | `>= 3.3` | Graphical installer |
| `calamares-settings-debian` | any | Calamares Debian presets (linus forks this) |
| `linus-branding` | `= linus epoch` | Plymouth theme, wallpaper, os-release, mantle defaults |
| `linus-session` | `= linus epoch` | Session scripts and compositor configs |

### Recommended (pulled by `linus-desktop` `Recommends`)

| Package | Notes |
|---|---|
| `foot` | Default terminal emulator |
| `firefox-esr` | Default browser |
| `thunar` | Default file manager |
| `fonts-noto` | Base font set |
| `fonts-noto-color-emoji` | Emoji support |
| `plymouth` | Boot splash (graceful fallback to text if KMS unavailable) |
| `plymouth-theme-linus` | linus Plymouth theme (in `linus-branding`) |

## Dependency strategy for hot spots

### Hyprland

trixie may ship a version older than `0.41`. If so:

1. **Backport** from Debian unstable (`sid`) via `apt-get -t trixie-backports` — preferred if
   the backport exists.
2. **Vendor** a `.deb` built from Hyprland source in CI — fall back if no backport is
   available.

The `packaging` stream owns this decision; the result is a `.deb` in `dist/packages/` and
is declared in this file.

### webkit2gtk-4.1

Tauri 2 requires `libwebkit2gtk-4.1-0 >= 2.44`. Verify against the pinned trixie snapshot
at build time. If the snapshot ships an older version, vendor the newer `.so` inside the
`mantle` `.deb` (not as a system package upgrade).

### mantle itself

Built from source in CI at every release; not taken from any Debian archive.

## Version conflict resolution

When a package conflict arises between the linus apt source and the trixie snapshot:

1. The linus apt source pin **wins** — it has higher `Priority` in the apt config.
2. The packaging stream updates this file to document the conflict and resolution.
3. The affected package version is frozen in `snapshot.pin` until the conflict resolves
   upstream.
