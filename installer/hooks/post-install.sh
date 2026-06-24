#!/bin/bash
# Post-install hook — runs inside the installed target chroot via Calamares shellprocess.
# Configures greetd, cleans up live-session artifacts, and verifies the mantle session.
set -euo pipefail

# ---------------------------------------------------------------------------
# greetd — Wayland-native greeter configuration
# ---------------------------------------------------------------------------

mkdir -p /etc/greetd

# gtkgreet under cage: renders a GTK login screen on a bare Wayland compositor.
# The -l flag enables a layer-shell layout; CSS theming provided by linus-branding.
cat > /etc/greetd/config.toml << 'EOF'
[terminal]
vt = 1

[default_session]
command = "cage -s -- gtkgreet -l -s /usr/share/linus/greeter.css"
user = "greeter"
EOF

# gtkgreet reads sessions from the XDG wayland-sessions directory.
# List them explicitly so it offers mantle first, sway second, and a shell escape.
cat > /etc/greetd/environments << 'EOF'
mantle
sway
bash
EOF

# The greeter system user is created by the greetd package; create it defensively
# in case the package left it out (e.g. dpkg --no-triggers race during unpackfs).
if ! id greeter &>/dev/null; then
    useradd --system --no-create-home --shell /usr/sbin/nologin \
            --home-dir /var/lib/greeter greeter
fi

# ---------------------------------------------------------------------------
# Remove live-session artifacts from the installed system
# ---------------------------------------------------------------------------

# live-boot initramfs hook — not needed in the installed system.
rm -f /etc/initramfs-tools/hooks/live
rm -f /etc/initramfs-tools/conf.d/live.conf
rm -f /etc/live/config.conf.d/*.conf 2>/dev/null || true

# Calamares autostart entry — installer must not appear in the installed desktop.
rm -f /etc/xdg/autostart/calamares.desktop 2>/dev/null || true

# live-session autologin config (live-build typically writes this for greetd/tty).
rm -f /etc/greetd/config.toml.live 2>/dev/null || true

# ---------------------------------------------------------------------------
# Hostname / hosts
# ---------------------------------------------------------------------------

# networkcfg already writes /etc/hostname; fill in a safe default if it is absent.
if [ ! -s /etc/hostname ]; then
    echo "linus" > /etc/hostname
fi

HOSTNAME=$(cat /etc/hostname | tr -d '[:space:]')

if ! grep -q "127.0.1.1" /etc/hosts 2>/dev/null; then
    echo "127.0.1.1 ${HOSTNAME}" >> /etc/hosts
fi

# ---------------------------------------------------------------------------
# Verify the mantle Wayland session entry exists
# ---------------------------------------------------------------------------
# The mantle package installs /usr/share/wayland-sessions/mantle.desktop.
# If it is absent the greeter will show an empty session list — fail loudly.
if [ ! -f /usr/share/wayland-sessions/mantle.desktop ]; then
    echo "ERROR: /usr/share/wayland-sessions/mantle.desktop is missing." >&2
    echo "The mantle package may not be installed correctly in the image." >&2
    exit 1
fi

echo "linus post-install configuration complete."
