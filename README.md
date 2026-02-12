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

## Memory allocator hardening

[hardened_malloc](https://github.com/GrapheneOS/hardened_malloc) is deployed system-wide via `/etc/ld.so.preload` (light variant) and per-app via bwrap `LD_PRELOAD` (default variant). Built from source in the [root-chezmoi](link) repository.

The light variant provides zero-on-free, slab canaries, and guard slabs. The default variant adds slot randomization, write-after-free checks, and slab quarantines.

Applications with incompatible custom allocators (PartitionAlloc, mozjemalloc, glycin) have hardened_malloc disabled inside their bwrap namespace via `--ro-bind /dev/null /etc/ld.so.preload`.

| Allocator | Applications |
|---|---|
| default (via bwrap) | imv, keepassxc, krita, mpv, obs, nvim, lazygit, qbittorrent, goldendict, makepkg |
| light (system-wide) | hyprland, waybar, kitty, wofi, all other native processes |
| disabled | anki (PartitionAlloc), gimp (glycin), swappy |
| not applicable | flatpak apps (own runtime) |

## Application sandboxing

GUI and CLI applications are sandboxed via [bubblewrap](https://github.com/containers/bubblewrap) wrappers in `~/.local/bin/`. A shared library `~/.local/lib/bwrap-common.sh` provides reusable helpers for GPU, Wayland/X11, audio, D-Bus, filesystem setup, and hardened_malloc integration.

AUR builds via `yay` are also sandboxed — `makepkg` runs inside bwrap with `$HOME` as empty tmpfs, preventing PKGBUILD `build()` from accessing SSH keys, configs, or other sensitive data.

Flatpak applications have per-app permission overrides in `~/.local/share/flatpak/overrides/`.

| Application | Display | Network | Notes |
|---|---|---|---|
| anki | Wayland | yes | QtWebEngine, Anki2 data dir |
| gimp | Wayland | no | Pictures/Downloads rw |
| goldendict | XWayland | yes | Dictionary dir from secrets |
| imv | Wayland | no | Read-only file viewer |
| keepassxc | Wayland | no | DB dir from secrets, isolated from network |
| krita | XWayland | yes | Separate config dir trick |
| lazygit | terminal | yes | CWD bind, SSH agent forwarding |
| mpv | Wayland | yes | subs2srs/mpvacious, Anki2 integration |
| nvim | terminal | yes | CWD + file args, clipboard via Wayland |
| obs | Wayland | yes | Camera devices, Videos dir |
| qbittorrent | Wayland | yes | Download dirs from secrets |
| swappy | Wayland | no | Screenshots dir |
| yay (makepkg) | — | yes | `$HOME` is tmpfs, only build dir writable |

Per-host data directories (media paths, download dirs) are configured in `secrets.enc.yaml` under each application key, keyed by hostname.

### Library (`~/.local/lib/bwrap-common.sh`)

Provides functions used by all wrappers. Each function appends bwrap arguments to a nameref array:

- `bwrap_base` — system skeleton (`/usr`, `/etc`, `/proc`, `/sys`, `/dev`, `/tmp`)
- `bwrap_lib64` — `/usr/lib64` bind or symlink
- `bwrap_resolv` — resolv.conf symlink target
- `bwrap_gpu` — DRI + NVIDIA device nodes
- `bwrap_wayland` — Wayland socket (rw for `connect()`)
- `bwrap_x11` — X11/XWayland socket + Xauthority
- `bwrap_audio` — PipeWire + PulseAudio sockets
- `bwrap_dbus_session` / `bwrap_dbus_system` — D-Bus sockets
- `bwrap_themes` — fontconfig, Qt, GTK, Kvantum, fonts, icons
- `bwrap_fcitx` — fcitx5 input method sockets + env
- `bwrap_home_tmpfs` — tmpfs `$HOME` with XDG skeleton
- `bwrap_env_base` — `HOME`, `LANG`, `PATH`, `XDG_RUNTIME_DIR`
- `bwrap_sandbox` — `--unshare-all`, optional `--share-net`, optional `--new-session`
- `bwrap_resolve_files` — resolve file arguments to bind mounts
- `bwrap_hardened_malloc` — upgrade to default variant via `LD_PRELOAD`
- `bwrap_no_hardened_malloc` — disable hardened_malloc for incompatible apps

### Wrapper pattern

```bash
A=()
bwrap_base A
bwrap_lib64 A
bwrap_gpu A
bwrap_home_tmpfs A
A+=(--bind "${HOME}/.config/app" "${HOME}/.config/app")
bwrap_wayland A
bwrap_env_base A
bwrap_hardened_malloc A default
bwrap_sandbox A yes
exec bwrap "${A[@]}" -- /usr/bin/app "$@"
```

## Secrets

Secrets are encrypted with [SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age).

Each machine has its own age key. Keys are stored separately from this repo.

### Structure

```yaml
# secrets.enc.yaml
sing-box:
    config_url:
        hostname1: https://example.com
        hostname2: https://example.com
goldendict:
    dict_dir: /path/to/dictionaries
keepassxc:
    db_dir: /path/to/database
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
