# Theming linus

linus ships with the **decorator** persona — a default theme applied on top of mantle's
built-in design tokens. This guide explains where the defaults live, how to override them,
and how the theme flows from files on disk into the running shell.

See [contracts/mantle-integration.md](../contracts/mantle-integration.md) for mantle's full
config schema; this document covers only the linus-specific overrides.

## Where defaults live

| Path | Contents |
|---|---|
| `/etc/skel/.config/mantle/` | Defaults copied into every new user's home on first login via `pam_mkhomedir` |
| `/etc/mantle/` | System-wide fallback used when `~/.config/mantle/` is absent (e.g. for the root user, or when skel copy failed) |

The skel files are shipped by the `linus-session` package. After the first-login copy, the
user owns their config — system upgrades do not overwrite it.

Skel layout:

```
/etc/skel/.config/mantle/
  config.toml          # bar layout, widgets, launcher, session commands
  theme.toml           # color palette and typography (Catppuccin Mocha)
```

## The `config.toml` file

`config.toml` controls mantle's structural layout. The linus defaults:

```toml
# /etc/skel/.config/mantle/config.toml — linus defaults

[compositor]
# "sway" or "hyprland" — detected automatically at runtime if unset.
# backend = "sway"

[bar]
enabled  = true
position = "top"
height   = 40

[widgets]
workspaces    = true
clock         = true
battery       = true
network       = true
audio         = true
notifications = true
tray          = true

[launcher]
enabled = true

[notifications]
enabled    = true
timeout_ms = 5000   # 0 = persistent until dismissed

[session]
lock_cmd   = "swaylock"
logout_cmd = "swaymsg exit"
# suspend/hibernate handed off to systemd-logind
```

See the mantle documentation for the full schema.

## The `theme.toml` file

`theme.toml` defines the color palette and typography. linus ships **Catppuccin Mocha** as the
default dark palette with mauve as the accent color:

```toml
# /etc/skel/.config/mantle/theme.toml — linus defaults (Catppuccin Mocha)

[palette]
mauve     = "#cba6f7"
blue      = "#89b4fa"
text      = "#cdd6f4"
base      = "#1e1e2e"
surface0  = "#313244"
# ... full palette in session/skel/.config/mantle/theme.toml

[colors]
background = "base"
surface    = "surface0"
accent     = "blue"
text       = "text"
error      = "red"
warning    = "yellow"
success    = "green"

[bar]
background_opacity = 0.92

[font]
family      = "Inter, Noto Sans, sans-serif"
size        = 14
mono_family = "Noto Sans Mono, monospace"
```

Override any key in `~/.config/mantle/theme.toml` to personalise without forking the file.

## The `tokens.css` file (webview layer)

In addition to `theme.toml`, the `branding/` assets include `tokens.css` — CSS custom
properties used by mantle's Tauri webview UI. These are installed alongside the branding
assets:

```
/etc/skel/.config/mantle/theme/tokens.css    (per-user skel)
/etc/mantle/theme/tokens.css                 (system fallback)
```

Tokens are scoped under `--mn-`. They are the more granular CSS-layer counterpart to
`theme.toml`; both files are loaded by mantle. See the mantle documentation for the full
`--mn-` token reference.

## Overriding the theme

### Per-user

Edit `~/.config/mantle/theme.toml`. mantle's config watcher reloads on file change — no
restart required.

To reset to the linus defaults:

```bash
cp /etc/skel/.config/mantle/theme.toml ~/.config/mantle/theme.toml
```

For CSS-level overrides (hiding a widget, adjusting a specific component):

```bash
# Create overrides.css targeting mantle component selectors
~/.config/mantle/theme/overrides.css
```

### System-wide (all users)

Edit `/etc/mantle/theme.toml`. This is the fallback and does **not** override per-user config.
To push a system default to existing users, copy the file and provide a migration note in the
package changelog.

## Packaging the decorator

The decorator files live in two places:

| Directory | Contents | Packaged by |
|---|---|---|
| `session/skel/.config/mantle/` | `config.toml`, `theme.toml` — copied to every new user's home | `linus-session` |
| `branding/mantle/` | `config.toml`, `theme/tokens.css`, `theme/overrides.css` — CSS token layer | `linus-branding` |

When building a custom linus spin, replace the files in `session/skel/` and `branding/mantle/`
and rebuild both packages — no other package needs to change.

## Cross-references

- [architecture.md](architecture.md) — how the session/config layer ships these files
- [contracts/mantle-integration.md](../contracts/mantle-integration.md) — mantle's config schema and token API
- [runbook.md](runbook.md) — how to bump the mantle pin when the token API changes
