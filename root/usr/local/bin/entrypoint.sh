#!/usr/bin/env bash
set -euo pipefail

log() { echo "[entrypoint] $*"; }

if [[ -r /etc/libation-webui-release ]]; then
    # shellcheck disable=SC1091
    . /etc/libation-webui-release
    log "libation-webui ${IMAGE_VERSION:-unknown} (${IMAGE_REVISION:-unknown})"
fi

: "${PUID:=99}" "${PGID:=100}" "${UMASK:=022}"
: "${LIBATION_FILES_DIR:=/config}" "${LIBATION_BOOKS_DIR:=/books}" "${LIBATION_CACHE_DIR:=/cache}"
: "${DISPLAY_WIDTH:=1280}" "${DISPLAY_HEIGHT:=800}" "${DISPLAY_DEPTH:=24}" "${WEB_PORT:=8080}"

umask "$UMASK"

if [[ -n "${TZ:-}" && -f "/usr/share/zoneinfo/$TZ" ]]; then
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
fi

# --- user ----------------------------------------------------------------------
# Recreated on every boot so PUID/PGID changes take effect on unraid.
if ! getent group "$PGID" >/dev/null; then
    groupadd -g "$PGID" libation
fi
GROUP_NAME=$(getent group "$PGID" | cut -d: -f1)

if getent passwd libation >/dev/null; then
    usermod -u "$PUID" -g "$PGID" -d "$LIBATION_FILES_DIR/.home" libation
elif getent passwd "$PUID" >/dev/null; then
    EXISTING=$(getent passwd "$PUID" | cut -d: -f1)
    usermod -l libation -g "$PGID" -d "$LIBATION_FILES_DIR/.home" "$EXISTING"
else
    useradd -u "$PUID" -g "$PGID" -M -d "$LIBATION_FILES_DIR/.home" -s /bin/bash libation
fi
log "running as libation ($PUID:$PGID, group $GROUP_NAME)"

export HOME="$LIBATION_FILES_DIR/.home"

mkdir -p "$LIBATION_FILES_DIR" "$LIBATION_BOOKS_DIR" "$LIBATION_CACHE_DIR" \
         "$HOME" "$HOME/.config" "$LIBATION_FILES_DIR/tmp" /run/libation /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

# --- seed a default Settings.json so the GUI skips the first-run wizard ---------
SETTINGS="$LIBATION_FILES_DIR/Settings.json"
if [[ ! -f "$SETTINGS" ]]; then
    log "seeding $SETTINGS"
    # Libation stores its own window geometry per window and reapplies it, so
    # the main window is maximized here rather than by the window manager.
    cat > "$SETTINGS" <<EOF
{
  "Books": "$LIBATION_BOOKS_DIR",
  "InProgress": "$LIBATION_FILES_DIR/tmp",
  "FirstLaunch": false,
  "BetaOptIn": false,
  "LogLevel": "Information",
  "MainWindow": {
    "X": 0,
    "Y": 0,
    "Width": $DISPLAY_WIDTH,
    "Height": $DISPLAY_HEIGHT,
    "IsMaximized": true
  }
}
EOF
fi

# --- fetch / update / cache Libation -------------------------------------------
/usr/local/bin/libation-update.sh
APP_DIR=$(cat "$LIBATION_CACHE_DIR/.appdir")
log "using Libation at $APP_DIR"
echo "$APP_DIR" > /run/libation/appdir

# --- optional basic auth --------------------------------------------------------
AUTH_CONF=/etc/nginx/conf.d/auth.inc
if [[ -n "${WEBUI_USER:-}" && -n "${WEBUI_PASS:-}" ]]; then
    htpasswd -bc /etc/nginx/.htpasswd "$WEBUI_USER" "$WEBUI_PASS" >/dev/null 2>&1
    chmod 640 /etc/nginx/.htpasswd
    chown root:www-data /etc/nginx/.htpasswd
    cat > "$AUTH_CONF" <<'EOF'
auth_basic "Libation";
auth_basic_user_file /etc/nginx/.htpasswd;
EOF
    log "basic auth enabled for user ${WEBUI_USER}"
else
    : > "$AUTH_CONF"
    log "basic auth disabled (set WEBUI_USER and WEBUI_PASS to enable)"
fi
sed -i "s/listen .* default_server;/listen ${WEB_PORT} default_server;/" /etc/nginx/conf.d/libation.conf

# --- ownership ------------------------------------------------------------------
# Only the container-managed dirs; skipping /books avoids a long chown on big libraries.
chown -R "$PUID:$PGID" "$LIBATION_FILES_DIR" "$LIBATION_CACHE_DIR" /run/libation 2>/dev/null || true
chown "$PUID:$PGID" "$LIBATION_BOOKS_DIR" 2>/dev/null || true

export LIBATION_FILES_DIR APP_DIR
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
