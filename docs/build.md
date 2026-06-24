# Building linus

This guide covers every `make` target, host prerequisites, the snapshot and mantle pins that
guarantee reproducible builds, and how to iterate locally.

See [architecture.md](architecture.md) for the pipeline overview and
[contracts/system-packages.md](../contracts/system-packages.md) for the locked package set.

## Host prerequisites

A **Debian 13 "trixie"** host (bare metal, VM, or container) is required. The build uses
`live-build` and loop devices — it must run as root inside a privileged container or directly
on the host.

```bash
sudo apt-get install \
  live-build debootstrap mmdebstrap \
  dpkg-dev dpkg-buildpackage \
  xorriso qemu-system-x86_64 qemu-utils \
  make gnupg reprepro \
  cargo rustc nodejs npm
```

`cargo`/`rustc`/`nodejs`/`npm` are only needed when building the `mantle` Debian package
locally (`make mantle-deb`). The default ISO build pulls a pre-built `mantle.deb` from CI.

## Pins

Two files anchor reproducibility:

| File | Purpose |
|---|---|
| `mantle.pin` | The mantle repo commit SHA (or tag) linus packages. Bump it to track a new mantle release — see [runbook.md](runbook.md). |
| `snapshot.pin` | The `snapshot.debian.org/debian` date-stamped snapshot URL for the trixie base. Fixes the exact set of base packages across builds. |

Both files are committed to the repository. CI enforces that builds use the pinned values.

## `make` targets

Run `make help` to list all targets from the `mk/*.mk` includes.

### Component package builds

| Target | What it does |
|---|---|
| `make session` | Build `linus-session_*.deb` from `session/` into `dist/packages/`. |
| `make greeter` | Build `linus-greeter_*.deb` from `greeter/` into `dist/packages/`. |
| `make branding` | Build `linus-branding_*.deb` from `branding/` into `dist/packages/`. |
| `make installer-deb` | Build `calamares-settings-linus_*.deb` from `installer/` into `dist/packages/`. |
| `make installer-check` | Validate YAML/shell syntax of all Calamares config files (runs automatically before `installer-deb`). |
| `make meta-package` | Build `linus-desktop_*.deb` (the meta-package) from `packaging/meta/` into `dist/packages/`. |
| `make backport-hyprland` | Build Hyprland `.deb`s from Debian sid source via `backports/hyprland/recipe.sh`. |

> **mantle package**: the `mantle` `.deb` is built by the `mantle-pkg` stream and fetched as
> a CI artifact. To build it locally, see `contracts/mantle-integration.md`.

### Repository and image

| Target | What it does |
|---|---|
| `make apt-repo` | Populate `dist/apt/` (reprepro) from `dist/packages/*.deb`. Signs with `$LINUS_GPG_KEY` or `$GPG_SIGNING_KEY`; unsigned with a warning if neither is set. |
| `make iso` | Full ISO build: `iso-clean` → `iso-config` → `iso-build`. Requires root or a privileged container (loop devices). |
| `make iso-config` | Run `lb config` only — reads `config/auto/config`, injects the snapshot and linus repo URL. |
| `make iso-build` | Run `lb build` only; outputs `dist/linus.iso` + `dist/linus.iso.sha256`. Must run as root. |
| `make iso-clean` | Remove live-build artefacts (`lb clean --purge` + `dist/linus.iso`). |
| `make iso-size` | Report ISO size vs the 2 048 MiB budget. |

### Cleanup (per component)

Each component exposes a `*-clean` target (`session-clean`, `greeter-clean`, `branding-clean`,
`installer-clean`, `meta-package-clean`, `apt-repo-clean`). There is no single top-level
`make clean` — run each component's clean target explicitly, or chain them:

```bash
make session-clean greeter-clean branding-clean installer-clean meta-package-clean apt-repo-clean iso-clean
```

### Fast iteration

To rebuild only packaging and session files without touching mantle:

```bash
make session greeter branding installer-deb meta-package apt-repo iso
```

To build all packages without running the ISO build:

```bash
make session greeter branding installer-deb meta-package apt-repo
```

### CI targets (`mk/ci.mk`)

These targets mirror what GitHub Actions runs, so you can reproduce CI locally:

| Target | What it does |
|---|---|
| `make ci-build` | `make packages apt-repo iso` — full artifact build |
| `make ci-lint` | Run lintian on all `dist/*.deb` (fails on any error) |
| `make ci-smoke` | Build the smoke-boot binary then boot the ISO in QEMU headless and assert markers |
| `make ci-test` | `ci-lint` + `ci-smoke` |
| `make ci-sign` | GPG detach-sign `dist/linus.iso` → `dist/linus.iso.asc` (requires `$GPG_SIGNING_PASSPHRASE`) |
| `make ci-checksums` | Generate and sign `dist/SHA256SUMS` |

## Smoke-boot harness

The QEMU smoke-boot harness is a Rust crate at `tools/smoke-boot/` in a Cargo workspace
(root `Cargo.toml`). The compiled binary lands at `target/release/smoke-boot`.

```bash
# Build the binary (workspace root)
cargo build --manifest-path tools/smoke-boot/Cargo.toml --release

# Run against a local ISO
target/release/smoke-boot \
  --iso dist/linus.iso \
  --timeout 300 \
  --marker "greetd" \
  --marker "mantle"
```

The harness boots the ISO headless in `qemu-system-x86_64` with a serial console and QMP
socket. It scans the serial output for each `--marker` string, and exits 0 only when all
markers appear before `--timeout` seconds elapses. QEMU is shut down gracefully via QMP
after the check completes (or forcefully killed on timeout).

`make ci-smoke` wraps this with the standard markers and the `dist/linus.iso` path.

## live-build config (`config/`)

The `config/` directory is the live-build config root:

```
config/
  auto/
    config      # lb config entrypoint (injects snapshot date, arch, linus repo URL)
    build       # lb build hook
    clean       # lb clean hook
  hooks/live/
    0100-autologin.hook.chroot    # enable autologin for the live session
    0200-session.hook.chroot      # wire the linus session entry
    9500-grub-brand.hook.binary   # inject linus GRUB theme
  includes.chroot/
    usr/share/wayland-sessions/   # linus.desktop session entry shipped into the chroot
  package-lists/
    linus.list.chroot             # installs linus-desktop from the linus apt source
```

The live image uses **autologin** to the `linus` user for the live session; the installed
system switches to the full greetd login flow.

## Reproducibility

Reproducible builds depend on three locks:

1. **`snapshot.pin`** — the trixie apt snapshot date. All base packages come from this
   snapshot; no live `deb.debian.org` hits during the build.
2. **`mantle.pin`** — the exact mantle commit. `make mantle-deb` checks out this SHA before
   building.
3. **Cargo.lock / package-lock.json inside mantle** — mantle's own build is reproducible
   within its repo; linus pins the entry point.

CI verifies reproducibility by building twice from a clean checkout and diffing the ISO
checksum.

## Signing

The apt repository and ISO checksum are signed with the linus release GPG key. The public key
is distributed at `https://kevinthelago.github.io/linus/apt/linus-release.gpg`.

Locally, set `LINUS_GPG_KEY` to your key fingerprint before running `make apt-repo`. In CI
the secret is named `GPG_SIGNING_KEY`; `mk/apt.mk` accepts either variable. Local builds
without a key produce an unsigned repo with a warning, which is fine for development.

## CI

GitHub Actions runs `make iso && make smoke` on every push to `develop` and `main`. See
[runbook.md](runbook.md) for how CI gates releases and [architecture.md](architecture.md)
for the full pipeline diagram.
