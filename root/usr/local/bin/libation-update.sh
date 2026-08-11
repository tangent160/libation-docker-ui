#!/usr/bin/env bash
# Resolve, download, cache and extract the Libation Linux release.
#
# On every boot this checks GitHub for the newest release. If it differs from
# what is cached, the new .deb is downloaded, extracted, and the previously
# cached version is removed. If GitHub is unreachable, the cached version is
# used as-is so the container still starts offline.
set -euo pipefail

REPO="rmcrackan/Libation"
CACHE_DIR="${LIBATION_CACHE_DIR:-/cache}"
DL_DIR="$CACHE_DIR/downloads"
APP_ROOT="$CACHE_DIR/app"
WANTED="${LIBATION_VERSION:-latest}"

log() { echo "[libation-update] $*"; }

case "$(dpkg --print-architecture)" in
    amd64) ARCH=amd64 ;;
    arm64) ARCH=arm64 ;;
    *) log "FATAL: unsupported architecture $(dpkg --print-architecture); Libation ships amd64 and arm64 only"; exit 1 ;;
esac

mkdir -p "$DL_DIR" "$APP_ROOT"

installed_version() {
    [[ -f "$CACHE_DIR/current" ]] && cat "$CACHE_DIR/current" || echo ""
}

app_dir_for() { echo "$APP_ROOT/$1/usr/lib/libation"; }

# --- resolve the target release ------------------------------------------------
api_url="https://api.github.com/repos/$REPO/releases/latest"
[[ "$WANTED" != "latest" ]] && api_url="https://api.github.com/repos/$REPO/releases/tags/${WANTED#v}"
[[ "$WANTED" != "latest" && "$WANTED" == v* ]] && api_url="https://api.github.com/repos/$REPO/releases/tags/$WANTED"

release_json=""
if release_json=$(curl -fsSL --max-time 30 -H 'Accept: application/vnd.github+json' "$api_url" 2>/dev/null); then
    :
elif [[ "$WANTED" != "latest" ]]; then
    # tag may or may not carry a leading "v"; try the other form once
    alt="${WANTED#v}"; [[ "$alt" == "$WANTED" ]] && alt="v$WANTED"
    release_json=$(curl -fsSL --max-time 30 -H 'Accept: application/vnd.github+json' \
        "https://api.github.com/repos/$REPO/releases/tags/$alt" 2>/dev/null || echo "")
fi

CURRENT="$(installed_version)"

if [[ -z "$release_json" ]]; then
    if [[ -n "$CURRENT" && -x "$(app_dir_for "$CURRENT")/Libation" ]]; then
        log "GitHub unreachable — continuing with cached version $CURRENT"
        echo "$(app_dir_for "$CURRENT")" > "$CACHE_DIR/.appdir"
        exit 0
    fi
    log "FATAL: cannot reach GitHub and no usable cached Libation in $CACHE_DIR"
    exit 1
fi

TARGET=$(jq -r '.tag_name // empty' <<<"$release_json" | sed 's/^v//')
ASSET_URL=$(jq -r --arg a "$ARCH" \
    '.assets[] | select(.name | test("linux-.*-" + $a + "\\.deb$")) | .browser_download_url' \
    <<<"$release_json" | head -n1)
ASSET_NAME="${ASSET_URL##*/}"

if [[ -z "$TARGET" || -z "$ASSET_URL" ]]; then
    if [[ -n "$CURRENT" && -x "$(app_dir_for "$CURRENT")/Libation" ]]; then
        log "No $ARCH .deb asset found in release — keeping cached version $CURRENT"
        echo "$(app_dir_for "$CURRENT")" > "$CACHE_DIR/.appdir"
        exit 0
    fi
    log "FATAL: no linux $ARCH .deb asset found for release '$TARGET'"
    exit 1
fi

log "cached=${CURRENT:-none} available=$TARGET arch=$ARCH"

# --- install if needed ---------------------------------------------------------
if [[ "$TARGET" == "$CURRENT" && -x "$(app_dir_for "$TARGET")/Libation" ]]; then
    log "already up to date ($TARGET)"
    echo "$(app_dir_for "$TARGET")" > "$CACHE_DIR/.appdir"
    exit 0
fi

deb_path="$DL_DIR/$ASSET_NAME"
if [[ ! -s "$deb_path" ]]; then
    log "downloading $ASSET_NAME"
    curl -fL --retry 3 --retry-delay 5 -o "$deb_path.part" "$ASSET_URL"
    mv "$deb_path.part" "$deb_path"
else
    log "reusing cached download $ASSET_NAME"
fi

if ! dpkg-deb -I "$deb_path" >/dev/null 2>&1; then
    log "cached download is corrupt — re-downloading"
    rm -f "$deb_path"
    curl -fL --retry 3 --retry-delay 5 -o "$deb_path" "$ASSET_URL"
    dpkg-deb -I "$deb_path" >/dev/null
fi

staging="$APP_ROOT/.staging-$TARGET"
rm -rf "$staging"
mkdir -p "$staging"
log "extracting to $APP_ROOT/$TARGET"
dpkg-deb -x "$deb_path" "$staging"

if [[ ! -x "$staging/usr/lib/libation/Libation" ]]; then
    log "FATAL: extracted package does not contain usr/lib/libation/Libation"
    rm -rf "$staging"
    exit 1
fi

rm -rf "${APP_ROOT:?}/$TARGET"
mv "$staging" "$APP_ROOT/$TARGET"
echo "$TARGET" > "$CACHE_DIR/current"
echo "$(app_dir_for "$TARGET")" > "$CACHE_DIR/.appdir"

# --- prune the previous version ------------------------------------------------
for d in "$APP_ROOT"/*; do
    [[ -d "$d" ]] || continue
    [[ "$(basename "$d")" == "$TARGET" ]] && continue
    log "removing old cached version $(basename "$d")"
    rm -rf "$d"
done
for f in "$DL_DIR"/*.deb; do
    [[ -f "$f" ]] || continue
    [[ "$(basename "$f")" == "$ASSET_NAME" ]] && continue
    log "removing old cached installer $(basename "$f")"
    rm -f "$f"
done

log "Libation $TARGET ready"
