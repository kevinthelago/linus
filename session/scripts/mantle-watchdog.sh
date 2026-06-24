#!/bin/sh
# Start mantle. On failure, surface a swaynag warning so the screen is never blank.
# The sway compositor keeps running either way — the user is never locked out.

/usr/bin/mantle
EXIT=$?

[ $EXIT -eq 0 ] && exit 0

logger -p user.warning "linus: mantle exited with code $EXIT"

exec swaynag -t warning \
    -m "mantle shell exited (code $EXIT) — open a terminal and run 'mantle' to restart"
