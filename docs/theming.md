# Theming linus

linus ships with the **decorator** persona — a default theme applied on top of mantle's
built-in design tokens. This guide explains where the defaults live, how to override them,
and how the theme flows from files on disk into the running shell.

See [contracts/mantle-integration.md](../contracts/mantle-integration.md) for mantle's full
config schema; this document covers only the linus-specific overrides.

## Where defaults live

| Path | Contents |
|---|---|
| `/etc/skel/.config/mantle/` | Defaults copied into every new user's home on first login |
| `/etc/mantle/` | System-wide fallback used when `~/.config/mantle/` is absent (e.g. for the root user, or when skel copy failed) |

The files under `/etc/skel/.config/mantle/` are shipped by the `linus-branding` package.
They are copied to `~/.config/mantle/` by the session initialisation script on first login.
After that copy, the user owns their config — system upgrades do not overwrite it.

Typical skel layout:

```
/etc/skel/.config/mantle/
  config.toml          # top-level mantle config (bar layout, launcher, notifications)
  theme/
    tokens.css         # design token overrides (colors, radii, spacing, typography)
    overrides.css      # additional component-level CSS (optional, empty by default)
```

## Design tokens

mantle resolves design tokens from CSS custom properties. linus's `tokens.css` declares
overrides in the `:root` scope; mantle's built-in defaults apply for any token not listed here.

```css
/* /etc/skel/.config/mantle/theme/tokens.css  — linus decorator defaults */
:root {
  /* Surface */
  --mn-color-surface:          #1e1e2e;
  --mn-color-surface-overlay:  rgba(30, 30, 46, 0.85);
  --mn-color-border:           rgba(255, 255, 255, 0.08);

  /* Text */
  --mn-color-text-primary:     #cdd6f4;
  --mn-color-text-secondary:   #a6adc8;
  --mn-color-text-disabled:    #585b70;

  /* Accent */
  --mn-color-accent:           #cba6f7;   /* mauve */
  --mn-color-accent-hover:     #d9b8ff;

  /* Status */
  --mn-color-success:          #a6e3a1;
  --mn-color-warning:          #f9e2af;
  --mn-color-error:            #f38ba8;

  /* Geometry */
  --mn-radius-bar:             8px;
  --mn-radius-widget:          12px;
  --mn-radius-launcher:        16px;

  /* Typography */
  --mn-font-family:            "Noto Sans", sans-serif;
  --mn-font-size-base:         13px;
  --mn-font-size-label:        11px;

  /* Spacing */
  --mn-bar-height:             36px;
  --mn-bar-padding:            0 12px;
  --mn-widget-gap:             8px;

  /* Backdrop blur (compositor must support wlr-layer-shell blur ext) */
  --mn-backdrop-blur:          12px;
}
```

Tokens are scoped under the `--mn-` namespace. Variables outside this namespace are not part
of the mantle public API and may change between mantle releases.

## Overriding the theme

### Per-user

Edit `~/.config/mantle/theme/tokens.css`. mantle's config watcher reloads the theme on file
change — no restart required.

To reset to the linus defaults, remove or replace the file with the skel copy:

```bash
cp /etc/skel/.config/mantle/theme/tokens.css ~/.config/mantle/theme/tokens.css
```

### System-wide (all users)

Edit `/etc/mantle/theme/tokens.css`. This file is the fallback; it does **not** override
per-user config. To push a system default to existing users, copy the file and inform users
to merge it (or provide a migration script in a package postinst).

### Component-level CSS

`overrides.css` is imported after `tokens.css` and accepts arbitrary CSS targeting mantle's
component selectors. Use it for adjustments that tokens cannot express (e.g. hiding a specific
widget, adjusting a single component's layout).

mantle component selectors are documented in the mantle repo's UI design-system docs. They are
considered semi-stable — minor version bumps may rename selectors; check the mantle changelog
when bumping `mantle.pin`.

## The `config.toml` file

`config.toml` controls mantle's structural layout — which widgets appear on the bar, the
launcher hotkey, notification timeout, and so on. The linus decorator ships an opinionated
default:

```toml
# /etc/skel/.config/mantle/config.toml  — linus decorator defaults

[bar]
position = "top"
height   = 36
modules_left  = ["workspaces", "launcher"]
modules_right = ["tray", "audio", "network", "battery", "clock"]

[launcher]
hotkey = "Super+Space"

[notifications]
timeout = 5000   # ms

[theme]
tokens   = "theme/tokens.css"
overrides = "theme/overrides.css"
```

See the mantle documentation for the full schema.

## Packaging the decorator

The decorator defaults are packaged in `linus-branding`:

```
packages/linus-branding/
  debian/
    control          # Package: linus-branding
    install          # copies skel and /etc/mantle/ files
  skel/
    .config/mantle/
      config.toml
      theme/
        tokens.css
        overrides.css
  system/
    etc/mantle/      # system fallback (same files)
```

When building a custom linus spin (a respin or downstream), replace the files in
`packages/linus-branding/skel/` and rebuild `linus-branding` — no other package needs to
change.

## Cross-references

- [architecture.md](architecture.md) — how the session/config layer ships these files
- [contracts/mantle-integration.md](../contracts/mantle-integration.md) — mantle's config schema and token API
- [runbook.md](runbook.md) — how to bump the mantle pin when the token API changes
