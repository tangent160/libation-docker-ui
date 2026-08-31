# Libation Web UI (Docker)

This image runs the full [Libation](https://github.com/rmcrackan/Libation) desktop GUI in a
container. It sends the GUI to your browser over HTTP with TigerVNC and noVNC. It is made
for unraid, but it operates anywhere that Docker operates.

- **Self-updating, with a cache.** Libation is not in the image. The first start downloads
  the official Linux release to `/cache`. Each restart looks for a newer release, installs
  it, and erases the old one. If the network is not available, the container boots from the
  cache.
- **Persistent.** The settings, the accounts, the database, and the master key are in
  `/config`. They stay after a restart and after an image update.
- **Usable on a phone.** The landing page picks the view from the size of your screen. A
  small screen gets a fit view and a pan view. See [Phones and tablets](#phones-and-tablets).
- **Complete.** The image contains GTK3, webkit2gtk (the Audible login view), ICU, fonts,
  and X.

## Quick start

```bash
docker compose up -d
```

Open <http://localhost:8080>. To build from this checkout instead of a pull, add
`-f docker-compose.yml -f docker-compose.dev.yml`. You can also start the container without
compose:

```bash
docker run -d --name libation -p 8080:8080 --shm-size=512m -e PUID=1000 -e PGID=1000 -v ./config:/config -v ./books:/books -v ./cache:/cache ghcr.io/tangent160/libation-webui:latest
```

**unraid:** Copy [`unraid/libation-webui.xml`](unraid/libation-webui.xml) into
`/boot/config/plugins/dockerMan/templates-user/`. Then add the container from the Docker
tab. The default paths are `/mnt/user/appdata/libation`, `/mnt/user/media/audiobooks`, and
`/mnt/user/appdata/libation-cache`.

## First run

1. Open the UI.
2. Click **Import → Add Account**. Then sign in to Audible in the embedded browser.
3. Click **Import → Scan Library**.
4. Click **Liberate**.

The books folder is already set to `/books`.

Note: The noVNC control bar on the left edge of the page contains the clipboard function.
The clipboard is useful for login URLs.

Note: Libation keeps the window sizes and window positions in `/config`. Thus your layout
stays after a restart.

## Phones and tablets

The landing page finds the size of your screen and picks the view for you. A screen with a
short side of less than 800 pixels is a small screen.

On a large screen the desktop changes size to fit the browser window. On a small screen
that is wrong, because the desktop then becomes smaller than the Libation window, and only
the top-left corner of that window stays visible. Thus a small screen gets two links
instead:

- **Fit the whole window on the screen.** The desktop keeps `DISPLAY_WIDTH` and
  `DISPLAY_HEIGHT`, and the image is scaled down. You see everything. The text is small.
- **Open at full size, and pan with a finger.** The image is not scaled. Tap the drag
  button in the noVNC control bar. Then drag the view with one finger.

Note: The noVNC control bar, on the left edge of the page, also holds a fullscreen button.
On Android this gives back the height of the address bar.

To make the text larger in the fit view, decrease the size of the desktop. For example, set
`DISPLAY_WIDTH=1024` and `DISPLAY_HEIGHT=768`. A phone in landscape orientation also fits a
1280x800 desktop much better than a phone in portrait orientation.

If the Libation window stays in a corner after this change, Libation saved a bad geometry
from an earlier connection. Stop the container. Then remove the `MainWindow` block from
`/config/Settings.json`. Then start the container again.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `LIBATION_VERSION` | `latest` | Looks at GitHub at each start. Set `13.7.7` to pin a version. |
| `WEBUI_USER` / `WEBUI_PASS` | unset | Set **both** for HTTP basic auth. If they are unset, there is no login. |
| `PUID` / `PGID` | `99` / `100` | The owner of all files that Libation writes. |
| `UMASK` | `022` | The file creation mask. |
| `TZ` | `Etc/UTC` | The timezone of the container. |
| `DISPLAY_WIDTH` / `DISPLAY_HEIGHT` | `1280` / `800` | The *initial* size. On a large screen the desktop then changes size to fit your browser. On a small screen it keeps this size, and the image is scaled. |
| `WEB_PORT` | `8080` | The port that nginx listens on in the container. |

| Volume | Contents |
| --- | --- |
| `/config` | Settings, accounts, `LibationContext.db`, cover art, logs, `libation-master.key` |
| `/books` | The liberated audiobooks |
| `/cache` | The downloaded `.deb` file and the extracted application |

## Command line

```bash
docker exec -u libation libation libation-cli scan
```

The CLI also accepts `liberate`, `search`, `export`, `list-accounts`, `get-setting`,
`login-external`, and more commands. For the full list, operate the CLI with `--help`.

## Versioning

There are two versions, and they move independently. The first is the version of the
**image** ([`VERSION`](VERSION), semver). The second is the version of **Libation**
(`LIBATION_VERSION`), which the container resolves at runtime. A pin on one version is not
a pin on the other version.

A release of `v1.2.3` publishes the tags `1.2.3`, `1.2`, and `latest`. A prerelease tag is
a tag with a hyphen, for example `v1.3.0-rc1`. A prerelease publishes **only** its exact
version, and GitHub marks it as a prerelease. Thus `latest` and `1.3` continue to point to
the last stable build. To get a prerelease, ask for it directly:

```bash
docker pull ghcr.io/tangent160/libation-webui:1.3.0-rc1
```

To see the version that operates now, use `docker exec libation cat /etc/libation-webui-release`.

**To make a release** — a push to `main` publishes nothing. Only a `v*` tag publishes.

1. Write the changes below `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md).
2. Operate `./scripts/release.sh minor`. The other permitted arguments are `patch`, `major`,
   `1.2.3`, and `1.3.0-rc1`. The script increases `VERSION`, puts the date in the changelog,
   and shows the git commands. The script does not commit, tag, or push.
3. Operate those git commands. The push of the tag starts the release.

If the tag and `VERSION` disagree, CI does not publish.

## Teardown

> **Copy `libation-master.key` to a safe place before you erase `/config`.** Without this
> key, Libation cannot decrypt the stored Audible credentials, and you must sign in again.
> The audiobooks in `/books` are plain files, and this does not change them.

| Goal | Command |
| --- | --- |
| Stop, but keep all data | `docker compose down` |
| Force a clean install of Libation | `docker compose down && rm -rf ./data/cache` |
| Erase the settings, the accounts, and the database | `docker compose down && rm -rf ./data/config ./data/cache` |
| Get the image space back (~1.3GB on disk, ~330MB for a new pull) | `docker image rm ghcr.io/tangent160/libation-webui:latest` |

The command `docker compose down -v` does **not** erase your data. The compose file uses
bind mounts below `./data`, thus you must use the `rm -rf` command in the table. If you
started the container with a plain `docker run` command, operate `docker rm -f libation`.

**unraid:** Go to the Docker tab. Then click Libation → *Remove*. This keeps the appdata
directories. When you are sure, erase `/mnt/user/appdata/libation` and
`/mnt/user/appdata/libation-cache` manually.

## Notes

- **The master key.** Libation encrypts the Audible tokens with a key that is bound to the
  OS. This key does not exist in a container. Thus, at the first start, Libation writes a
  portable key to `/config/libation-master.key`. Keep this key as safe as a password. To
  move from a desktop install, operate `export-master-key` there. Then put the key next to
  `AccountsSettings.json`.
- **Plain HTTP.** If you do not set `WEBUI_USER` and `WEBUI_PASS`, all persons who can
  connect to the port can operate the GUI. Also, the credentials cross the network without
  encryption. Thus keep the container on your LAN, or put a TLS reverse proxy in front of it.
- **`--shm-size=512m`** — webkit2gtk can stop with an error at the 64MB default of Docker.
- **amd64 only.** The image also builds for arm64, but no arm64 image is published. To get
  one, build it with `docker compose -f docker-compose.yml -f docker-compose.dev.yml build`.

## License

The packaging in this repository is [MIT](LICENSE.md). Libation is GPL-3.0. The container
downloads Libation at runtime, and this repository does not redistribute it.

The image also holds software from Debian, under other licenses. See
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
