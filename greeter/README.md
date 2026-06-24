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
