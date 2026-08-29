# CLAUDE.md

This repository builds a Docker image. The image runs the
[Libation](https://github.com/rmcrackan/Libation) desktop GUI in a browser. The
user-facing documentation is in [README.md](README.md).

## Layout

```
Dockerfile              debian:bookworm-slim + X/VNC/nginx + Libation's runtime deps
root/                   overlay copied to / in the image
  usr/local/bin/        entrypoint.sh, libation-update.sh, start-libation.sh,
                        wait-for-x.sh, libation-cli
  etc/supervisor/       process supervision
  etc/nginx/conf.d/     web serving + optional basic auth
  etc/xdg/openbox/      window rules
  opt/webroot/          landing page that redirects to noVNC
scripts/release.sh      version bump helper
unraid/                 Community Applications template + icon (libation.svg -> .png)
                        The icon is GPL-3.0; see unraid/NOTICE.md
VERSION, CHANGELOG.md   release state
LICENSE.md              MIT, packaging only; Libation stays GPL-3.0
THIRD-PARTY-NOTICES.md  licenses of the Debian packages and of Libation
docker-compose.yml      pulls the published image
docker-compose.dev.yml  override that builds from this checkout
```

**Boot order:** `entrypoint.sh` (user setup, seed `Settings.json`, auth, then
`libation-update.sh`) → supervisord → `Xvnc` → openbox → websockify → nginx → Libation.

## Upstream facts (examined, not guessed)

- The Linux releases are **`.deb` and `.rpm` files only** (amd64 and arm64). There is no
  tarball. `dpkg-deb -x` extracts the file. The image never installs it. The binaries go
  to `usr/lib/libation/`.
- `dpkg-deb` decompresses `data.tar.xz` **internally**. Thus `xz-utils` is not necessary.
- `LIBATION_FILES_DIR` overrides the configuration directory. But **the directory must
  exist first**, or Libation silently uses `~/.local/share/Libation`.
- The CLI **never makes `Settings.json`**. Only the first-run wizard of the GUI makes it.
  Thus `entrypoint.sh` writes the initial file. Absent keys in the settings use their
  defaults.
- Token encryption is bound to the OS. If there is no OS keystore, Libation writes a
  portable `/config/libation-master.key` itself. Do not write this function again.
- `LibationCli` is fully scriptable and headless. The commands `login-external
  --response-url` and `export-master-key` exist specifically for containers.

## Gotchas

- **Xvfb cannot change size.** It has no runtime mode-setting. Thus this image uses `Xvnc`
  from TigerVNC, which is an X server and a VNC server in one process. It operates with
  `-AcceptSetDesktopSize`, and noVNC operates with `resize=remote`. Do not "simplify" this
  back to Xvfb and x11vnc.
- **The nginx `return` directive operates in the rewrite phase, before `auth_basic`.** Thus
  a redirect written as `return` goes around the auth. For this reason there is a static
  file at `/opt/webroot/index.html`.
- **`absolute_redirect off` is necessary.** Without it, nginx writes the internal port into
  the Location headers, and host mappings other than 8080 stop.
- **Libation owns its window geometry.** It keeps `MainWindow` and one entry per dialog
  (`{X, Y, Width, Height, IsMaximized}`) in `Settings.json`, and it applies them again. This
  overrides all values that the WM forces. For this reason `entrypoint.sh` maximizes the
  main window with the `MainWindow.IsMaximized` value, and not with wmctrl or xdotool.
- **Never remove the decorations, and never maximize with an openbox rule.** The child
  windows of Libation (Audible Accounts, Settings) are `_NET_WM_WINDOW_TYPE_NORMAL` with
  the class `Libation`. The main window is the same. Only `WM_TRANSIENT_FOR` is different,
  and openbox cannot match on it. Thus a rule on the class also hits the dialogs. Some
  dialogs have no close button in the application, thus a dialog without a titlebar traps
  the user. A match on the title also does not work: openbox applies the rules at map time,
  before Avalonia sets the title.
- **websockify binds to loopback only.** nginx is the only entrance, because nginx holds
  the auth. A bind to all interfaces is reachable with `--network host`.
- **A new `apt` package needs a new row in `THIRD-PARTY-NOTICES.md`.** If you add a package
  to the Dockerfile, add its license to that table.
- webkit2gtk (the Audible login view) needs `--shm-size=512m` and the `WEBKIT_DISABLE_*`
  environment variables. The Dockerfile already sets these variables.
- The image is approximately 1.3GB. The largest parts are llvm and mesa (137MB), webkit2gtk
  and its dependencies (185MB), and nodejs (45MB, which the Debian `novnc` package pulls
  in). Perl (approximately 47MB) comes from `tigervnc-standalone-server`, for a `vncserver`
  wrapper that this image does not use.

## Testing

There is no test suite. To do a test, build the image and boot it.

```bash
docker build -t libation-webui:test .
docker run -d --name libtest -p 18080:8080 --shm-size=512m \
  -v tcfg:/config -v tbooks:/books -v tcache:/cache libation-webui:test
```

Then wait approximately 60 seconds and operate these commands:

```bash
docker logs libtest | grep -E '\[libation-update\]|\[entrypoint\]'
docker exec libtest bash -c 'DISPLAY=:1 xdotool search --onlyvisible --class Libation getwindowname %@'
docker exec libtest bash -c 'DISPLAY=:1 xdotool getdisplaygeometry'
docker exec -u libation libtest libation-cli version
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:18080/health
```

Do these tests again after each change. Make sure that:

- A clean first run downloads and extracts the release.
- A restart uses the cache and downloads nothing.
- A faked stale `/cache/current` upgrades the release and erases the old one.
- Basic auth gives 401 on `/` and on `/vnc.html`, but 200 on `/health`.

Erase the volumes between the runs. A `/config` volume with data in it hides the first-run
errors.

To debug the GUI itself, make a screenshot of the X display and drive the GUI from in the
container. The packages `x11-utils` and `imagemagick` are not in the image, thus install
them in the test container.

```bash
docker exec libtest bash -c 'DISPLAY=:1 import -window root /tmp/s.png'
docker cp libtest:/tmp/s.png . && docker exec libtest bash -c 'DISPLAY=:1 xdotool mousemove X Y click 1'
docker exec libtest bash -c 'DISPLAY=:1 xprop -id <win> _NET_WM_WINDOW_TYPE WM_TRANSIENT_FOR _NET_WM_STATE'
```

A command in the form `docker run ... image <cmd>` needs `--entrypoint`. Without it,
`entrypoint.sh` ignores the command and starts the full stack.

## Releases

`VERSION` and the git tag control everything. Only a `v*` tag publishes. To prepare a
release, operate `./scripts/release.sh <patch|minor|major|X.Y.Z>`. The script edits the
files and shows the git commands. CI operates on tags only. There are no builds on main and
no builds on pull requests, thus a tag is the first time that anything compiles. The
published image is **amd64 only**. The Dockerfile is arch-agnostic, and
`libation-update.sh` can do arm64, but this build under QEMU emulation is too slow for CI.
A version with a hyphen (`1.0.0-rc1`) is a prerelease. It publishes that exact image tag,
but it does not move `latest` or `major.minor`. **Never operate git commit, git tag, or git
push.** The user does that.

One time only, after the push of the very first tag: GHCR packages are **private** by
default. Thus you must make the package public in GitHub → Packages → libation-webui →
Package settings. If you do not, each `docker pull` in the README and in the unraid
template fails with an authentication error.
