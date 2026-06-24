# linus

![License](https://img.shields.io/github/license/kevinthelago/linus) ![Last commit](https://img.shields.io/github/last-commit/kevinthelago/linus)

# linus — a Debian-based Linux distribution with mantle as its desktop shell

## Overview

# linus — a Debian-based Linux distribution with mantle as its desktop shell

linus is a bootable, installable Linux distribution that pairs a Debian/Ubuntu base with **mantle** — our Rust + Tauri 2 webview renderer — as the default desktop experience.

## Overview

linus turns mantle from a standalone Wayland layer-shell renderer into the shell of a
real, daily-drivable operating system. We take a stable Debian/Ubuntu base, add a Wayland
compositor, wire in mantle as the bar/widgets/launcher/notification surface, ship a login
greeter and a curated default application set, and bake the whole thing into a reproducible,
installable **ISO image**.

The deliverable is a **bootable distro spin**: a user downloads `linus.iso`, boots it live,
installs it, logs in, and lands in a complete mantle-driven desktop — no manual shell setup.

## What it is

- **Base:** Debian 13 "trixie" (chosen over Ubuntu LTS: modern Wayland/PipeWire, clean
  `live-build`/`mkosi` ISO tooling, no Snap/PPA baggage).
- **Compositor:** a Wayland compositor (sway or Hyprland) running under the session.
- **Shell:** mantle, preconfigured as bar, widgets, app launcher, and notification center,
  bridged to the compositor (IPC), the system bus (UPower / NetworkManager / notifications),
  and audio (PipeWire).
- **Image:** a reproducible build pipeline producing a live-bootable, installable ISO with
  sensible defaults, a greeter, and a curated app set.

## Who it's for

Linux desktop enthusiasts and tinkerers who want a polished, opinionated, web-tech-themeable
Wayland desktop out of the box — without hand-assembling a compositor + shell + dotfiles stack
themselves. (Refined in Users.)

## Success signals

- A freshly built `linus.iso` boots live on real hardware/VM, installs, and logs into a
  working mantle desktop with no manual configuration.
- The mantle shell shows live system state (workspaces, battery, network, audio, notifications)
  and lets the user launch apps and manage the session.
- The image build is reproducible and runs in CI from a clean checkout.

## The central tension (resolved later)

Debian/Ubuntu ship conservative package versions; mantle targets a bleeding-edge stack
(Tauri 2 / webkit2gtk-4.1, Hyprland, native PipeWire). The Stack and Architecture stages
decide how we close that gap — base track choice, backports, or vendoring the few hot
components — so the build stays buildable on the chosen base.

## Scope

# Scope

linus is the **distro / integration layer** that pairs the **existing mantle shell** with a
Debian 13 "trixie" base and ships it as an installable ISO. **Mantle is its own project** —
building the shell's functionality is NOT linus's work; mantle is linked and consumed as a
ready shell artifact. linus owns the OS around it.

## In scope

### Consume mantle (the existing shell)
- **Link the mantle repo** and treat it as a consumed dependency — read its build/run
  contract, its compositor/system/audio bridges, and its session/config model.
- **Package mantle** for the distro: build it into an installable artifact (native `.deb`
  and/or in-image bundle / Flatpak — decided in Architecture) pinned to a mantle release/commit.
- If integration reveals a genuinely missing shell capability, that is filed as an issue in
  **mantle's own repo**, not built here — linus stays the integration layer.

### linus distro (the image — the real work)
- **Base + compositor:** Debian 13 "trixie" with a Wayland compositor (sway and/or Hyprland)
  preconfigured as the session that hosts mantle.
- **Session wiring:** start mantle with the compositor, provide its config, restore layout —
  the glue that makes "login → mantle desktop" work.
- **Greeter / login:** a display manager/greeter offering the **mantle session** (default) and
  a **plain compositor session** as a fallback.
- **Dependency strategy:** satisfy mantle's bleeding-edge deps (Tauri/webkit2gtk-4.1, Hyprland,
  PipeWire) on trixie — backports, vendoring, or shipping them with the mantle package.
- **Curated defaults:** a sensible default app set (terminal, browser, file manager, etc.),
  fonts, theming defaults, and out-of-the-box config.
- **ISO build pipeline:** a reproducible `live-build`/`mkosi` pipeline producing a live-bootable,
  installable ISO, runnable in CI from a clean checkout.
- **Install flow:** an installer (Calamares or the Debian installer) so the live image installs
  to disk.

### Quality bars (part of "done")
- Reproducible image builds and CI that builds the ISO from a clean checkout.
- Smoke/boot tests for the image (boots, reaches greeter, logs into a mantle session) and tests
  for the distro glue (session scripts, packaging).
- Docs: build/run instructions, the mantle-integration contract, theming defaults, architecture
  overview.

## Out of scope (v1)
- **Building mantle's shell features** — owned by the mantle project, not linus.
- A custom compositor of our own (we use sway/Hyprland).
- Non-technical/mainstream-user polish, enterprise fleet management, server/headless images.
- An app store / package-management UI (beyond what the base ships).
- Architectures beyond x86_64 in v1 (ARM/RISC-V later).
- Secure Boot signing / a hardened-distro security posture (later concern).
- Compositors other than sway/Hyprland in v1.

## Open scoping questions (to resolve before fleet launch)
- **sway vs Hyprland as the shipped default** session (one is the default; both may be installable).
- **Installer:** Calamares (graphical, friendlier) vs the Debian installer.
- **mantle packaging:** native `.deb` vs Flatpak vs in-image bundle (decided in Architecture).
- **Dependency strategy** for the few bleeding-edge components (decided in Stack/Architecture).

## Features

- **mantle Package Build** — A reproducible Make target + CI job that builds the EXISTING mantle shell (pinned by commit/tag) into a versioned Debian package the rest of linus consumes. It checks out mantle at the SHA in mantle.pin, runs the documented build (npm ci && npm run tauri:build), takes the Tauri-2-emitted .deb, stamps it to the linus version scheme, augments its runtime Depends per the integration contract, lints it, and drops it in dist/packages/. Edge/error states: invalid or missing pin -> fail fast with a clear message; mantle build failure -> job fails with full logs, NO partial artifact published; Tauri bundle missing/unusable -> documented fallback repackages the release binary+assets via dpkg-deb with a linus-authored control file; webkit2gtk-4.1 version mismatch at build -> surfaced and handled via the vendor fallback in the deps strategy.
- **APT Repo and Dependency Strategy** — Stand up linus's signed apt repository and the reproducibility/dependency strategy. Generates a Debian apt repo (reprepro) from the built .debs, pins the build to a dated snapshot.debian.org trixie snapshot, and resolves the bleeding-edge components (Hyprland; any too-old webkit2gtk-4.1/Tauri dep) via backport or vendored .deb. Owns the locked system-package set in contracts/system-packages.md. Edge/error states: a package missing/too old in trixie -> backport recipe or vendored .deb; GPG key absent locally -> repo builds UNSIGNED with a warning, signed only in CI with the secret; snapshot unreachable -> fail fast with a clear message; version conflict -> the pin wins.
- **Session and Config Layer** — The glue that makes login -> mantle desktop work. Ships the Wayland session entry (/usr/share/wayland-sessions/linus.desktop) that starts sway with mantle autostarted, the sway (default) + Hyprland (alt) configs that exec mantle, the session environment (XDG_CURRENT_DESKTOP, XDG_SESSION_TYPE=wayland, portals), and the default mantle config + theme to /etc/skel/.config/mantle/. Confirms mantle's real config path/CLI against the integration-contract checklist. Edge/error states: mantle binary not on PATH -> session fails visibly with a fallback notice (no black screen); config dir absent for existing users -> system fallback /etc/mantle/; mantle crashes -> the compositor stays up so the user isn't locked out; portal missing -> webview still loads, file dialogs degrade gracefully.
- **linus-desktop Meta-Package** — The linus-desktop meta .deb whose Depends/Recommends pull the entire desktop: mantle, sway (+hyprland), greetd+gtkgreet, pipewire+wireplumber, NetworkManager, UPower, xdg-desktop-portal(-wlr/-gtk), fonts, curated base apps (foot terminal, firefox-esr, a file manager), linus-branding, and the linus-session package. Installing it on trixie yields the linus desktop. Edge/error states: dependency conflict -> meta pins compatible versions; required vs optional split via Depends vs Recommends; removing the meta must leave a bootable base system.
- **Greeter and Session Selection** — greetd + gtkgreet graphical login on Wayland, listing the mantle session (default) and the plain-sway fallback, themed per branding. gtkgreet runs under cage (or sway). Edge/error states: auth failure -> clear error + retry; no sessions found -> safe default; live ISO autologin vs installed-system greeter; greeter crash -> systemd restarts it; multi-seat/multi-display handled or documented.
- **Branding and Identity** — linus's visual identity across the boot+desktop chain: os-release, a Plymouth boot splash theme, default wallpaper, logo/icon set, the default mantle theme tokens, greeter theming, and the ISO volume/boot-menu branding. Edge/error states: Plymouth theme/KMS unavailable -> graceful fallback to text boot; high-DPI wallpaper scaling; trademark-safe naming -> use linus's own marks, set os-release ID=linus, keep required Debian attribution.
- **Calamares Installer** — A branded Calamares graphical installer to install the live linus to disk, forked from calamares-settings-debian, installing linus-desktop + base with partitioning, users, locale, and bootloader. Edge/error states: UEFI vs BIOS; optional LUKS encryption; offline install from the squashfs (no network); partitioning failure -> clear error, no destructive partial; optional OEM/first-boot setup mode.
- **ISO Build Pipeline** — live-build config + hooks assembling the live, installable ISO: trixie base + the linus apt source (carrying mantle/linus-desktop) + the linus-desktop meta + Calamares + greeter autologin + branding + a branded GRUB/boot menu. Driven by make iso, producing a hybrid ISO bootable on UEFI+BIOS and in QEMU. Edge/error states: build needs root/loop devices -> run privileged in a container/CI; reproducibility via the pinned snapshot; ISO size budget tracked; a missing package -> fail with the apt error; Secure Boot shim out of scope for v1.
- **CI CD Pipeline** — GitHub Actions workflows that build the .debs + apt repo + ISO and gate on tests, mapped to the deploy env ladder. Builds mantle.deb + linus-desktop.deb, runs lintian + the QEMU smoke-boot harness asserting the ISO reaches the greeter and a mantle session. Owns the build/test workflow files + the Rust smoke-boot harness (deps locked in dependencies.json). Edge/error states: long ISO builds -> caching + raised timeouts; privileged build -> container; flaky boot test -> single retry; artifact size limits; a UEFI/BIOS smoke matrix.
- **Documentation** — linus's documentation set: README quickstart (download/build/boot), a build guide (make targets, prerequisites, reproducibility, the snapshot/mantle pins), a theming guide for the decorator persona, an architecture overview, and a release runbook. References (does not duplicate) the contracts/. Edge/error states: docs drift -> keep authored alongside the features; link rather than copy the contracts.
- **Release and APT Publishing** — The deploy/CD half: publish the signed ISO to GitHub Releases and host the signed apt repo on GitHub Pages (ghpages) on green main builds, with semver tagging and rollback = republish prior. Owns the publish workflow + apt/release hosting + signing. Edge/error states: signing key only in the CI secret; Pages deploy concurrency; pre-release from develop -> a separate testing apt suite; keep last 3; publish checksums + signatures; a failed publish must leave the existing published repo/releases intact.

## Tech stack

# Stack

linus is a **distro-integration** project: its "stack" is the base OS, the session/compositor,
the packaging + image toolchain, and the contract it consumes from mantle. mantle's own internal
stack (Rust/Tauri 2/React) is documented in the mantle repo and is not re-decided here — linus
only needs mantle's **build, package, and run** contract.

All choices target Debian 13 "trixie" (current stable, 2026).

## Layers

| Layer | Choice | Version | Notes / justification |
|---|---|---|---|
| Base OS | **Debian 13 "trixie"** | stable | Modern Wayland/PipeWire, clean ISO tooling, no Snap/PPA baggage |
| Architecture | **x86_64** | — | Only arch in v1 (ARM later) |
| Display server | **Wayland** | — | mantle is a Wayland layer-shell client; no X11 session |
| Default compositor | **sway** | trixie pkg | Stable, predictable, mature `swayipc` — best "just works" default. Hyprland also installable |
| Alt compositor | **Hyprland** | backport/vendor | Shipped as a selectable session for the decorator audience; may need backport/build (see deps) |
| Shell | **mantle** (consumed) | pinned release/commit | Linked repo; packaged + bundled, not built here |
| Webview runtime | **webkit2gtk-4.1** | trixie pkg | mantle's Tauri 2 dependency; present in trixie (GTK3 webkit) |
| Tray/indicator | **libayatana-appindicator** | trixie pkg | mantle Tauri 2 dependency |
| Audio | **PipeWire** + WirePlumber | trixie pkg | mantle uses the native PipeWire API; system ships PipeWire as default |
| System services | UPower, NetworkManager, `xdg-desktop-portal` | trixie pkg | The D-Bus services mantle bridges to |
| Greeter / DM | **greetd** + **gtkgreet** | trixie pkg | Wayland-native, minimal, supports session selection (mantle vs plain compositor) |
| Installer | **Calamares** | trixie pkg | Graphical installer for the live ISO; friendlier than d-i for a desktop spin |
| Image builder | **live-build** (`lb`) | trixie pkg | Canonical Debian live+installable ISO tool; pairs with Calamares |
| Package format | **`.deb`** (`linus-desktop` meta + `mantle` pkg) | — | Native to the base; meta-package pulls the whole desktop |
| Boot test | **QEMU/KVM** | trixie pkg | Smoke-boot the built ISO headless in CI |
| CI | **GitHub Actions** | — | Builds `.deb`s + ISO from a clean checkout |
| Build orchestration | **make** + shell | — | One `make iso` entry point over lb/debootstrap |

## Dependency strategy (the central tension)
Debian trixie already carries most of what mantle needs — **webkit2gtk-4.1**, **libayatana-appindicator**,
**PipeWire**, **sway**, **NetworkManager**, **UPower**. The hot spots:
- **mantle itself** — built in CI (Rust + Tauri/Vite), packaged as a versioned **`.deb`** pinned to a
  mantle release/commit; its runtime deps are expressed as `.deb` dependencies on trixie packages.
- **Hyprland** — newer than trixie may ship; if the packaged version is too old, **backport** it or
  build it into the image. sway (the default) needs no special handling.
- **Tauri/webkit timing** — verified against trixie at build; if a component is too old, vendor it in
  the mantle `.deb` rather than forcing system upgrades.

## What linus needs FROM mantle (the consumed contract — pinned in Architecture)
- A reproducible **build** command producing a relocatable binary + assets.
- A **packaging** story (how it installs: binary path, desktop entry, default config location).
- A **session** entry: the command that launches mantle under a compositor.
- Its **runtime dependency** list (so the `.deb`/image can declare them).

## Toolchain binaries (recorded in commands.json)
- **linus image work:** `lb` (live-build), `debootstrap`, `mmdebstrap`, `dpkg-deb`, `dpkg-buildpackage`,
  `apt-get`, `xorriso`, `qemu-system-x86_64`, `make`.
- **mantle build (when building its `.deb` in CI):** `cargo`, `rustc`, `node`, `npm`, `pnpm`, `tauri`.

## Architecture

# Architecture

linus is an **integration + image-build** system, not an application. Its architecture is the
set of artifacts and the pipeline that turn "Debian trixie + the existing mantle shell" into a
bootable, installable ISO. mantle's internals live in the mantle repo; linus treats mantle as a
black box behind a pinned contract.

## Components

1. **mantle (consumed, external repo)** — the Wayland layer-shell desktop shell, real and
   substantially built on `develop`: a Tauri 2 app (`src-tauri/`) with `sway`/`hyprland`
   compositor backends behind one trait, a config loader/watcher/schema, a desktop-entry
   launcher, and `zbus`/PipeWire services (power, network, audio, brightness, tray), plus the
   React/TS UI + design system. linus pins it to a release/commit and consumes four things: how
   to build it, how it installs, how it launches under a compositor, and its runtime deps.

2. **`mantle` Debian package** — mantle builds with `npm ci && npm run tauri:build`, and
   **Tauri 2 natively emits a `.deb`** (under `src-tauri/target/release/bundle/deb/`) with the
   binary, a `.desktop` entry, icons, and auto-declared webkit2gtk/appindicator dependencies.
   linus's packaging work is therefore thin: build that `.deb` in CI pinned to a mantle commit,
   add the bits Tauri's bundle omits for a *shell* (a Wayland **session** entry + default
   config), and declare the extra runtime deps (PipeWire, D-Bus services). This is the bridge
   between "mantle the project" and "linus the OS." The exact seam is pinned in
   `contracts/mantle-integration.md`.

3. **`linus-desktop` meta-package** — a `.deb` that depends on everything a linus desktop needs:
   the `mantle` package, **sway** (default) + **Hyprland** (alt), greetd + gtkgreet, PipeWire +
   WirePlumber, NetworkManager, UPower, xdg-desktop-portal(-wlr), fonts, and the curated app set.
   Installing it on any trixie box yields the linus desktop.

4. **Session + config layer** — the glue files: compositor configs (sway/Hyprland) that autostart
   mantle, the greetd config + session entries (mantle session default, plain-compositor fallback),
   mantle's default config/theme, and environment (Wayland env vars, portals). Shipped inside the
   meta-package / image.

5. **Image build pipeline (`live-build`)** — the `lb` config + hooks that assemble a live,
   installable ISO: a trixie base, the linus apt source carrying our `.deb`s, the `linus-desktop`
   meta-package, Calamares for install-to-disk, and branding. Driven by `make iso`.

6. **CI/CD (GitHub Actions)** — builds the `.deb`s, runs them through the image build, boots the
   ISO headless in QEMU as a smoke test, and publishes the ISO + packages as artifacts/releases.

## How they communicate
- **Build-time, not runtime:** components are wired by **packaging and apt dependencies**, not
  network calls. The `mantle` `.deb` → declared deps; `linus-desktop` → depends on `mantle` + the
  session stack; the ISO → installs `linus-desktop` from the linus apt source.
- **mantle ↔ system (at runtime, inside the shell):** mantle talks to the compositor over its IPC
  (`swayipc` / Hyprland socket) and to the system over D-Bus (UPower, NetworkManager,
  Notifications) and PipeWire. linus's job is only to ensure those services are present, running,
  and reachable in the session — it does not mediate them.

## The three key flows
1. **Build → ISO:** CI builds `mantle.deb` → builds `linus-desktop.deb` → `lb build` assembles
   the ISO with Calamares → QEMU smoke-boot → publish. Reproducible from a clean checkout.
2. **Boot → desktop:** ISO boots → greetd/gtkgreet → user picks the **mantle session** → the
   compositor (sway) starts → autostart launches mantle → mantle binds as a layer-shell surface
   and connects to compositor IPC + D-Bus + PipeWire → working desktop.
3. **Install → first run:** live session → Calamares installs trixie + `linus-desktop` to disk →
   reboot → greetd → mantle session → same desktop, persistent.

## Repo ownership (multi-repo)
- **`linus` (new repo)** — owns the meta-package, the session/config layer, the `live-build`
  config + hooks, Calamares config, branding, the `mantle`-packaging recipe, CI, and docs.
- **`mantle` (existing repo, linked)** — owns the shell. linus does not modify it; any missing
  shell capability is filed there.

## Key risks / decisions deferred to the workshop
- **Tauri `.deb` vs shell needs** — Tauri's bundle gives a normal app `.desktop` (launches a
  window); a *shell* needs a Wayland **session** `.desktop` (in `/usr/share/wayland-sessions/`)
  that starts the compositor + autostarts mantle. linus adds this; the contract pins it.
- **mantle config location** — mantle's `config/loader.rs` resolves a config path (likely
  `$XDG_CONFIG_HOME/mantle`); linus must ship sensible defaults to the right place. Confirmed
  against mantle's loader in the workshop. Default if unconfirmed: `/etc/skel/.config/mantle/`.
- **webkit2gtk-4.1 / Tauri on trixie** — verify trixie carries webkit2gtk-4.1 + libayatana at a
  version Tauri 2 accepts at build; vendor in the `.deb` if not.
- **Hyprland on trixie** — package, backport, or build-in; only matters for the alt session.
- **Reproducibility** — pinning the apt snapshot + mantle commit so builds are deterministic.

## Getting started

```bash
git clone https://github.com/kevinthelago/linus.git
cd linus
npm install
npm run dev
cargo build
cargo run
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and our [Code of Conduct](CODE_OF_CONDUCT.md).

## License

See [LICENSE](LICENSE).

---

_Scaffolded by base-studio-code._