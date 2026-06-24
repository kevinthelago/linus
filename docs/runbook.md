# Release Runbook

Operational procedures for cutting releases, signing artifacts, rolling back, and maintaining
the `mantle.pin` and `snapshot.pin` dependencies.

See [build.md](build.md) for local build commands and [architecture.md](architecture.md) for
the pipeline overview.

## Cutting a release

### Prerequisites

- You have write access to the `linus` GitHub repository.
- The `LINUS_GPG_KEY` secret is configured in GitHub Actions (Secrets → Actions).
- The `develop` branch is green (all CI jobs pass).
- You have the linus GPG release key available locally if doing a manual step.

### Automated path (normal releases)

1. **Merge `develop` → `main`** via a PR. The three-workflow chain runs automatically:
   - **Build**: `make ci-build` (packages + apt-repo + ISO)
   - **Test**: lintian + QEMU smoke-boot (asserts greeter + mantle session)
   - **Release**: signs ISO and checksums, publishes GitHub Release, pushes apt repo
2. The Release workflow:
   - Tags the commit `vMAJOR.MINOR.PATCH`.
   - Signs `dist/linus.iso` → `dist/linus.iso.asc` and generates `dist/SHA256SUMS` + `dist/SHA256SUMS.asc`.
   - Creates a GitHub Release with the ISO, signature, and checksums attached.
   - Pushes the `stable` apt channel to gh-pages.
3. Verify the release page shows all four assets and the apt repo is reachable at
   `https://kevinthelago.github.io/linus/stable`.

### Choosing the version number

linus uses **semver**:

| Change | Bump |
|---|---|
| New mantle version, new distro features | MINOR |
| Bug-fix or security-only rebuild | PATCH |
| Breaking change to the session/packaging API | MAJOR |

The version is set in `packages/linus-desktop/debian/changelog` and
`packages/mantle/debian/changelog`. Update both before triggering the release.

### Pre-release from `develop`

The same Build → Test → Release chain runs on `develop`. The Release workflow publishes a
**nightly** pre-release to GitHub Releases (tagged `nightly`, marked as pre-release) and
pushes the `testing` apt channel to gh-pages. Users tracking pre-releases add:

```bash
echo "deb https://kevinthelago.github.io/linus/testing trixie main" \
  | sudo tee /etc/apt/sources.list.d/linus-testing.list
```

## Bumping `mantle.pin`

When a new version of mantle ships:

1. Find the commit SHA or tag in the mantle repo.
2. Update `mantle.pin`:
   ```bash
   echo "abc1234def5678" > mantle.pin
   ```
3. Run `make mantle-deb` locally to confirm the mantle build succeeds at the new pin.
4. If mantle introduced new runtime dependencies, update the `Depends` in
   `packages/mantle/debian/control` — cross-reference
   [contracts/mantle-integration.md](../contracts/mantle-integration.md).
5. If mantle changed config schema or token names, update [theming.md](theming.md) and the
   skel files in `packages/linus-branding/`.
6. Commit `mantle.pin` (and any dependent changes) on a branch and open a PR to `develop`.

## Bumping `snapshot.pin`

The trixie snapshot pin is updated deliberately, not automatically, to keep builds
reproducible. To move to a newer trixie snapshot:

1. Choose a recent `snapshot.debian.org` date:
   ```
   https://snapshot.debian.org/archive/debian/YYYYMMDDTHHMMSSZ/
   ```
2. Update `snapshot.pin` with the full snapshot URL.
3. Run `make iso` to verify the new snapshot resolves all required packages.
4. Commit and PR as usual.

Do this before every MINOR release to pick up security fixes in the base system.

## Signing

The GPG key is stored in two GitHub Actions secrets:

Three GitHub Actions secrets gate signing:

| Secret | Contents |
|---|---|
| `GPG_SIGNING_KEY` | ASCII-armored private key. `mk/apt.mk` and the Release workflow import it automatically. |
| `GPG_SIGNING_PASSPHRASE` | Passphrase for the key. Used by `mk/ci-sign`/`ci-checksums` and the Release workflow via `--passphrase-fd`. |
| `LINUS_GPG_KEY` | Key fingerprint, used by reprepro's `SignWith` in `mk/apt.mk`. |

To rotate the signing key:

1. Generate a new key: `gpg --full-generate-key` (RSA 4096 or Ed25519, no expiry or
   long expiry).
2. Export the armored private key and set a passphrase:
   ```bash
   gpg --export-secret-keys --armor <FINGERPRINT> > key.asc
   ```
3. Update all three secrets in GitHub → Settings → Secrets → Actions:
   - `GPG_SIGNING_KEY` ← contents of `key.asc`
   - `GPG_SIGNING_PASSPHRASE` ← the key passphrase
   - `LINUS_GPG_KEY` ← the key fingerprint
4. Export and commit the **public** key:
   ```bash
   gpg --export --armor <FINGERPRINT> > apt/linus-release.gpg
   git add apt/linus-release.gpg && git commit -m "rotate: update release signing key"
   ```
5. Announce the key rotation and provide the new fingerprint in the release notes.

## Rollback

Rollback = republish a prior good release.

1. Find the last good release tag (e.g. `v1.2.3`) in GitHub Releases.
2. Re-run the `publish` workflow manually with `ref: refs/tags/v1.2.3` as the input.
   This re-signs (using the current key) and re-publishes the ISO and apt repo from
   that tag's artifacts.
3. Update the "latest" pointer in the apt repo:
   ```bash
   # CI does this; manually: reprepro re-export the suite from the older snapshot
   ```
4. Post a GitHub Release note on the bad release marking it as retracted, pointing users
   to the rollback version.

Keep the three most recent releases in GitHub Releases. The `publish` job automatically
deletes releases beyond that threshold (excluding pre-releases).

## apt repo structure

The apt repo is hosted on GitHub Pages with two channels:

| Channel | URL | Source branch |
|---|---|---|
| `stable` | `https://kevinthelago.github.io/linus/stable` | `main` |
| `testing` | `https://kevinthelago.github.io/linus/testing` | `develop` |

Each channel has the same internal reprepro layout (codename `trixie`):

```
<channel>/
  dists/
    trixie/
      Release
      Release.gpg
      InRelease
      main/
        binary-amd64/
          Packages
          Packages.gz
  pool/
    main/
      l/linus-desktop/
      m/mantle/
```

The public signing key is at `https://kevinthelago.github.io/linus/stable/linus-release.gpg`.

Users add the stable repo with:

```bash
curl -fsSL https://kevinthelago.github.io/linus/stable/linus-release.gpg \
  | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/linus.gpg

echo "deb https://kevinthelago.github.io/linus/stable trixie main" \
  | sudo tee /etc/apt/sources.list.d/linus.list

sudo apt-get update
```

The codename `trixie` matches `apt/conf/distributions` (`Codename: trixie`). Suite alias `stable` also works.

## Smoke test failures

If the **Test** CI workflow fails on `ci-smoke`:

1. Download the `dist/` artifact from the **Build** run that triggered it.
2. Reproduce locally with the smoke-boot harness:
   ```bash
   make ci-smoke   # builds binary + runs against dist/linus.iso
   ```
   Or run the binary directly for more verbosity:
   ```bash
   target/release/smoke-boot \
     --iso dist/linus.iso --timeout 300 \
     --marker "greetd" --marker "mantle"
   ```
3. For a quick interactive look at the serial console:
   ```bash
   qemu-system-x86_64 -m 2048 -cdrom dist/linus.iso -enable-kvm \
     -nographic -serial mon:stdio
   ```
4. Check the CI job output for the harness log lines (`[smoke-boot] ...`).
5. Common causes:
   - `greetd` marker missing: greetd failed to start (check unit ordering, PAM config)
   - `mantle` marker missing: mantle binary not on PATH or session entry wrong
   - Timeout: PipeWire/D-Bus not ready before mantle (check systemd unit ordering)

## Cross-references

- [build.md](build.md) — `make` targets and local build steps
- [architecture.md](architecture.md) — pipeline diagram and component layout
- [contracts/mantle-integration.md](../contracts/mantle-integration.md) — mantle build/run contract (check when bumping the pin)
- [contracts/system-packages.md](../contracts/system-packages.md) — locked system packages (check when bumping the snapshot)
