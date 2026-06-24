# Greeter — greetd + gtkgreet configuration

linus uses **greetd** as its display manager with **gtkgreet** as the Wayland
greeter UI, launched under **cage** so gtkgreet gets an isolated Wayland display.

---

## Files installed to `/etc/greetd/`

| File | Purpose |
|---|---|
| `config.toml` | greetd config for **installed systems** (shows the gtkgreet login UI) |
| `autologin.toml` | greetd config for the **live ISO** (autologins as the live `user`) |
| `gtkgreet.css` | gtkgreet CSS theme (matches the default mantle palette) |

The live ISO activates `autologin.toml` via the systemd drop-in shipped at
`/etc/systemd/system/greetd.service.d/autologin.conf.live-iso`; the live-build
hook renames that file to `autologin.conf` during image assembly. Installed
systems are unaffected.

---

## Session picker

gtkgreet is launched with `-e` which reads session entries from
`/usr/share/wayland-sessions/`. The `linus-session` package ships:

| Entry file | Session name | Compositor |
|---|---|---|
| `linus.desktop` | linus (mantle) | sway + mantle (default) |
| `linus-plain-sway.desktop` | sway (plain) | sway only, no mantle |
| `linus-hyprland.desktop` | linus (Hyprland) | Hyprland + mantle |

`linus.desktop` sorts before the others alphabetically and is therefore the
first (default-selected) entry in the dropdown.

---

## Authentication

greetd uses PAM; the PAM config at `/etc/pam.d/greetd` delegates to the
system `login` stack, which supports local passwords, LDAP, etc.

Auth failures are surfaced by gtkgreet with a retry prompt. There is no
lockout policy at the greeter layer — rely on PAM for that.

---

## Systemd integration

greetd runs as a systemd service (`greetd.service`). The `linus-greeter`
package enables it (via `postinst`) and installs a service drop-in that sets
`Restart=on-failure RestartSec=3` so a greeter crash is recovered
automatically without user intervention.

The `greeter` system user (created by `postinst`) runs the gtkgreet process
under least privilege.

---

## Theming

`/etc/greetd/gtkgreet.css` uses the Catppuccin Mocha palette by default and
references the wallpaper at `/usr/share/backgrounds/linus/default.jpg`
(shipped by the `linus-branding` package).

To customise: edit `/etc/greetd/gtkgreet.css` directly (it is a `conffile` so
`dpkg` will prompt before overwriting on upgrade) or point the `command` in
`config.toml` to a different `-s <stylesheet>` path.

---

## Switching sessions at the greeter

gtkgreet shows a session dropdown populated from `/usr/share/wayland-sessions/`.
The user selects a session before entering credentials; greetd starts the
chosen session's `Exec` command in the authenticated user's context.

---

## Multi-seat and multi-display

greetd supports multi-seat via its `vt` setting — each seat runs its own greetd
instance on a separate VT. linus ships a single default seat configuration
(`vt = "next"`); multi-seat requires separate greetd instances configured
manually under `/etc/greetd/`.

gtkgreet under cage is single-display. For a multi-monitor setup the cage
window appears on the primary output only; secondary outputs are blank until the
user session starts (where the compositor manages all outputs normally).

Multi-seat and multi-display beyond the single-primary-output case are out of
scope for v1. Operators needing multi-seat should configure independent greetd
instances with separate VT and `user` settings per seat.

---

## Edge cases

| Condition | Behaviour |
|---|---|
| `/usr/share/wayland-sessions/` is empty | gtkgreet shows an empty session dropdown; the user can still attempt a login but no session will start. Prevented in practice by the `linus-session` package, which ships three session entries and declares `Depends: linus-session` in `linus-greeter`. |
| gtkgreet crashes | systemd restarts `greetd.service` after 3 s via the `Restart=on-failure` drop-in; the VT is recovered automatically. |
| Auth failure | gtkgreet clears the password field and shows an inline error message; the user can retry immediately. No lockout is applied at the greeter layer — configure PAM (`/etc/pam.d/greetd`) for rate-limiting if required. |
