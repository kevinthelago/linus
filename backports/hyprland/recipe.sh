#!/usr/bin/env bash
# Hyprland backport recipe for Debian trixie.
#
# Tries trixie-backports first. Falls back to fetching source from Debian sid
# via snapshot.debian.org and rebuilding for trixie.
#
# Must run as root inside a trixie build container.
# Usage: LINUS_DIST_PACKAGES=dist/packages ./recipe.sh

set -euo pipefail

# --- Configuration -----------------------------------------------------------

# Debian sid snapshot to pull source packages from when backports are absent.
# Override via env (mk/apt.mk passes it from snapshot.pin automatically).
SID_SNAPSHOT="${SID_SNAPSHOT:-http://snapshot.debian.org/archive/debian/20260601T000000Z}"

OUTPUT_DIR="${LINUS_DIST_PACKAGES:-dist/packages}"

# Hyprland ecosystem build order (dependencies before dependents).
ECOSYSTEM=(
    hyprwayland-scanner
    hyprutils
    hyprlang
    hyprcursor
    hyprgraphics
    aquamarine
    hyprland
    xdg-desktop-portal-hyprland
)

# --- Helpers -----------------------------------------------------------------

need_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "ERROR: recipe.sh must run as root (use a build container)." >&2
        exit 1
    fi
}

hyprland_in_backports() {
    apt-cache policy hyprland 2>/dev/null | grep -q 'trixie-backports'
}

# Try to satisfy with pre-built trixie-backports packages. Returns 0 on success.
try_from_backports() {
    echo "==> Checking trixie-backports for hyprland ecosystem..."
    if ! hyprland_in_backports; then
        echo "    Not found in trixie-backports."
        return 1
    fi
    echo "==> Found in trixie-backports; downloading .deb files..."
    mkdir -p "${OUTPUT_DIR}"
    for pkg in "${ECOSYSTEM[@]}"; do
        apt-get download "${pkg}/trixie-backports" 2>/dev/null || true
    done
    find . -maxdepth 1 -name "*.deb" -exec mv {} "${OUTPUT_DIR}/" \;
    echo "==> Backport .debs saved to ${OUTPUT_DIR}/"
    return 0
}

# Build one source package from Debian sid for trixie.
build_from_sid() {
    local pkg="$1"
    local builddir
    builddir="$(mktemp -d "/tmp/linus-backport-${pkg}-XXXXXX")"
    trap "rm -rf '${builddir}'" RETURN

    echo ""
    echo "==> Building ${pkg} from Debian sid (${SID_SNAPSHOT})..."

    # Temporary sid-src entry for this fetch
    local sid_list="/etc/apt/sources.list.d/linus-backport-sid-src.list"
    cat > "${sid_list}" <<EOF
deb-src [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] \
    ${SID_SNAPSHOT}/ sid main
EOF
    apt-get update -qq

    cd "${builddir}"
    apt-get source --only-source "${pkg}" -t sid -qq

    local srcdir
    srcdir="$(find "${builddir}" -maxdepth 1 -mindepth 1 -type d | head -n1)"
    if [ -z "${srcdir}" ]; then
        echo "ERROR: apt-get source produced no directory for ${pkg}" >&2
        rm -f "${sid_list}"
        return 1
    fi

    cd "${srcdir}"

    # Stamp as a trixie backport
    dch --bpo --distribution trixie-backports \
        "Backported to Debian trixie from sid for the linus distribution."

    # Install build-time dependencies
    mk-build-deps \
        --install \
        --remove \
        --tool "apt-get -y --no-install-recommends" \
        debian/control

    # Build binary-only (no source upload)
    dpkg-buildpackage -us -uc -b -j"$(nproc)"

    # Collect .deb output (dpkg-buildpackage writes to the parent directory)
    mkdir -p "${OUTPUT_DIR}"
    find "${builddir}" -maxdepth 1 -name "*.deb" \
        -exec cp {} "${OUTPUT_DIR}/" \;

    # Remove temporary sid source and refresh
    rm -f "${sid_list}"
    apt-get update -qq

    echo "    ${pkg}: .deb files written to ${OUTPUT_DIR}/"
}

# Install freshly built packages so later ecosystem builds can see them.
install_built() {
    local pkg="$1"
    # Install any matching .deb; tolerate "already installed at same version".
    find "${OUTPUT_DIR}" -maxdepth 1 -name "${pkg}_*.deb" \
        -exec dpkg -i {} \; 2>/dev/null || true
}

# --- Main --------------------------------------------------------------------

main() {
    need_root

    mkdir -p "${OUTPUT_DIR}"

    if try_from_backports; then
        echo ""
        echo "==> Hyprland ecosystem satisfied from trixie-backports."
        echo "    Output: ${OUTPUT_DIR}/"
        return 0
    fi

    echo "==> Building Hyprland ecosystem from sid source..."
    apt-get install -y --no-install-recommends \
        devscripts \
        build-essential \
        equivs \
        dpkg-dev \
        debian-keyring

    for pkg in "${ECOSYSTEM[@]}"; do
        build_from_sid "${pkg}"
        install_built "${pkg}"
    done

    echo ""
    echo "==> Hyprland ecosystem built successfully."
    echo "    Output: ${OUTPUT_DIR}/"
    ls "${OUTPUT_DIR}"/hypr*.deb "${OUTPUT_DIR}"/aquamarine*.deb 2>/dev/null || true
}

main "$@"
