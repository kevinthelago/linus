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

`make iso` drives `lb build` over the `config/` directory:

1. `debootstrap` a trixie chroot from the pinned `snapshot.debian.org` snapshot.
2. Install `linus-desktop` and Calamares from the local `dist/apt/` reprepro tree.
3. Run chroot hooks: apply branding (`9500-grub-brand`), wire the session entry
   (`0200-session`), enable autologin for the live session (`0100-autologin`).
4. Assemble a hybrid GRUB/UEFI ISO with a branded boot menu.
5. Output: `dist/linus.iso` (bootable on UEFI and BIOS, runnable in QEMU).

### 6. CI/CD (GitHub Actions)

Three chained workflows run on every push to `feature/**`, `develop`, and `main`:

| Workflow | Trigger | Steps |
|---|---|---|
| **Build** (`.github/workflows/build.yml`) | push / PR | `make ci-build` (packages + apt-repo + ISO); upload `dist/` and `smoke-boot` binary as artifacts |
| **Test** (`.github/workflows/test.yml`) | after Build succeeds | `make ci-lint` (lintian) + `make ci-smoke` (QEMU headless boot, asserts `greetd` and `mantle` markers) |
| **Release** (`.github/workflows/release.yml`) | after Test succeeds (develop/main only) | sign ISO + checksums; publish GitHub Release (`nightly` from develop, `vX.Y.Z` from main); push apt repo to gh-pages |

The **smoke-boot** harness (`tools/smoke-boot/`) is a Rust binary compiled by CI. It boots
`dist/linus.iso` in QEMU headless and scans the serial console for required text markers.
See [build.md](build.md#smoke-boot-harness) for local usage.

See [runbook.md](runbook.md) for the release flow.

## The three key flows

### Build → ISO

```
CI: make session greeter branding installer-deb
  └─ dist/packages/linus-session_*.deb
  └─ dist/packages/linus-greeter_*.deb
  └─ dist/packages/linus-branding_*.deb
  └─ dist/packages/calamares-settings-linus_*.deb

CI: (mantle-pkg stream) → dist/packages/mantle_*.deb

CI: make meta-package apt-repo
  └─ dist/packages/linus-desktop_*.deb
  └─ dist/apt/ (reprepro, codename: trixie)

CI: make iso
  └─ lb config (trixie snapshot + dist/apt/ linus repo)
  └─ lb build
  └─ dist/linus.iso + dist/linus.iso.sha256

CI: make ci-smoke
  └─ cargo build → tools/smoke-boot/target/release/smoke-boot
  └─ qemu-system-x86_64 (headless, serial QMP)
  └─ assert: "greetd" + "mantle" appear on serial console
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
  config/              # live-build config root
    auto/              # lb auto scripts (config, build, clean)
    hooks/live/        # chroot and binary hooks
    includes.chroot/   # files copied verbatim into the chroot
    package-lists/     # apt package lists for the live image
  branding/            # linus branding assets (icons, wallpaper, GRUB theme, Plymouth, tokens.css)
  session/             # session scripts, compositor configs, mantle defaults (skel)
  greeter/             # greetd + gtkgreet config and PAM
  installer/           # Calamares settings and post-install hook
  packaging/
    meta/              # linus-desktop meta-package (debian/ layout)
    branding/          # linus-branding package (debian/ layout)
    session/           # linus-session and linus-greeter DEBIAN/ stubs
  mk/                  # Makefile fragments (one per build component)
  backports/
    hyprland/          # Hyprland backport recipe from Debian sid
  apt/
    conf/              # reprepro distributions config
  contracts/           # integration seam documents (source of truth)
  docs/                # this documentation
  Makefile             # thin dispatcher: include mk/*.mk
  mantle.pin           # pinned mantle commit SHA
  snapshot.pin         # pinned Debian trixie snapshot date
```

## Cross-references

- [build.md](build.md) — make targets and prerequisites
- [theming.md](theming.md) — the mantle theme layer
- [runbook.md](runbook.md) — operating the release pipeline
- [contracts/mantle-integration.md](../contracts/mantle-integration.md) — mantle build/run/package contract
- [contracts/system-packages.md](../contracts/system-packages.md) — locked trixie package set
