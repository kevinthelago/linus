#!/bin/sh
# Session wrapper for linus + Hyprland + mantle.
# Sets up the Wayland environment, then execs Hyprland.
# The Hyprland config includes /etc/hypr/mantle.conf which autostarts mantle.

export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=linus
export XDG_SESSION_TYPE=wayland

export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export GDK_BACKEND=wayland
export MOZ_ENABLE_WAYLAND=1
export SDL_VIDEODRIVER=wayland
export _JAVA_AWT_WM_NONREPARENTING=1
export GTK_USE_PORTAL=1

exec /usr/bin/Hyprland
