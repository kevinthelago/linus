# mantle Integration Contract — session stream notes

This document records how the `linus-session` package implements the integration
seam defined in `contracts/mantle-integration.md`. Items marked **[CONFIRM]**
still need verification against mantle's `src-tauri/` source; everything else
has been reconciled against the contract.

---

## Binary path

| Path | Source |
|---|---|
| `/usr/bin/mantle` | Confirmed in `contracts/mantle-integration.md` §2 package layout. |

---

## Launch command

| CLI | Status |
|---|---|
| `mantle` (no flags) | Assumed; contract §3 shows `exec mantle` in sway config with no flags. **[CONFIRM]** against `src-tauri/src/main.rs` — update watchdog scripts if flags are required. |

The watchdog scripts invoke `/usr/bin/mantle` with no arguments.

---

## Config path resolution

Confirmed in `contracts/mantle-integration.md` §5:

| Priority | Path |
|---|---|
| 1 | `$MANTLE_CONFIG_DIR` (if set) |
| 2 | `$XDG_CONFIG_HOME/mantle/` → `~/.config/mantle/` |
| 3 | `/etc/mantle/` (system fallback) |

`linus-session` seeds both writable locations:
- `/etc/skel/.config/mantle/` — new users get this on first login via pam_mkhomedir
- `/etc/mantle/` — permanent system-wide fallback for existing users

---

## Required runtime environment

The session wrapper (`linus-session.sh`) exports these before starting sway;
sway's `90-mantle.conf` propagates them to `systemd --user` and `dbus-daemon`:

| Variable | Value | Purpose |
|---|---|---|
| `XDG_CURRENT_DESKTOP` | `sway` | Activates `xdg-desktop-portal-wlr` for screen capture |
| `XDG_SESSION_DESKTOP` | `linus` | Branding identity; does not affect portal selection |
| `XDG_SESSION_TYPE` | `wayland` | Tells toolkits to use Wayland backends |
| `WAYLAND_DISPLAY` | set by sway | mantle connects to the compositor socket |
| `SWAYSOCK` | set by sway | mantle uses swayipc for IPC |

**[CONFIRM]** If mantle also needs `DBUS_SESSION_BUS_ADDRESS` or compositor-specific
vars (e.g. `HYPRLAND_INSTANCE_SIGNATURE`), add them to the session wrappers.

---

## Compositor IPC

mantle talks to sway over its Unix socket (`$SWAYSOCK`) using swayipc.
The socket is set automatically by sway before `exec` commands run, so no
explicit path configuration is needed in the default case.

For Hyprland, mantle uses `$HYPRLAND_INSTANCE_SIGNATURE`; the Hyprland session
wrapper and `hyprland/mantle.conf` propagate this variable.

---

## Failure behaviour

If mantle exits with a non-zero code:
- **sway sessions**: `mantle-watchdog.sh` calls `swaynag -t warning` — a persistent
  bar across the bottom of the screen with a recovery message. The compositor
  keeps running; the user can open a terminal and run `mantle` to restart.
- **Hyprland sessions**: `mantle-watchdog-hypr.sh` opens a recovery terminal
  (foot → alacritty → kitty → xterm) with the same message.

A clean exit (code 0) from mantle — e.g. user-initiated quit — is passed through
without showing a warning.

---

## Reconciliation checklist

Reconciled against `contracts/mantle-integration.md` (landed 2026-06-24):

- [x] Binary path `/usr/bin/mantle` — confirmed §2
- [x] Session entry Exec changed to `/usr/bin/linus-session` — confirmed §3
- [x] Config path priority — confirmed §5
- [x] Extra Depends added to `linus-session`: pipewire, wireplumber, network-manager, upower — confirmed §4
- [x] DesktopNames changed from `linus;sway` to `linus` — confirmed §3
- [ ] CLI flags for mantle binary — **[CONFIRM]** against `src-tauri/src/main.rs`
- [ ] All required env vars present — **[CONFIRM]** if mantle needs DBUS_SESSION_BUS_ADDRESS
