# Architecture

linus is an **integration and image-build system**, not an application. Its architecture is the
set of artifacts and the pipeline that turns "Debian 13 trixie + the existing mantle shell" into
a bootable, installable ISO.

mantle's internals (Rust/Tauri 2/React) live in the mantle repo. linus treats mantle as a black
box behind a pinned contract — see [contracts/mantle-integration.md](../contracts/mantle-integration.md).

## Components

```
┌──────────────────────────────────────────────────────────────┐
│  linus repo                                                  │
│                                                              │
│  mantle.pin ──► mantle build ──► mantle.deb                 │
│                                       │                      │
│  session/config layer ────────────────┤                      │
│  (sway cfg, greetd, /etc/skel)        │                      │
│                                       ▼                      │
│                              linus-desktop.deb               │
│                                       │                      │
│  snapshot.pin ──► lb config ──────────┤                      │
│                   (Calamares,         ▼                      │
│                    branding,    live-build ──► linus.iso     │
│                    hooks)             │                      │
│                                       ▼                      │
│                               QEMU smoke test                │
│                                       │                      │
│                                       ▼                      │
│                              GitHub Release                  │
│                              + apt repo (gh-pages)           │
└──────────────────────────────────────────────────────────────┘
```

### 1. mantle (consumed, external repo)

The Wayland layer-shell desktop shell — a Tauri 2 app with sway/Hyprland compositor backends,
a config loader/watcher, a desktop-entry launcher, and zbus/PipeWire services (power, network,
audio, brightness, tray), plus the React/TS UI and design system.

linus pins mantle to a release commit in `mantle.pin` and consumes four things:

- How to **build** it (`npm ci && npm run tauri:build`)
- How it **installs** (binary path, desktop entry, config location)
- How it **launches** under a compositor (the session command)
- Its **runtime dependency** list

The full binding is in [contracts/mantle-integration.md](../contracts/mantle-integration.md).

### 2. `mantle` Debian package

`make mantle-deb` checks out mantle at `mantle.pin`, runs the documented build, and
repackages the Tauri-emitted `.deb` with:

- A Wayland **session entry** (`/usr/share/wayland-sessions/linus.desktop`) — Tauri's bundle
  ships a normal `.desktop`; a shell needs a session entry that starts the compositor and
  autostarts mantle.
- **Default config** at `/etc/skel/.config/mantle/` (see [theming.md](theming.md)).
- Extra runtime `Depends`: PipeWire, D-Bus services (UPower, NetworkManager,
  xdg-desktop-portal-wlr).

The output `.deb` lands in `dist/packages/`.

### 3. `linus-desktop` meta-package

A `.deb` whose `Depends`/`Recommends` pull the full desktop onto a bare trixie install:

| Category | Packages |
|---|---|
| Shell | `mantle` |
| Compositor (default) | `sway` |
| Compositor (alt) | `hyprland` |
| Greeter | `greetd`, `gtkgreet`, `cage` |
| Audio | `pipewire`, `wireplumber` |
| System services | `networkmanager`, `upower`, `xdg-desktop-portal`, `xdg-desktop-portal-wlr`, `xdg-desktop-portal-gtk` |
| Apps | `foot` (terminal), `firefox-esr`, `thunar` (files) |
| Fonts | `fonts-noto`, `fonts-noto-color-emoji` |
| Branding | `linus-branding` |
| Session glue | `linus-session` |

`Depends` covers required components; non-critical items use `Recommends` so the package
remains installable in constrained environments.

### 4. Session and config layer

The glue that makes **login → mantle desktop** work:

| File | Purpose |
|---|---|
| `/usr/share/wayland-sessions/linus.desktop` | Session entry: starts sway, which autostarts mantle |
| `/etc/sway/config.d/linus.conf` | sway config fragment: `exec mantle`, IPC socket, env vars |
| `/etc/hyprland/linus.conf` | Hyprland equivalent for the alt session |
| `/etc/greetd/config.toml` | Runs gtkgreet under cage; lists mantle session as default |
| `/etc/skel/.config/mantle/` | Default mantle config and theme tokens shipped to new users |
| `/etc/mantle/` | System fallback config (used when `~/.config/mantle/` is absent) |

Session environment set for mantle:

```
XDG_CURRENT_DESKTOP=linus
XDG_SESSION_TYPE=wayland
WAYLAND_DISPLAY=wayland-1
DBUS_SESSION_BUS_ADDRESS=...
```

Failure modes:
- **mantle binary not on PATH** → sway autostart fails; the compositor stays up with a
  fallback notice (no black screen).
- **mantle crashes** → the compositor stays up; the user can relaunch or switch sessions.
- **config dir absent** → system falls back to `/etc/mantle/`.

### 5. Image build pipeline (`live-build`)

`make iso` drives `lb build` over the `lb/` config:

1. `debootstrap` a trixie chroot from the pinned `snapshot.debian.org` snapshot.
2. Install `linus-desktop` and `Calamares` from the local `dist/apt/` reprepro tree.
3. Run chroot hooks: apply branding, set the greeter to autologin in the live session.
4. Assemble a hybrid GRUB/UEFI ISO with a branded boot menu.
5. Output: `dist/linus.iso` (bootable on UEFI and BIOS, runnable in QEMU).

### 6. CI/CD (GitHub Actions)

| Job | Trigger | Steps |
|---|---|---|
| `build-debs` | push to `develop`/`main`, PR | `make mantle-deb linus-deb apt-repo` → upload to artifacts |
| `build-iso` | after `build-debs` passes | `make iso` → upload ISO artifact |
| `smoke` | after `build-iso` | `make smoke` (QEMU headless boot, asserts greeter + session) |
| `publish` | push to `main`, green `smoke` | sign + push apt repo to gh-pages; create GitHub Release |

See [runbook.md](runbook.md) for the release flow.

## The three key flows

### Build → ISO

```
CI: make mantle-deb
  └─ checkout mantle@<mantle.pin>
  └─ npm ci && npm run tauri:build
  └─ repackage .deb with session entry + linus deps
  └─ dist/packages/mantle_*.deb

CI: make linus-deb apt-repo
  └─ dist/packages/linus-desktop_*.deb
  └─ dist/apt/ (reprepro)

CI: make iso
  └─ lb build (trixie snapshot + dist/apt/)
  └─ dist/linus.iso

CI: make smoke
  └─ qemu-system-x86_64 -cdrom dist/linus.iso
  └─ assert: greeter visible, mantle session listed
```

### Boot → desktop

```
BIOS/UEFI → GRUB → Linux kernel → systemd
  └─ greetd starts gtkgreet (under cage)
  └─ user selects "linus" (mantle session)  [default]
  └─ sway starts
  └─ sway autostart: exec mantle
  └─ mantle binds as wlr-layer-shell surface
  └─ mantle connects: swayipc + D-Bus + PipeWire
  └─ working desktop
```

### Install → first run

```
live session → launch Calamares
  └─ partition disk, set locale/user
  └─ install trixie + linus-desktop from squashfs (offline)
  └─ install GRUB bootloader
  └─ reboot

installed system → GRUB → systemd → greetd → mantle session (same as above)
```

## Repo layout

```
linus/
  lb/                  # live-build config
    config/
      archives/        # apt sources
      hooks/           # chroot hooks
      package-lists/
    auto/config
  packages/
    mantle/            # mantle .deb packaging recipe
    linus-desktop/     # meta-package
    linus-session/     # session glue files
    linus-branding/    # branding assets
  tests/
    smoke/             # Rust QEMU smoke-boot harness
  contracts/           # integration seam documents (source of truth)
  docs/                # this documentation
  Makefile
  mantle.pin
  snapshot.pin
```

## Cross-references

- [build.md](build.md) — make targets and prerequisites
- [theming.md](theming.md) — the mantle theme layer
- [runbook.md](runbook.md) — operating the release pipeline
- [contracts/mantle-integration.md](../contracts/mantle-integration.md) — mantle build/run/package contract
- [contracts/system-packages.md](../contracts/system-packages.md) — locked trixie package set
