#!/usr/bin/env bash
# Block until the X server on :1 accepts connections, then exec the given command.
set -euo pipefail
for _ in $(seq 1 120); do
    [[ -S /tmp/.X11-unix/X1 ]] && exec "$@"
    sleep 0.5
done
echo "[wait-for-x] X server did not appear within 60s" >&2
exit 1
