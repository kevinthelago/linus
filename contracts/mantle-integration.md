# Contract: mantle integration

> **Owned by:** the `mantle-pkg` stream. This file is the authoritative integration seam between
> the mantle shell project and linus's packaging/session layer. Do not duplicate its contents
> in docs — link to it.

This contract pins the four things linus needs from mantle:

1. **Build command** — how CI builds the mantle binary and assets.
2. **Package layout** — where the Tauri-emitted `.deb` puts the binary, desktop entry, icons,
   and what `Depends` it auto-declares.
3. **Session entry** — the command that launches mantle under a compositor.
4. **Runtime dependencies** — the D-Bus services, PipeWire, and portal packages mantle requires
   at runtime beyond what Tauri's bundle declares.

---

## 1. Build

```bash
# Check out mantle at the SHA in mantle.pin, then:
npm ci
npm run tauri:build
# Tauri 2 emits a .deb at:
src-tauri/target/release/bundle/deb/mantle_<version>_amd64.deb
```

The build requires: `cargo`, `rustc`, `node ≥ 20`, `npm`, webkit2gtk-4.1 headers,
libayatana-appindicator headers.

## 2. Package layout (Tauri-emitted `.deb`)

| Path | Contents |
|---|---|
| `/usr/bin/mantle` | Main binary |
| `/usr/share/applications/mantle.desktop` | App desktop entry (normal window launch) |
| `/usr/share/icons/hicolor/…/apps/mantle.png` | Icon set |
| `Depends:` | `libwebkit2gtk-4.1-0`, `libayatana-appindicator3-1` |

linus's repackaging step adds:

| Path | Contents |
|---|---|
| `/usr/share/wayland-sessions/linus.desktop` | Wayland session entry |
| `/etc/skel/.config/mantle/` | Default config + theme tokens |
| Extra `Depends:` | `pipewire`, `wireplumber`, `networkmanager`, `upower`, `xdg-desktop-portal`, `xdg-desktop-portal-wlr` |

## 3. Session entry

```ini
# /usr/share/wayland-sessions/linus.desktop
[Desktop Entry]
Name=linus (mantle)
Comment=linus desktop with mantle shell
Exec=/usr/bin/linus-session
Type=Application
DesktopNames=linus
```

`/usr/bin/linus-session` starts the compositor (sway by default) which autostarts mantle via
its config (`exec mantle`).

## 4. Runtime dependencies

mantle requires the following to be present and running in the session at startup:

| Service | Interface |
|---|---|
| compositor | `swayipc` socket (sway) or Hyprland socket |
| PipeWire | PipeWire native API (audio + screen capture) |
| WirePlumber | PipeWire session manager |
| `org.freedesktop.NetworkManager` | D-Bus system bus |
| `org.freedesktop.UPower` | D-Bus system bus |
| `org.freedesktop.Notifications` | D-Bus session bus |
| `org.freedesktop.portal.Desktop` | xdg-desktop-portal (via wlr or gtk backend) |

The linus session script ensures these are started before mantle is exec'd.

## 5. Config path

mantle resolves config from (in priority order):

1. `$MANTLE_CONFIG_DIR` (if set)
2. `$XDG_CONFIG_HOME/mantle/` (default: `~/.config/mantle/`)
3. `/etc/mantle/` (system fallback)

linus ships defaults to `/etc/skel/.config/mantle/` (copied to `~` on first login) and
`/etc/mantle/` (permanent fallback). See [docs/theming.md](../docs/theming.md).
