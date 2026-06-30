# LM Dream Aquarium 🐠

A turnkey **HD video aquarium screensaver for Linux Mint (MATE)**. It plays a
looping, hardware-decoded 1080p coral-reef video as a native MATE screensaver —
so it shows up in the normal Mint screensaver chooser as **"Aquarium HD"**, no
hacks or fiddling required after install.

![Aquarium HD screensaver running](assets/screenshot.png)

---

## Install

```bash
git clone https://github.com/VonHoltenCodes/LM_Dream_Aquarium.git
cd LM_Dream_Aquarium
./install.sh
```

Or one-liner (downloads everything, including the video):

```bash
curl -fsSL https://raw.githubusercontent.com/VonHoltenCodes/LM_Dream_Aquarium/main/install.sh | bash
```

Run it **as your normal user, not with `sudo`** — the script calls `sudo` itself
only for the few steps that touch system directories and install packages.

The installer will:

1. Install dependencies (`mpv`, `ffmpeg`, `curl`) via `apt` if missing.
2. Download the ~570 MB aquarium video and **verify its SHA-256** before installing it to `/opt/aquarium-screensaver/aquarium.mp4`.
3. Install the playback engine to `/usr/libexec/xscreensaver/aquarium-hack`.
4. Install the screensaver theme to `/usr/share/applications/screensavers/reef2.desktop`.
5. Select **"Aquarium HD"** as your active screensaver and restart the daemon.

When it finishes, preview it immediately:

```bash
mate-screensaver-command --preview
```

…or just leave the machine idle and it kicks in like any screensaver.

## Uninstall

```bash
./uninstall.sh
```

Removes the engine, theme, and video, and reverts your screensaver to the
blank-screen default. (`mpv`/`ffmpeg` are left in place — other apps use them.)

---

## How it works

MATE's screensaver runs an "engine" program and hands it a window id. Our engine
([`engine/aquarium-hack`](engine/aquarium-hack)) is a small Bash wrapper that
plays the video, muted and looping, into that window with `mpv` using GPU
hardware decode (`--hwdec=auto`):

```
mate-screensaver  →  aquarium-hack  →  mpv --wid=$XSCREENSAVER_WINDOW aquarium.mp4
```

The theme file ([`theme/reef2.desktop`](theme/reef2.desktop)) is what makes it
appear in the chooser; its id is `screensavers-reef2`.

### ⚠️ The gotcha that cost hours

> **The engine *must* live in `/usr/libexec/xscreensaver/`.** `mate-screensaver`
> silently rejects any theme whose `Exec` path points elsewhere (e.g.
> `/usr/local/bin`) — the screen just goes black with no error. Debug it with
> `mate-screensaver --no-daemon --debug` (look for `Setting command for job: 'NULL'`).
> Also: keep the theme `.desktop` basename **hyphen-free** — the id is
> `screensavers-<basename>`, and an extra hyphen breaks the reverse lookup.

The installer puts everything in the right place, so you don't have to worry
about any of this — it's documented here only for the curious / for hacking on it.

---

## Requirements

- **Linux Mint / MATE** (uses `mate-screensaver` + `org.mate.screensaver` gsettings).
- `mpv` and `ffmpeg` (installed automatically on apt-based systems).
- A GPU that can hardware-decode **1080p H.264** — virtually anything from the
  last decade, including old Intel integrated graphics (this was built on an
  Intel HD 4600). **Note:** the video is intentionally 1080p H.264, *not* 4K /
  VP9 / AV1, so it decodes smoothly on low-end hardware.

## Use your own video

Want a different scene? Any 1080p H.264 `.mp4` works:

```bash
# Point the installer at your own host:
AQUARIUM_VIDEO_URL="https://example.com/myreef.mp4" \
AQUARIUM_VIDEO_SHA256="$(sha256sum myreef.mp4 | cut -d' ' -f1)" \
./install.sh

# …or after install, just swap the file in place:
sudo cp myreef.mp4 /opt/aquarium-screensaver/aquarium.mp4
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| Screen goes **black**, no video | Display is blanking before the video shows. Run `xset s off; xset -dpms; xset s noblank`. |
| Not in the chooser | Re-run `./install.sh`; confirm `theme/reef2.desktop` landed in `/usr/share/applications/screensavers/`. |
| Choppy playback | Confirm hardware decode: `mpv --hwdec=auto /opt/aquarium-screensaver/aquarium.mp4`. The video must be 1080p H.264. |
| Want to test now | `mate-screensaver-command --activate` (move the mouse to dismiss). |

---

## License

Scripts and configuration in this repo are released into the public domain
(do whatever you like). The bundled aquarium video is distributed for personal
use; rights to the footage belong to its original creator.
