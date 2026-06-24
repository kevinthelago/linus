# /etc/skel/.bash_profile — linus live session launcher
# Starts sway on tty1 when not already in a Wayland session.

if [ -z "${WAYLAND_DISPLAY}" ] && [ "$(tty)" = "/dev/tty1" ]; then
    export XDG_SESSION_TYPE=wayland
    export XDG_CURRENT_DESKTOP=sway
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    exec dbus-run-session sway
fi
