# Changelog

Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Versions describe **this container image**, not Libation — that is chosen at runtime by
`LIBATION_VERSION` and updates independently.

## [Unreleased]

## [0.1.0] - 2026-08-10

First release.

### Added

- Libation desktop GUI in the browser: TigerVNC (`Xvnc`) + noVNC behind nginx, with
  browser-driven desktop resizing so the UI renders at native resolution.
- Runtime install of the official Libation release, cached in `/cache`. Each start upgrades
  to a newer release and prunes the old one, falling back to the cache when offline.
- Persistent `/config` — settings, accounts, database, logs and the portable master key.
- Optional HTTP basic auth (`WEBUI_USER` / `WEBUI_PASS`), with `/health` left open.
- `libation-cli` wrapper for the CLI against the same config.
- unraid template (with icon and self-updating `TemplateURL`), docker-compose files for
  pulling and for local builds. Published image is amd64.
- Tag-driven releases: `VERSION`, `scripts/release.sh`, and CI that publishes only on a
  `v*` tag and refuses when tag and `VERSION` disagree. Prerelease tags (`v1.0.0-rc1`)
  publish their exact version without moving `latest`. Image version readable at
  `/etc/libation-webui-release`.

[Unreleased]: https://github.com/tangent160/libation-docker-ui/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/tangent160/libation-docker-ui/releases/tag/v0.1.0
