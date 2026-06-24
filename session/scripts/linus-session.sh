#!/bin/sh
# Session wrapper for linus + sway + mantle.
# Sets up the Wayland environment, then execs sway.
# sway loads /etc/sway/config.d/90-mantle.conf which autostarts mantle.

export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_DESKTOP=linus
export XDG_SESSION_TYPE=wayland

# Qt/GTK Wayland backends
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export GDK_BACKEND=wayland
export MOZ_ENABLE_WAYLAND=1
export SDL_VIDEODRIVER=wayland
export CLUTTER_BACKEND=wayland
export _JAVA_AWT_WM_NONREPARENTING=1

# Prefer Wayland portals for file/url dialogs
export GTK_USE_PORTAL=1

exec /usr/bin/sway
