#!/bin/sh
# Hyprland variant of the mantle watchdog.
# On failure, opens a recovery terminal (swaynag is sway-only).

/usr/bin/mantle
EXIT=$?

[ $EXIT -eq 0 ] && exit 0

logger -p user.warning "linus: mantle exited with code $EXIT"

MSG="mantle shell exited (code $EXIT). Run 'mantle' to restart or 'hyprctl dispatch exit' to log out."

for TERM in foot alacritty kitty xterm; do
    if command -v "$TERM" >/dev/null 2>&1; then
        exec "$TERM" -- sh -c "printf '\n\n%s\n\n' '$MSG'; exec sh"
    fi
done

# No terminal found; notify-send as last resort (may not be visible without mantle)
notify-send -u critical "mantle" "$MSG" || true
