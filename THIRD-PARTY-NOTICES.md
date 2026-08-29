# Third-party notices

The source in this repository is MIT. See [LICENSE.md](LICENSE.md). But the
container image that this repository builds holds software from other projects.
This file lists that software and its licenses.

Two different sets of components exist. The first set is in the image. The
second set is not in the image, because the container gets it at run time.

## In the image

The image starts from `debian:bookworm-slim` and installs packages with `apt`.
Debian gives the full license text of each package in the image, at
`/usr/share/doc/<package>/copyright`. To read one, operate this command:

```bash
docker run --rm --entrypoint cat ghcr.io/tangent160/libation-webui:latest /usr/share/doc/nginx/copyright
```

| Component | Package | License |
|---|---|---|
| Debian base system | `debian:bookworm-slim` | Many licenses, mostly GPL-2.0, GPL-3.0, LGPL, and BSD |
| TigerVNC | `tigervnc-standalone-server` | GPL-2.0 |
| noVNC | `novnc` | MPL-2.0 (and other licenses for the parts that it holds) |
| websockify | `websockify` | LGPL-3.0 |
| nginx | `nginx` | BSD-2-Clause |
| htpasswd | `apache2-utils` | Apache-2.0 |
| Openbox | `openbox` | GPL-2.0 |
| xdotool | `xdotool` | BSD-3-Clause |
| D-Bus | `dbus-x11` | AFL-2.1 or GPL-2.0 |
| Supervisor | `supervisor` | BSD-like (the Repoze license) |
| tini | `tini` | MIT |
| jq | `jq` | MIT |
| curl | `curl` | The curl license (MIT/X derivative) |
| CA certificates | `ca-certificates` | MPL-2.0 (the Mozilla CA bundle), GPL-2.0 (the scripts) |
| GTK 3 | `libgtk-3-0` | LGPL-2.1-or-later |
| WebKitGTK | `libwebkit2gtk-4.1-0` | LGPL-2.1-or-later, BSD-2-Clause |
| ICU | `libicu72` | The Unicode license (ICU) |
| OpenSSL | `libssl3` | Apache-2.0 |
| Fontconfig | `libfontconfig1` | The Fontconfig license (MIT-like) |
| X11 client libraries | `libx11-6`, `libsm6`, `libice6` | MIT (X11) |
| DejaVu fonts | `fonts-dejavu-core` | The Bitstream Vera license (permissive) |
| Liberation fonts | `fonts-liberation` | SIL Open Font License 1.1 |

### LGPL components

WebKitGTK, GTK 3, and websockify are under the LGPL. The image holds the
unmodified Debian binaries of these libraries, and it links to them
dynamically. This repository does not change their source. To get their
complete source, operate `apt-get source <package>` against the Debian
`bookworm` archive, or get it from Debian at <https://sources.debian.org/>.

## Not in the image

### Libation

[Libation](https://github.com/rmcrackan/Libation) is **GPL-3.0**.

The image does not hold Libation, and it does not redistribute Libation. At
each start, `libation-update.sh` downloads the official `.deb` release from the
GitHub releases of the project, and it extracts that release into `/cache`.

The source of Libation is at <https://github.com/rmcrackan/Libation>. The text
of the GPL-3.0 is at <https://www.gnu.org/licenses/gpl-3.0.html>.

### The unraid icon

The files `unraid/libation.svg` and `unraid/libation.png` come from the artwork
of Libation. Thus they stay under **GPL-3.0**. This repository does
redistribute these two files, because the unraid template reads the icon from
its raw URL at that path. See [unraid/NOTICE.md](unraid/NOTICE.md).

## Errors in this file

This file is a good-faith summary. It is not legal advice. If you find an
error, or a missing notice, open an issue at
<https://github.com/tangent160/libation-docker-ui/issues>.
