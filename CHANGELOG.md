# Changelog

This file obeys [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The versions in this file are the versions of **this container image**. They are not the
versions of Libation. `LIBATION_VERSION` selects the Libation version at runtime, and that
version changes independently.

## [Unreleased]

### Added

- `THIRD-PARTY-NOTICES.md`. It lists the licenses of the Debian packages in the image, and
  the GPL-3.0 terms of Libation and of the unraid icon.
- `unraid/NOTICE.md`. The icon is a derivative of the Libation artwork, thus it stays
  GPL-3.0. This file marks the two icon files, because the PNG cannot hold a comment.

### Changed

- `LICENSE` is now `LICENSE.md`. The third-party text moved out of it, into
  `THIRD-PARTY-NOTICES.md`.

## [0.1.0] - 2026-08-10

The first release.

### Added

- The Libation desktop GUI in the browser. TigerVNC (`Xvnc`) and noVNC operate behind
  nginx. The browser changes the size of the desktop, thus the UI shows at native
  resolution.
- A runtime install of the official Libation release, with a cache in `/cache`. Each start
  installs a newer release and erases the old one. If the network is not available, the
  container uses the cache.
- A persistent `/config` directory. It holds the settings, the accounts, the database, the
  logs, and the portable master key.
- Optional HTTP basic auth (`WEBUI_USER` and `WEBUI_PASS`). The `/health` endpoint stays
  open.
- A `libation-cli` wrapper. The CLI uses the same configuration as the GUI.
- An unraid template, with an icon and a self-updating `TemplateURL`. Also two
  docker-compose files: one to pull the image, and one to build it locally. The published
  image is amd64.
- Tag-driven releases: `VERSION`, `scripts/release.sh`, and CI. CI publishes only on a `v*`
  tag, and it stops if the tag and `VERSION` disagree. A prerelease tag (`v1.0.0-rc1`)
  publishes its exact version and does not move `latest`. The image version is readable at
  `/etc/libation-webui-release`.

[Unreleased]: https://github.com/tangent160/libation-docker-ui/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/tangent160/libation-docker-ui/releases/tag/v0.1.0
