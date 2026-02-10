# Dotfiles

Arch Linux dotfiles, managed with [chezmoi](https://www.chezmoi.io/).

## What's included

- **WM**: Hyprland + waybar + hyprpaper + hypridle/hyprlock
- **Terminal**: kitty + zsh
- **Editor**: neovim
- **Files**: lf + thunar
- **Audio**: mpd + ncmpcpp + mpv
- **Input**: fcitx5 + kkc (Japanese)
- **Theme**: Materia GTK + Kvantum + Papirus icons

## Application sandboxing

GUI and CLI applications are sandboxed via [bubblewrap](https://github.com/containers/bubblewrap) wrappers in `~/.local/bin/`. A shared library `~/.local/lib/bwrap-common.sh` provides reusable helpers for GPU, Wayland/X11, audio, D-Bus, and filesystem setup.

| Application | Display | Network | Notes |
|---|---|---|---|
| anki | Wayland | yes | QtWebEngine, Anki2 data dir |
| gimp | Wayland | no | Pictures/Downloads rw |
| goldendict | XWayland | yes | Dictionary dir from secrets |
| imv | Wayland | no | Read-only file viewer |
| krita | XWayland | yes | Separate config dir trick |
| mpv | Wayland | yes | subs2srs/mpvacious, Anki2 integration |
| nvim | — (terminal) | yes | CWD + file args, clipboard via Wayland |
| qbittorrent | Wayland | yes | Download dirs from secrets |

Per-host data directories (media paths, download dirs) are configured in `secrets.enc.yaml` under each application key, keyed by hostname.

### Library (`~/.local/lib/bwrap-common.sh`)

Provides functions used by all wrappers:

- `bwrap_gpu` — DRI + NVIDIA device nodes
- `bwrap_lib64` — `/usr/lib64` bind or symlink
- `bwrap_resolv` — resolv.conf symlink handling
- `bwrap_wayland` — Wayland socket (rw for `connect()`)
- `bwrap_x11` — X11/XWayland socket + Xauthority
- `bwrap_audio` — PipeWire + PulseAudio sockets
- `bwrap_dbus_session` / `bwrap_dbus_system` — D-Bus sockets
- `bwrap_themes` — fontconfig, Qt, GTK, Kvantum, fonts, icons
- `bwrap_resolve_files` — resolve file args to bind mounts
- `bwrap_base` — common system mounts (`/usr`, `/etc`, `/proc`, `/sys`, `/dev`)
- `bwrap_home_tmpfs` — tmpfs `$HOME` skeleton
- `bwrap_env_base` — `HOME`, `LANG`, `PATH`, `XDG_RUNTIME_DIR`
- `bwrap_sandbox` — `--unshare-all`, optional `--share-net`

## Secrets

Secrets are encrypted with [SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age).

Each machine has its own age key. Keys are stored separately from this repo.

### Structure

```yaml
# secrets.enc.yaml
goldendict:
    dict_dir: /path/to/dictionaries
mpv:
    hostname1:
        anime: /path/to/anime
    hostname2:
        videos: /path/to/videos
qbittorrent:
    hostname1:
        anime_dir: /path/to/torrents
```

### Setup on a new machine

1. Create age key:
```bash
mkdir -p ~/.config/chezmoi
age-keygen -o ~/.config/chezmoi/key.txt
```

2. Add public key to `.sops.yaml` and re-encrypt secrets:
```bash
# Edit .sops.yaml, add new recipient
sops updatekeys secrets.enc.yaml
```

## Install

```bash
chezmoi init --apply https://gitlab.com/fkzys/dotfiles.git
```

## Post-install

- Set Kvantum theme to `KvGnomeDark` in kvantummanager

## Credits

Some configs based on [tatsumoto-ren/dotfiles](https://github.com/tatsumoto-ren/dotfiles):
- `.local/bin/cabl`
- `.local/bin/dmenu`
- mpd, ncmpcpp, lf, fontconfig, mpv/input.conf
