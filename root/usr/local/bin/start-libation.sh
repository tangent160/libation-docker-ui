#!/usr/bin/env bash
# Launch the Libation GUI on the internal X display. Supervisor restarts it if
# the user closes the window, so the browser view is never left empty.
set -euo pipefail

APP_DIR=$(cat /run/libation/appdir)
export DISPLAY=:1
export LIBATION_FILES_DIR="${LIBATION_FILES_DIR:-/config}"
export HOME="${HOME:-$LIBATION_FILES_DIR/.home}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-libation}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

# webkit2gtk (the Audible login view) cannot use its sandbox or GPU compositing
# inside a container.
export WEBKIT_DISABLE_COMPOSITING_MODE=1
export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1
export LIBGL_ALWAYS_SOFTWARE=1

/usr/local/bin/wait-for-x.sh true

# The main window is maximized via "MainWindow": {"IsMaximized": true} in
# Settings.json, seeded by entrypoint.sh. Libation persists and reapplies its own
# window geometry, so anything the window manager forces here gets overridden the
# moment the app saves its layout.
cd "$APP_DIR"
exec ./Libation
