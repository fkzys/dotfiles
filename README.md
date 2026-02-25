# Dotfiles

Arch Linux dotfiles, managed with [chezmoi](https://www.chezmoi.io/).

## What's included

- **WM**: Hyprland + waybar + hyprpaper + hypridle/hyprlock
- **Terminal**: kitty + zsh
- **Editor**: neovim
- **Files**: lf + thunar
- **Audio**: mpd + ncmpcpp + mpv
- **Bluetooth**: bt-audio (connect/disconnect paired BT audio devices via wofi, auto-switch PipeWire sink)
- **Input**: fcitx5 + kkc (Japanese)
- **Theme**: Materia GTK + Kvantum + Papirus icons
- **Browser**: Firefox (flatpak, arkenfox user.js with overrides)
- **Cloud sync**: Nextcloud (sandboxed, autostart via XDG desktop entry)
- **Scripts**: ffmpeg\_jp (Japanese audio extraction), rename\_subs (subtitle renaming by episode)

## Per-host configuration

Feature flags are set via `chezmoi init` prompts and stored in `~/.config/chezmoi/chezmoi.toml`:

| Variable | Description |
|---|---|
| `nvidia` | NVIDIA GPU (env vars, packages, waybar gpu\_temp) |
| `amd_cpu` | AMD CPU temp sensors (Tctl/Tccd1 vs generic) |
| `laptop` | Battery, backlight, natural scroll, disable touchpad while typing, compact fonts, bluetooth packages |
| `tablet` | OpenTabletDriver (otd-daemon) |
| `ocr` | transformers\_ocr (autostart + keybind) |
| `goldendict` | GoldenDict-ng (wrapper, config, package) |
| `subs2srs` | subs2srs (wrapper, package) |
| `sparrow` | sparrow-wallet (wrapper) |
| `portproton` | PortProton (flatpak + alias) |
| `virt_manager` | QEMU / virt-manager / dnsmasq |

Per-host data (monitor line, wallpaper path, podman graphroot, directory aliases) is stored in `secrets.enc.yaml` under the `host` and `dir_aliases` keys, keyed by hostname.

## Memory allocator hardening

[hardened\_malloc](https://github.com/GrapheneOS/hardened_malloc) is deployed system-wide via `/etc/ld.so.preload` (light variant) and per-app via bwrap `LD_PRELOAD` (default variant). Built from source in the [root-chezmoi](https://gitlab.com/fkzys/system-config) repository.

The light variant provides zero-on-free, slab canaries, and guard slabs. The default variant adds slot randomization, write-after-free checks, and slab quarantines.

GTK4 uses [glycin](https://gitlab.gnome.org/GNOME/glycin) for image loading, which sets `RLIMIT_AS` on its sandboxed loader processes. This is incompatible with hardened\_malloc's large virtual memory reservation (~240 GB `PROT_NONE` guard regions). A `libfake_rlimit.so` shim intercepts `prlimit64(RLIMIT_AS)` calls, returning success without applying the limit.

Applications with incompatible custom allocators (PartitionAlloc, mozjemalloc) have hardened\_malloc disabled inside their bwrap namespace via `--ro-bind /dev/null /etc/ld.so.preload`.

| Allocator | Applications |
|---|---|
| default (via bwrap) | imv, keepassxc, krita, mpv, obs, nvim, lazygit, qbittorrent, gimp, swappy, makepkg, fcitx5, nextcloud, otd-daemon, sparrow, transformers\_ocr, subs2srs |
| light (system-wide) | hyprland, waybar, kitty, wofi, thunar, all other native processes |
| disabled | anki, goldendict (PartitionAlloc) |
| not applicable | flatpak apps (own runtime) |

## Application sandboxing

GUI and CLI applications are sandboxed via [bubblewrap](https://github.com/containers/bubblewrap) wrappers in `~/.local/bin/`. A shared library `~/.local/lib/bwrap-common.sh` provides reusable helpers for GPU, Wayland/X11, audio, D-Bus, filesystem setup, and hardened\_malloc integration.

AUR builds via `yay` are also sandboxed — `makepkg` runs inside bwrap with `$HOME` as empty tmpfs, preventing PKGBUILD `build()` from accessing SSH keys, configs, or other sensitive data.

Flatpak applications have per-app permission overrides in `~/.local/share/flatpak/overrides/`.

Nextcloud and fcitx5 are launched via XDG autostart desktop entries (`~/.config/autostart/`) instead of systemd user services. The desktop entries use templated paths pointing to the bwrap wrappers.

| Application | Display | Network | Notes |
|---|---|---|---|
| anki | Wayland | yes | QtWebEngine, Anki2 data dir, audio sources dir from secrets |
| fcitx5 | Wayland | no | Input method daemon, socket dir shared via `/tmp/fcitx5-$UID`, D-Bus session access |
| gimp | Wayland | no | Pictures/Downloads rw |
| goldendict | XWayland | yes | Dictionary + audio dirs from secrets |
| imv | Wayland | no | Read-only file viewer |
| keepassxc | Wayland | no | DB dir from secrets, isolated from network |
| krita | XWayland | no | Separate config dir trick |
| lazygit | terminal | yes | CWD bind, SSH agent forwarding |
| mpv | Wayland | yes | subs2srs/mpvacious, Anki2 integration |
| nextcloud | Wayland | yes | Sync dir from secrets, D-Bus system access for status notifications, GNOME keyring forwarding |
| nvim | terminal | yes | CWD + file args, clipboard via Wayland |
| obs | Wayland | yes | Camera devices, Videos dir |
| otd-daemon | — | no | OpenTabletDriver daemon, full `/dev` access for tablet devices, network isolated |
| qbittorrent | Wayland | yes | Download dirs from secrets |
| sparrow | XWayland | yes | Bitcoin wallet, `/opt/sparrow` read-only bind, Java AWT non-reparenting |
| subs2srs | XWayland | no | Mono/.NET app, media dir read-only from secrets, output dir writable, fcitx5 input |
| swappy | Wayland | no | Screenshots dir |
| transformers\_ocr | Wayland | yes | OCR daemon with GPU access, Python venv bind, IPC commands run unsandboxed; PID namespace not isolated (breaks PID file) |
| yay (makepkg) | — | yes | `$HOME` is tmpfs, only build dir writable |

Per-host data directories (media paths, download dirs) are configured in `secrets.enc.yaml` under each application key, keyed by hostname.

### Library (`~/.local/lib/bwrap-common.sh`)

Provides functions used by all wrappers. Each function takes a variable name and appends bwrap arguments to it via nameref:

**Low-level helpers:**

| Function | Purpose |
|---|---|
| `bwrap_base` | System skeleton (`/usr`, `/etc`, `/proc`, `/sys`, `/dev`, `/tmp`) |
| `bwrap_lib64` | `/usr/lib64` bind or symlink |
| `bwrap_resolv` | resolv.conf symlink target for DNS |
| `bwrap_gpu` | DRI + NVIDIA device nodes |
| `bwrap_wayland` | Wayland socket (rw for `connect()`) |
| `bwrap_x11` | X11/XWayland socket + Xauthority |
| `bwrap_audio` | PipeWire + PulseAudio sockets |
| `bwrap_dbus_session` / `bwrap_dbus_system` | D-Bus sockets |
| `bwrap_themes` | GTK2/3, fontconfig, Qt, Kvantum, fonts, icons |
| `bwrap_fcitx` | fcitx5 input method sockets + env |
| `bwrap_home_tmpfs` | tmpfs `$HOME` with XDG skeleton |
| `bwrap_runtime_dir` | XDG\_RUNTIME\_DIR with correct permissions |
| `bwrap_env_base` | `HOME`, `LANG`, `PATH`, `XDG_RUNTIME_DIR` |
| `bwrap_sandbox` | `--unshare-all`, optional `--share-net` / `--new-session` |
| `bwrap_resolve_files` | Resolve file arguments to bind mounts |
| `bwrap_bind_dir` | Create state dirs on host + add `--bind` |
| `bwrap_ro_bind_dir` | Bind pre-existing dirs read-only, skip missing |
| `bwrap_ssh_agent` | SSH agent socket forwarding |
| `bwrap_hardened_malloc` | Upgrade to default variant via `LD_PRELOAD` |
| `bwrap_no_hardened_malloc` | Disable hardened\_malloc for incompatible apps |
| `require_dir` | Validate that directories exist, exit on missing |

**High-level composites:**

| Function | Purpose |
|---|---|
| `bwrap_gui_setup` | `bwrap_base` + `lib64` + `gpu` + optional `resolv` + `runtime_dir` + `home_tmpfs` |
| `bwrap_gui_finish` | `themes` + `wayland`/`x11` + `dbus_session` + `env_base` + malloc + `sandbox` |

### Wrapper pattern

Typical GUI wrapper using high-level composites:

```bash
A=()
bwrap_gui_setup A yes                    # yes = network (adds resolv)
bwrap_bind_dir A "${HOME}/.config/app" "${HOME}/Data"
bwrap_ro_bind_dir A "${MEDIA_DIR}"
bwrap_audio A
bwrap_gui_finish A wayland yes           # display, network, malloc=default
exec bwrap "${A[@]}" -- /usr/bin/app "$@"
```

Equivalent using low-level helpers:

```bash
A=()
bwrap_base A
bwrap_lib64 A
bwrap_gpu A
bwrap_resolv A
bwrap_runtime_dir A
bwrap_home_tmpfs A
bwrap_bind_dir A "${HOME}/.config/app" "${HOME}/Data"
bwrap_ro_bind_dir A "${MEDIA_DIR}"
bwrap_themes A
bwrap_wayland A
bwrap_audio A
bwrap_dbus_session A
bwrap_env_base A
bwrap_hardened_malloc A default
bwrap_sandbox A yes
exec bwrap "${A[@]}" -- /usr/bin/app "$@"
```

## lf file manager

### Previews

Video and image previews use kitty's `icat` protocol. Videos get cached thumbnails via `ffmpegthumbnailer`.

For videos with saved mpv playback position, the resume point and total duration are overlaid on the thumbnail (e.g. `⏸ 12:34 / 25:20`). The previewer reads mpv's `watch_later` state files (MD5 of the file path) and annotates via ImageMagick. Font is auto-detected from common system paths with `fc-match` as fallback.

The previewer runs inside a bwrap sandbox with read-only access to the video directory, lf config, vidthumb cache, and mpv watch\_later state. Only the vidthumb cache is writable.

### Status bar

An `on-select` hook displays the mpv resume position in the lf status bar when navigating to a video with saved state.

### Keybindings

| Key | Action |
|---|---|
| `m` | Play with mpv |
| `n` | Edit with nvim |
| `o` | Extract Japanese audio (ffmpeg\_jp) |
| `Ctrl-B` | Rename subtitles to match videos |

## Standalone scripts (`~/.local/bin/`)

| Script | Description |
|---|---|
| `ffmpeg_jp` | Extract Japanese audio track from video files as opus. Accepts a file, directory, or `$LF_SELECTED_FILES` from lf. Auto-detects Japanese track by language tag or title; falls back to the only track if there is exactly one. |
| `rename_subs` | Rename subtitle files (`.srt`, `.ass`) to match video filenames by episode number (`S01E01`). Supports `--dry-run`. |

Both are integrated into lf via keybindings (`o` for ffmpeg\_jp, `Ctrl-B` for rename\_subs).

## Firefox

Firefox runs as a flatpak with [arkenfox user.js](https://github.com/arkenfox/user.js). Overrides are managed via chezmoi at `~/.var/app/org.mozilla.firefox/.mozilla/firefox/<profile>/user-overrides.js`.

Custom overrides include:
- Hardware video acceleration (VA-API)
- Disabled menu access key
- JIT disabled (`ion`, `baselinejit`, `native_regexp`) for security hardening
- Session restore enabled

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
host:
    hostname1:
        monitor: "DP-1,1920x1080@144,0x0,1"
        wallpaper: "~/Downloads/background.jpg"
        podman_graphroot: "/path/to/storage"
    hostname2:
        wallpaper: "/usr/share/hypr/wall2.png"
dir_aliases:
    hostname1:
        subs: /path/to/subtitles
        anime: /path/to/anime
goldendict:
    dict_dir: /path/to/dictionaries
    audio_dir: /path/to/audio
anki:
    audio_sources_dir: /path/to/audio/sources
keepassxc:
    db_dir: /path/to/database
nextcloud:
    sync_dir: /path/to/sync
subs2srs:
    media_dir: /path/to/anime
mpv:
    hostname1:
        anime_dir: /path/to/anime
    hostname2:
        video_dir: /path/to/video
qbittorrent:
    hostname1:
        anime_dir: /path/to/torrents
mpd:
    hostname1:
        music_dir: /path/to/music
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

3. Add host data to secrets:
```bash
sops secrets.enc.yaml
# Add entries under host, dir_aliases, and app-specific keys
```

## Install

```bash
chezmoi init --apply https://gitlab.com/fkzys/dotfiles.git
```

During init, chezmoi will prompt for feature flags (nvidia, laptop, etc.).

## Post-install

- Set Kvantum theme to `KvGnomeDark` in kvantummanager

## Credits

Some configs based on [tatsumoto-ren/dotfiles](https://github.com/tatsumoto-ren/dotfiles):
- `.local/bin/cabl`
- `.local/bin/dmenu`
- mpd, ncmpcpp, lf, fontconfig, mpv/input.conf
