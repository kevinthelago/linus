# Hyprland Backport

Hyprland and its ecosystem are not always available in a given Debian trixie snapshot
at a sufficiently recent version. This directory contains a recipe that:

1. Checks `trixie-backports` first (no build needed if the package is there).
2. Falls back to fetching the source from Debian sid via `snapshot.debian.org` and
   rebuilding for trixie.

## Packages built

The following packages are built in dependency order:

| Package | Role |
|---|---|
| `hyprwayland-scanner` | Wayland protocol code generator (build tool) |
| `hyprutils` | Shared utility library for the Hypr ecosystem |
| `hyprlang` | Configuration language library |
| `hyprcursor` | Cursor theme library |
| `hyprgraphics` | Graphics utilities |
| `aquamarine` | Wayland backend/GPU abstraction library |
| `hyprland` | The Wayland compositor |
| `xdg-desktop-portal-hyprland` | Portal backend for Hyprland sessions |

## Usage

Run inside the CI build container (requires root):

```bash
LINUS_DIST_PACKAGES=dist/packages backports/hyprland/recipe.sh
```

Output `.deb` files land in `dist/packages/` and are then added to the linus apt
repo by `make apt-repo`.

## Updating the backport

1. Change `SID_SNAPSHOT` in `recipe.sh` to a newer `snapshot.debian.org` date.
2. Verify the new hyprland builds cleanly: `make backport-hyprland`.
3. Update `contracts/system-packages.md` if any new packages join the ecosystem.
