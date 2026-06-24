# mantle Integration Contract — session stream assumptions

This document records the assumptions the `linus-session` package makes about
the mantle binary, config, and CLI. These must be reconciled against
`contracts/mantle-integration.md` (owned by the director/mantle-pkg stream)
once that file lands. Every item tagged **[CONFIRM]** requires verification
against mantle's `src-tauri/` source.

---

## Binary path

| Assumption | Source |
|---|---|
| `/usr/bin/mantle` | Standard Debian package prefix; Tauri 2 `.deb` bundles typically install to `/usr/bin/`. |

**[CONFIRM]** Verify by inspecting the Tauri bundle's `debian/` directory in the mantle repo
or running `dpkg -L mantle` on a built package.

---

## Launch command

| Assumption | CLI |
|---|---|
| Session autostart | `mantle` (no flags required; reads config from standard paths) |

The watchdog scripts invoke `/usr/bin/mantle` with no arguments.

**[CONFIRM]** Check `src-tauri/src/main.rs` or `Cargo.toml [[bin]]` for required flags.
If `--bar`, `--config <path>`, or similar flags are needed, update
`session/scripts/mantle-watchdog.sh` and `session/scripts/mantle-watchdog-hypr.sh`.

---

## Config path resolution

| Priority | Path |
|---|---|
| 1 (user) | `$XDG_CONFIG_HOME/mantle/config.toml` → `~/.config/mantle/config.toml` |
| 2 (system) | `/etc/mantle/config.toml` |

`linus-session` seeds both locations:
- `/etc/skel/.config/mantle/` — new users get this on first login
- `/etc/mantle/` — system-wide fallback for existing users without a personal config

**[CONFIRM]** Verify path priority against `config/loader.rs` in the mantle repo.
Update `mk/session.mk` staging paths if the fallback location differs.

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

When `contracts/mantle-integration.md` lands, verify:

- [ ] Binary path matches
- [ ] No required CLI flags missing from watchdog scripts
- [ ] Config path priority matches mantle's `config/loader.rs`
- [ ] All required env vars are exported in session wrappers
- [ ] Tauri `.deb` Depends already list `sway` or we add it explicitly
