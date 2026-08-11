# Libation Web UI (Docker)

The full [Libation](https://github.com/rmcrackan/Libation) desktop GUI in a container,
streamed to your browser over HTTP (TigerVNC + noVNC). Built for unraid, runs anywhere
Docker does.

- **Self-updating, cached.** Libation isn't baked in. First start downloads the official
  Linux release to `/cache`; every restart checks for a newer one, installs it and prunes
  the old. No network, no problem — it boots from cache.
- **Persistent.** Settings, accounts, database and master key live in `/config`, surviving
  restarts and image updates.
- **Batteries included.** GTK3, webkit2gtk (the in-app Audible login), ICU, fonts, X.

## Quick start

```bash
docker compose up -d
```

Open <http://localhost:8080>. To build from this checkout instead of pulling, add
`-f docker-compose.yml -f docker-compose.dev.yml`. Or without compose:

```bash
docker run -d --name libation -p 8080:8080 --shm-size=512m -e PUID=1000 -e PGID=1000 -v ./config:/config -v ./books:/books -v ./cache:/cache ghcr.io/tangent160/libation-webui:latest
```

**unraid:** drop [`unraid/libation-webui.xml`](unraid/libation-webui.xml) into
`/boot/config/plugins/dockerMan/templates-user/` and add the container from the Docker tab.
Defaults to `/mnt/user/appdata/libation`, `/mnt/user/media/audiobooks` and
`/mnt/user/appdata/libation-cache`.

## First run

Open the UI, then **Import → Add Account** and sign in to Audible in the embedded browser.
**Import → Scan Library**, then **Liberate**. The books folder is already set to `/books`.

Clipboard sharing (handy for login URLs) is in the noVNC control bar on the page's left edge.

Window sizes and positions are remembered in `/config`, so any layout you set persists.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `LIBATION_VERSION` | `latest` | Re-checks GitHub each start. Set e.g. `13.7.7` to pin. |
| `WEBUI_USER` / `WEBUI_PASS` | unset | Set **both** for HTTP basic auth. Unset = no login. |
| `PUID` / `PGID` | `99` / `100` | Ownership of everything Libation writes. |
| `UMASK` | `022` | File creation mask. |
| `TZ` | `Etc/UTC` | Container timezone. |
| `DISPLAY_WIDTH` / `DISPLAY_HEIGHT` | `1280` / `800` | *Initial* size; the desktop resizes to your browser on connect. |
| `WEB_PORT` | `8080` | Port nginx listens on inside the container. |

| Volume | Contents |
| --- | --- |
| `/config` | Settings, accounts, `LibationContext.db`, cover art, logs, `libation-master.key` |
| `/books` | Liberated audiobooks |
| `/cache` | Downloaded `.deb` and the extracted app |

## Command line

```bash
docker exec -u libation libation libation-cli scan
```

Also `liberate`, `search`, `export`, `list-accounts`, `get-setting`, `login-external` and
more — see `--help`.

## Versioning

Two versions move independently: the **image** ([`VERSION`](VERSION), semver) and
**Libation** (`LIBATION_VERSION`, resolved at runtime). Pinning one doesn't pin the other.

A release of `v1.2.3` publishes the tags `1.2.3`, `1.2` and `latest`. A prerelease tag
(`v1.3.0-rc1` — anything with a hyphen) publishes **only** its exact version and is marked
as a prerelease on GitHub, so `latest` and `1.3` keep pointing at the last stable build.
Opt in explicitly:

```bash
docker pull ghcr.io/tangent160/libation-webui:1.3.0-rc1
```

Check what's running with `docker exec libation cat /etc/libation-webui-release`.

**Cutting a release** — nothing publishes from `main`; only a `v*` tag does.

1. Write the changes under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md).
2. `./scripts/release.sh minor` (or `patch`/`major`/`1.2.3`/`1.3.0-rc1`) — bumps `VERSION`,
   dates the changelog, prints the git commands. It never commits, tags or pushes.
3. Run those commands. Pushing the tag triggers the release.

CI refuses to publish when the tag and `VERSION` disagree.

## Teardown

> **Save `libation-master.key` before deleting `/config`** — without it the stored Audible
> credentials can't be decrypted and you'll have to sign in again. Audiobooks in `/books`
> are plain files and are never affected.

| Goal | Command |
| --- | --- |
| Stop, keep everything | `docker compose down` |
| Force a clean Libation reinstall | `docker compose down && rm -rf ./data/cache` |
| Wipe settings, accounts and database | `docker compose down && rm -rf ./data/config ./data/cache` |
| Reclaim the image (~1.3GB on disk, ~330MB to re-pull) | `docker image rm ghcr.io/tangent160/libation-webui:latest` |

`docker compose down -v` will **not** delete your data — the compose file uses bind mounts
under `./data`, so removal is the `rm -rf` above. Started it with plain `docker run` instead?
`docker rm -f libation`.

**unraid:** Docker tab → Libation → *Remove*. Appdata is left behind, so delete
`/mnt/user/appdata/libation` and `/mnt/user/appdata/libation-cache` by hand when you're sure.

## Notes

- **Master key.** Libation encrypts Audible tokens with an OS-bound key that doesn't exist
  in a container, so on first run it writes a portable `/config/libation-master.key`. Treat
  it like a password. Migrating from a desktop install? Run `export-master-key` there and
  drop the key next to `AccountsSettings.json`.
- **Plain HTTP.** Anyone who can reach the port can drive the GUI unless you set
  `WEBUI_USER`/`WEBUI_PASS` — and even then credentials cross the network in the clear. Keep
  it on your LAN or behind a TLS reverse proxy.
- **`--shm-size=512m`** — webkit2gtk can crash on Docker's 64MB default.
- **amd64 only.** The image builds for arm64 too, but no arm64 image is published — build
  it yourself with `docker compose -f docker-compose.yml -f docker-compose.dev.yml build`.

## License

[MIT](LICENSE) for the packaging in this repo. Libation itself is GPL-3.0 and is
downloaded at runtime, not redistributed here.
