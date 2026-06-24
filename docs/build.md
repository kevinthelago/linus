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

| Target | What it does |
|---|---|
| `make iso` | Full build: mantle.deb → linus-desktop.deb → lb build → `dist/linus.iso` |
| `make mantle-deb` | Check out mantle at `mantle.pin`, run `npm ci && npm run tauri:build`, repackage the Tauri-emitted `.deb` with the session entry and linus deps, write to `dist/packages/`. |
| `make linus-deb` | Build the `linus-desktop` meta-package `.deb` (depends on mantle + compositor + session stack). |
| `make apt-repo` | Populate the local `dist/apt/` reprepro tree from `dist/packages/*.deb`. Signs with the key in `$LINUS_GPG_KEY` (unsigned with a warning if unset). |
| `make iso` | Runs `lb build` over the `lb/` config, pulling packages from `dist/apt/` + the pinned trixie snapshot. Output: `dist/linus.iso`. |
| `make smoke` | Boots `dist/linus.iso` in QEMU headless and asserts the ISO reaches the greeter and a mantle session is selectable (Rust harness in `tests/smoke/`). |
| `make clean` | Remove `dist/` and `lb/.build/` build artefacts. Does not remove `dist/packages/` (mantle.deb is expensive to rebuild). |
| `make clean-all` | Remove everything including cached packages. |

### Fast iteration

To skip the mantle rebuild when only changing packaging or session config:

```bash
make linus-deb apt-repo iso
```

To skip the full ISO build and only run the package builds:

```bash
make mantle-deb linus-deb apt-repo
```

## live-build config (`lb/`)

The `lb/` directory is the `live-build` config root:

```
lb/
  config/
    archives/   # linus apt source pointing at dist/apt/
    hooks/      # chroot hooks (branding, session wiring, greeter config)
    package-lists/
      linus.list.chroot   # installs linus-desktop + Calamares from the linus apt source
  auto/
    config      # lb config entrypoint (sets the trixie snapshot, architecture, etc.)
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

Locally, set `LINUS_GPG_KEY` to your key fingerprint before running `make apt-repo`. The
key is only available in CI via a GitHub Actions secret; local builds produce an unsigned
repo with a warning, which is fine for development.

## CI

GitHub Actions runs `make iso && make smoke` on every push to `develop` and `main`. See
[runbook.md](runbook.md) for how CI gates releases and [architecture.md](architecture.md)
for the full pipeline diagram.
