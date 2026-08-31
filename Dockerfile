FROM debian:bookworm-slim

# Supplied by CI from the git tag; "0.0.0-dev" when built by hand.
ARG VERSION=0.0.0-dev
ARG REVISION=unknown
ARG BUILD_DATE=""

LABEL org.opencontainers.image.title="Libation Web UI" \
      org.opencontainers.image.description="Libation (rmcrackan/Libation) GUI in a browser, with cached self-updating installs and persistent config" \
      org.opencontainers.image.source="https://github.com/tangent160/libation-docker-ui" \
      org.opencontainers.image.url="https://github.com/rmcrackan/Libation" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.created="${BUILD_DATE}"

ENV DEBIAN_FRONTEND=noninteractive

# X server + noVNC + nginx, plus Libation's own runtime dependencies.
# Xvnc (TigerVNC) is both the X server and the VNC server: unlike Xvfb it
# implements RandR mode setting, so in a large browser window noVNC can resize
# the real desktop to that window instead of upscaling a fixed framebuffer. A
# small window keeps the fixed desktop and scales it; see /opt/webroot/index.html.
# libgtk-3-0 / libwebkit2gtk-4.1-0 come from the .deb's Recommends field and are
# what the in-app Audible login WebView needs.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl jq tini supervisor \
        tigervnc-standalone-server openbox xdotool dbus-x11 \
        novnc websockify nginx apache2-utils \
        libgtk-3-0 libwebkit2gtk-4.1-0 \
        libicu72 libssl3 libfontconfig1 libx11-6 libsm6 libice6 \
        fonts-dejavu-core fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

COPY root/ /

# Readable at runtime: `docker exec <container> cat /etc/libation-webui-release`
RUN printf 'IMAGE_VERSION=%s\nIMAGE_REVISION=%s\nIMAGE_BUILD_DATE=%s\n' \
        "$VERSION" "$REVISION" "$BUILD_DATE" > /etc/libation-webui-release \
    && chmod +x /usr/local/bin/* \
    && rm -f /etc/nginx/sites-enabled/default \
    && ln -sf /usr/share/novnc /opt/novnc

# Libation config/state (Settings.json, AccountsSettings.json, LibationContext.db, logs)
ENV LIBATION_FILES_DIR=/config \
    LIBATION_BOOKS_DIR=/books \
    LIBATION_CACHE_DIR=/cache \
    LIBATION_VERSION=latest \
    HOME=/config/.home \
    DISPLAY=:1 \
    DISPLAY_WIDTH=1280 \
    DISPLAY_HEIGHT=800 \
    DISPLAY_DEPTH=24 \
    WEB_PORT=8080 \
    PUID=99 \
    PGID=100 \
    UMASK=022 \
    TZ=Etc/UTC \
    WEBKIT_DISABLE_COMPOSITING_MODE=1 \
    WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1

VOLUME ["/config", "/books", "/cache"]
EXPOSE 8080

# start-period is generous: the very first boot downloads ~61MB of Libation
# before nginx is up, and that can be slow on a thin connection.
HEALTHCHECK --interval=30s --timeout=5s --start-period=300s \
    CMD curl -fsS "http://localhost:${WEB_PORT}/health" || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
