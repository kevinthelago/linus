# linus System Package Contract

> **Owned by:** the `packaging` stream. This file is the authoritative locked package list for
> the linus trixie base. Other streams read it; only the packaging stream edits it.

Locked apt/system package set for linus 1.0 (Debian trixie base).
This file is the single source of truth — `linus-desktop` `Depends`/`Recommends` and
the image build both draw from it. Update here first; update the meta-package second.

---

## Trixie Snapshot Pin

All base packages are resolved from this snapshot:

```
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] \
    http://snapshot.debian.org/archive/debian/20260601T000000Z/ trixie main contrib
```

Current pin date: **20260601T000000Z**

The pin is also recorded in `snapshot.pin` in the repo root. See
[docs/build.md](../docs/build.md#pins) for how it is applied.
Update `SNAPSHOT` in `mk/apt.mk` and both files together when intentionally advancing the pin.

---

## Compositor

| Package | Version constraint | Source | Notes |
|---|---|---|---|
| `sway` | `>= 1.9` | trixie snapshot | Default Wayland compositor |
| `swaybg` | any | trixie snapshot | Wallpaper daemon |
| `swaylock` | any | trixie snapshot | Screen locker |
| `swayidle` | any | trixie snapshot | Idle/DPMS management |
| `hyprland` | `>= 0.41` | trixie-backports or `backports/hyprland/` | Alt compositor; see `backports/hyprland/` |
| `xdg-desktop-portal-hyprland` | any | same as hyprland | Portal backend for Hyprland sessions |

---

## Greeter / Display Manager

| Package | Version constraint | Source | Notes |
|---|---|---|---|
| `greetd` | `>= 0.10` | trixie snapshot | Systemd-native DM; PAM-based |
| `gtkgreet` | `>= 0.8` | trixie snapshot | GTK greeter UI for greetd |
| `cage` | `>= 0.1.5` | trixie snapshot | Wayland kiosk compositor hosting gtkgreet |

---

## Audio

| Package | Version constraint | Source | Notes |
|---|---|---|---|
| `pipewire` | `>= 1.0` | trixie snapshot | Audio/video routing daemon |
| `pipewire-audio` | any | trixie snapshot | Default audio client profile |
| `pipewire-pulse` | any | trixie snapshot | PulseAudio compatibility shim |
| `wireplumber` | `>= 0.5` | trixie snapshot | PipeWire session and policy manager |
| `libspa-0.2-bluetooth` | any | trixie snapshot | Bluetooth audio (via PipeWire) |

---

## Networking & Power

| Package | Version constraint | Source | Notes |
|---|---|---|---|
| `network-manager` | `>= 1.44` | trixie snapshot | Network management daemon |
| `network-manager-gnome` | any | trixie snapshot | nm-applet system-tray indicator |
| `upower` | `>= 1.90` | trixie snapshot | Power management D-Bus service |
| `brightnessctl` | any | trixie snapshot | Backlight brightness control |

---

## Desktop Integration

| Package | Version constraint | Source | Notes |
|---|---|---|---|
| `xdg-desktop-portal` | `>= 1.18` | trixie snapshot | Portal framework (file dialogs, screen capture, etc.) |
| `xdg-desktop-portal-wlr` | `>= 0.7` | trixie snapshot | Wayland (wlroots) portal backend |
| `xdg-desktop-portal-gtk` | `>= 1.15` | trixie snapshot | GTK file-chooser portal backend |
| `polkitd` | any | trixie snapshot | polkit daemon (renamed from `polkit` in bookworm) |
| `mate-polkit` | any | trixie snapshot | Authentication agent (pkexec GUI prompts). `polkit-gnome`/`policykit-1-gnome` do not exist in trixie |
| `xdg-utils` | any | trixie snapshot | `xdg-open` and MIME helpers |

---

## mantle Runtime Dependencies

Declared as `Depends` on the `mantle` `.deb` directly; listed here for auditability and
to guard against accidental removal from the snapshot.

| Package | Version constraint | Source | Notes |
|---|---|---|---|
| `libwebkit2gtk-4.1-0` | `>= 2.44` | trixie snapshot | Tauri 2 webview runtime (GTK 3 variant) |
| `libayatana-appindicator3-1` | any | trixie snapshot | System-tray support for mantle |

---

## Fonts

| Package | Version constraint | Source | Notes |
|---|---|---|---|
| `fonts-noto` | any | trixie snapshot | Core Noto font family |
| `fonts-noto-color-emoji` | any | trixie snapshot | Color emoji |
| `fonts-noto-mono` | any | trixie snapshot | Monospace variant |

---

## Curated Applications

| Package | Version constraint | Source | Notes |
|---|---|---|---|
| `foot` | any | trixie snapshot | Default terminal emulator (Wayland-native) |
| `firefox-esr` | any | trixie snapshot | Default web browser |
| `thunar` | any | trixie snapshot | Default file manager |
| `gvfs` | any | trixie snapshot | Virtual filesystem (USB, MTP, network shares) |
| `gvfs-backends` | any | trixie snapshot | GVFS protocol backends |
| `plymouth` | any | trixie snapshot | Boot splash (graceful fallback to text if KMS unavailable) |

---

## linus-Specific Packages (from linus apt repo)

Built by other streams; consumed here as apt dependencies.

| Package | Version constraint | Built by stream | Role |
|---|---|---|---|
| `mantle` | `= linus epoch` | `mantle-pkg` | The Wayland shell — built from `mantle.pin` |
| `linus-session` | `= linus epoch` | `desktop` | Wayland session entry + compositor configs |
| `linus-branding` | `= linus epoch` | `branding` | Plymouth theme, wallpaper, os-release, mantle defaults |
| `linus-desktop` | — | `packaging` (this) | Meta-package pulling all of the above |

See [contracts/mantle-integration.md](mantle-integration.md) for the mantle build/run contract.

---

## ISO Build Tools (build-time only — not installed on the target system)

| Package | Version constraint | Source | Notes |
|---|---|---|---|
| `live-build` | any | trixie snapshot | Debian live + installable ISO builder |
| `reprepro` | any | trixie snapshot | Apt repository management |
| `calamares` | `>= 3.3` | trixie snapshot | Graphical installer for the live image |
| `calamares-settings-debian` | any | trixie snapshot | Calamares Debian presets (linus forks this) |
| `qemu-system-x86_64` | any | trixie snapshot | Smoke-boot test runner in CI |
| `lintian` | any | trixie snapshot | Debian package quality checker |
| `devscripts` | any | trixie snapshot | Debian developer scripts (backport builds) |
| `build-essential` | any | trixie snapshot | C/C++ toolchain |
| `equivs` | any | trixie snapshot | Build-dep satisfaction helper |

---

## Dependency Strategy for Hot Spots

### Hyprland

trixie may ship a version older than `0.41`. If so:

1. **Backport** from Debian sid via `snapshot.debian.org` — preferred; see `backports/hyprland/`.
2. **Vendor** a `.deb` built in CI from Hyprland source — fallback if no backport succeeds.

The `packaging` stream owns this decision; the result is a `.deb` in `dist/packages/`.

### webkit2gtk-4.1

Tauri 2 requires `libwebkit2gtk-4.1-0 >= 2.44`. Verified against the pinned snapshot at build
time. If the snapshot ships an older version, vendor the newer `.so` inside the `mantle` `.deb`
(not as a system package upgrade).

### mantle itself

Built from source in CI at every release (pinned to `mantle.pin`); not taken from any Debian
archive.

---

## Version Conflict Resolution

When a package conflict arises between the linus apt source and the trixie snapshot:

1. The linus apt source pin **wins** — it has higher `Priority` in the apt config.
2. The packaging stream updates this file to document the conflict and resolution.
3. The affected package version is frozen until the conflict resolves upstream.

---

## Adding or Removing Packages

1. Update the relevant table above (and add the version constraint if known).
2. Update `packaging/meta/debian/control` (`Depends` or `Recommends`).
3. Verify the package exists in the pinned snapshot:
   ```bash
   apt-cache -o Dir::Etc::sourcelist=/dev/null \
       -o Dir::Etc::sourceparts=/dev/null \
       policy <package>
   ```
4. If missing from the snapshot → add a backport recipe under `backports/<pkg>/`.
5. Commit both files in the same commit.
