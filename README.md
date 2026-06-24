# linus

![License](https://img.shields.io/github/license/kevinthelago/linus) ![Last commit](https://img.shields.io/github/last-commit/kevinthelago/linus)

**linus** is a bootable, installable Linux distribution that pairs Debian 13 "trixie" with
[mantle](https://github.com/kevinthelago/mantle) — a Rust + Tauri 2 Wayland layer-shell renderer
— as its default desktop shell.

Download `linus.iso`, boot it live, install to disk, and land in a complete mantle-driven desktop.
No manual shell setup required.

## Download

Pre-built ISO images are published to [GitHub Releases](https://github.com/kevinthelago/linus/releases).

```
# Verify the checksum before writing
sha256sum -c linus-<version>.iso.sha256

# Write to USB (replace /dev/sdX with your drive)
sudo dd if=linus-<version>.iso of=/dev/sdX bs=4M status=progress && sync
```

The apt repository is hosted at `https://kevinthelago.github.io/linus/stable` (stable) and
`https://kevinthelago.github.io/linus/testing` (nightly builds from `develop`).

## Install

1. Boot the ISO (UEFI or BIOS — both supported).
2. The live session starts at the **greetd** greeter; log in as `linus` (no password) to reach
   the mantle desktop.
3. Launch **Calamares** from the desktop to install to disk.
4. Reboot — the installed system presents the same greeter and mantle session.

> **Fallback session:** the greeter also lists a plain **sway** session if you need to bypass
> mantle for troubleshooting.

## Build from source

### Prerequisites

Debian 13 "trixie" host (or a matching container/VM) with:

```bash
sudo apt-get install live-build debootstrap mmdebstrap dpkg-dev \
  xorriso qemu-system-x86_64 make gnupg reprepro \
  cargo rustc nodejs npm
```

mantle's build toolchain (`cargo`, `rustc`, `node`, `npm`) is only needed if you build the
mantle package locally; CI fetches a pre-built artifact by default.

### Quick start

```bash
git clone https://github.com/kevinthelago/linus.git
cd linus
make iso
```

The finished ISO is written to `dist/linus.iso`. See [docs/build.md](docs/build.md) for all
`make` targets, the snapshot pin, and reproducibility details.

### Smoke test

```bash
make ci-smoke      # builds smoke-boot binary, boots the ISO in QEMU, asserts greeter + mantle
```

## Documentation

| Document | Contents |
|---|---|
| [docs/build.md](docs/build.md) | `make` targets, prerequisites, the snapshot/mantle pins, reproducibility |
| [docs/architecture.md](docs/architecture.md) | Package/image pipeline and the mantle integration seam |
| [docs/theming.md](docs/theming.md) | Overriding mantle's theme tokens and CSS for the decorator persona |
| [docs/runbook.md](docs/runbook.md) | Cutting a release, signing, rollback, bumping `mantle.pin` |

Integration contracts (consumed by docs and other streams):

| Contract | Contents |
|---|---|
| [contracts/mantle-integration.md](contracts/mantle-integration.md) | Build, package, session, and runtime-dep contract with the mantle repo |
| [contracts/system-packages.md](contracts/system-packages.md) | Locked system-package set and the trixie snapshot pin |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and our [Code of Conduct](CODE_OF_CONDUCT.md).

## License

See [LICENSE](LICENSE).
