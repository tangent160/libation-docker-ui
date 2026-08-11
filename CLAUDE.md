# CLAUDE.md

Docker image running the [Libation](https://github.com/rmcrackan/Libation) desktop GUI in a
browser. See [README.md](README.md) for user-facing docs.

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
VERSION, CHANGELOG.md   release state; LICENSE is MIT (packaging only)
docker-compose.yml      pulls the published image
docker-compose.dev.yml  override that builds from this checkout
```

**Boot order:** `entrypoint.sh` (user setup, seed `Settings.json`, auth, then
`libation-update.sh`) → supervisord → `Xvnc` → openbox → websockify → nginx → Libation.

## Upstream facts (verified, not guessed)

- Linux releases are **`.deb`/`.rpm` only** (amd64/arm64), no tarball. Extracted with
  `dpkg-deb -x`; never installed. Binaries land in `usr/lib/libation/`.
- `dpkg-deb` decompresses `data.tar.xz` **internally** — `xz-utils` is not needed.
- `LIBATION_FILES_DIR` overrides the config dir, but **the directory must already exist**
  or Libation silently falls back to `~/.local/share/Libation`.
- The CLI **never creates `Settings.json`** — only the GUI's first-run wizard does, so
  `entrypoint.sh` seeds it. Absent settings keys just use defaults.
- Token encryption is OS-bound. With no OS keystore, Libation writes a portable
  `/config/libation-master.key` itself. Don't reimplement this.
- `LibationCli` is fully scriptable and headless: `login-external --response-url` and
  `export-master-key` exist specifically for containers.

## Gotchas

- **Xvfb cannot resize.** It has no runtime mode-setting, which is why this uses TigerVNC's
  `Xvnc` (X server + VNC in one process) with `-AcceptSetDesktopSize` and noVNC
  `resize=remote`. Don't "simplify" back to Xvfb + x11vnc.
- **nginx `return` runs in the rewrite phase, before `auth_basic`.** Any redirect written as
  `return` bypasses auth — hence the static file at `/opt/webroot/index.html`.
- **`absolute_redirect off`** is required, or Location headers get rewritten to the internal
  port and break non-8080 host mappings.
- **Libation owns its window geometry.** It persists `MainWindow` and per-dialog entries
  (`{X, Y, Width, Height, IsMaximized}`) in `Settings.json` and reapplies them, overriding
  anything the WM forces. That is why the main window is maximized by seeding
  `MainWindow.IsMaximized` in `entrypoint.sh`, not with wmctrl/xdotool.
- **Never strip decorations, and never maximize by openbox rule.** Libation's child windows
  (Audible Accounts, Settings) are `_NET_WM_WINDOW_TYPE_NORMAL` with class `Libation`, the
  same as the main window — only `WM_TRANSIENT_FOR` differs, which openbox cannot match on.
  A class rule therefore hits the dialogs too, and some of them have no in-app close button,
  so removing the titlebar leaves the user trapped. Title matching does not work either:
  openbox applies rules at map time, before Avalonia sets the title.
- **websockify binds loopback only.** nginx is the sole entrance because that is where auth
  lives; an all-interfaces bind would be reachable under `--network host`.
- webkit2gtk (the Audible login view) needs `--shm-size=512m` and the
  `WEBKIT_DISABLE_*` env vars already set in the Dockerfile.
- Image is ~1.3GB. The bulk is llvm/mesa (137MB), webkit2gtk and its tail (185MB), and
  nodejs (45MB, pulled by Debian's `novnc` package). Perl (~47MB) comes from
  `tigervnc-standalone-server`, for a `vncserver` wrapper we do not use.

## Testing

There is no test suite; verify by building and booting.

```bash
docker build -t libation-webui:test .
docker run -d --name libtest -p 18080:8080 --shm-size=512m \
  -v tcfg:/config -v tbooks:/books -v tcache:/cache libation-webui:test
```

Then check, after ~60s:

```bash
docker logs libtest | grep -E '\[libation-update\]|\[entrypoint\]'
docker exec libtest bash -c 'DISPLAY=:1 xdotool search --onlyvisible --class Libation getwindowname %@'
docker exec libtest bash -c 'DISPLAY=:1 xdotool getdisplaygeometry'
docker exec -u libation libtest libation-cli version
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:18080/health
```

Worth re-running after any change: clean first run downloads and extracts; restart reuses
the cache without downloading; a faked-stale `/cache/current` upgrades and prunes; basic
auth returns 401 on `/` and `/vnc.html` but 200 on `/health`. Clean up volumes between runs
— a populated `/config` hides first-run bugs.

To debug the GUI itself, screenshot the X display and drive it from inside the container
(`x11-utils` and `imagemagick` are not in the image — install them in the test container):

```bash
docker exec libtest bash -c 'DISPLAY=:1 import -window root /tmp/s.png'
docker cp libtest:/tmp/s.png . && docker exec libtest bash -c 'DISPLAY=:1 xdotool mousemove X Y click 1'
docker exec libtest bash -c 'DISPLAY=:1 xprop -id <win> _NET_WM_WINDOW_TYPE WM_TRANSIENT_FOR _NET_WM_STATE'
```

Anything run with `docker run ... image <cmd>` needs `--entrypoint`, or `entrypoint.sh`
swallows the command and starts the whole stack.

## Releases

`VERSION` + git tag drive everything; only a `v*` tag publishes. Prepare with
`./scripts/release.sh <patch|minor|major|X.Y.Z>`, which edits files and prints the git
commands. CI runs on tags only — there are no builds on main or pull requests, so a tag is
the first time anything is compiled. Published image is **amd64 only**: the Dockerfile is
arch-agnostic and `libation-update.sh` handles arm64, but emulating this build under QEMU is
too slow for CI. A hyphenated version (`1.0.0-rc1`) is a prerelease: it publishes that exact image
tag but does not move `latest` or `major.minor`. **Never run git commit, tag or push** — the
user does that.

One-time, after the very first tag push: GHCR packages default to **private**, so the
package must be set public in GitHub → Packages → libation-webui → Package settings, or
every `docker pull` in the README and the unraid template fails to authenticate.
