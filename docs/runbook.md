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

1. **Merge `develop` → `main`** via a PR. CI on `main` runs the full
   `build-debs → build-iso → smoke → publish` pipeline automatically.
2. The `publish` job:
   - Tags the commit `vMAJOR.MINOR.PATCH`.
   - Signs `dist/linus.iso` with the release key and publishes checksums.
   - Creates a GitHub Release with the ISO, checksum, and apt key attached.
   - Pushes the signed apt repo to the `gh-pages` branch at
     `https://kevinthelago.github.io/linus/apt`.
3. Verify the release page shows the correct assets and the apt repo is reachable.

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

CI on `develop` builds and uploads the ISO as a workflow artifact but does **not** publish
to GitHub Releases or the apt repo. Download the ISO artifact from the Actions run for
testing.

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

| Secret | Contents |
|---|---|
| `GPG_SIGNING_KEY` | ASCII-armored private key (or key fingerprint). `mk/apt.mk` imports armored material automatically at build time. |
| `LINUS_GPG_KEY` | Fingerprint of the key after import, used by reprepro's `SignWith`. |

To rotate the signing key:

1. Generate a new key: `gpg --full-generate-key` (RSA 4096 or Ed25519, no expiry or
   long expiry).
2. Export the armored private key:
   ```bash
   gpg --export-secret-keys --armor <FINGERPRINT> > key.asc
   ```
3. Update `GPG_SIGNING_KEY` in GitHub Secrets with the armored key content.
4. Update `LINUS_GPG_KEY` in GitHub Secrets with the key fingerprint.
5. Export and commit the **public** key:
   ```bash
   gpg --export --armor <FINGERPRINT> > apt/linus-release.gpg
   git add apt/linus-release.gpg && git commit -m "rotate: update release signing key"
   ```
6. Announce the key rotation and provide the new fingerprint in the release notes.

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

The apt repo is hosted on GitHub Pages at `https://kevinthelago.github.io/linus/apt`:

```
apt/
  dists/
    trixie/            # codename (suite alias: stable) — published from main
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
  linus-release.gpg    # public signing key
```

Users add the repo with:

```bash
curl -fsSL https://kevinthelago.github.io/linus/apt/linus-release.gpg \
  | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/linus.gpg

echo "deb https://kevinthelago.github.io/linus/apt trixie main" \
  | sudo tee /etc/apt/sources.list.d/linus.list

sudo apt-get update
```

The codename `trixie` matches `apt/conf/distributions` (`Codename: trixie`). Suite alias `stable` also works.

## Smoke test failures

If the `smoke` CI job fails:

1. Download the ISO artifact from the failed run.
2. Boot it locally:
   ```bash
   qemu-system-x86_64 -m 2048 -cdrom linus.iso -enable-kvm \
     -nographic -serial mon:stdio
   ```
3. Check the smoke harness logs in the CI job output — the harness asserts specific
   markers in the serial output (greeter started, session listed).
4. Common causes:
   - mantle binary not found at the expected path (update the session entry)
   - greetd config references a session file that doesn't exist
   - PipeWire/D-Bus not started before mantle (check systemd unit ordering)

## Cross-references

- [build.md](build.md) — `make` targets and local build steps
- [architecture.md](architecture.md) — pipeline diagram and component layout
- [contracts/mantle-integration.md](../contracts/mantle-integration.md) — mantle build/run contract (check when bumping the pin)
- [contracts/system-packages.md](../contracts/system-packages.md) — locked system packages (check when bumping the snapshot)
