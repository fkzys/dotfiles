# Dotfiles

## Per-host configuration

Feature flags are set via `dotm init` prompts and stored in `~/.local/state/dotm/<hash>.toml`:

| Variable | Description |
|---|---|
| `nvidia` | NVIDIA GPU (env vars, packages, waybar gpu\_temp) |
| `amd_cpu` | AMD CPU temp sensors (Tctl/Tccd1 vs generic) |
| `laptop` | Battery, backlight, natural scroll, disable touchpad while typing, compact fonts, bluetooth packages |
| `tablet` | OpenTabletDriver (otd-daemon, systemd user service) |
| `ocr` | transformers\_ocr (systemd user service + keybind) |
| `goldendict` | GoldenDict-ng (wrapper, config, package) |
| `subs2srs` | [subs2srs](https://github.com/ajatt-tools/subs2srs) + SubsReTimer (wrappers, desktop entries, packages) |
| `sparrow` | sparrow-wallet (wrapper) |
| `portproton` | PortProton (flatpak + alias) |
| `virt_manager` | QEMU / virt-manager / dnsmasq |

Per-host data (monitor line, wallpaper path, container graphroot, directory aliases) is stored in `secrets.enc.yaml` under each application's key, keyed by hostname.

## Shell

### Completion

Interactive menu with arrow navigation, case-insensitive matching, `LS_COLORS`, grouped by type.

### Aliases

| Alias | Expands to |
|---|---|
| `ls`, `ll`, `la`, `lt`, `l.` | `eza` variants (color, dirs first, git status, tree) |
| `cat` | `bat --paging=never` |
| `ccat` | `bat --paging=never --style=full --color=never` |
| `catp` | `bat` with pager |
| `rg` | `ripgrep --smart-case` |
| `vi`, `vim` | `nvim` |
| `lg` | `lazygit` |
| `start-hyprland` | `exec uwsm start start-hyprland` |
| `ssops` | `sudo SOPS_AGE_KEY="$(cat ~/keys/age/dotm.txt)"` |
| `g`, `ga`, `gc`, `gco`, `gd`, `gl`, `gp`, `gst`, `glog` | git shorthands |
| Flatpak apps | `firefox`, `telegram`, etc. → `flatpak run <id>` (generated from a map, conditional on feature flags) |
| Directory aliases | Per-host `cd` shortcuts from `secrets.enc.yaml` (e.g. `anime`, `subs`) |

### Functions

| Function | Description |
|---|---|
| `bcat` | `bat` with decorations → `wl-copy` (copy file with line numbers to clipboard) |

### Keybindings

| Key | Action |
|---|---|
| `Ctrl-O` | Launch `lf` |
| `Ctrl-F` | `fzf-cd-widget` (fuzzy cd) |
| `Ctrl-N` | Launch `ncmpcpp` |
| `Ctrl-T` | fzf file search |
| `Alt-C` | fzf directory search |
| `Up` / `Down` | History search by prefix |
| `Ctrl-Left` / `Ctrl-Right` | Word navigation |
| `Ctrl-Backspace` / `Ctrl-Delete` | Kill word backward/forward |

### Environment

| Variable | Value |
|---|---|
| `EDITOR` | `nvim` |
| `MANPAGER` | `bat` as man pager (with `col -bx`) |
| `MAKEFLAGS` etc. | Parallel builds (`-j$(nproc)`) for make, cmake, ninja, meson, dpkg |
| `SOPS_AGE_KEY_FILE` | Age key path for sops decryption |

## Systemd user services

| Service | Type | Description |
|---|---|---|
| `ssh-agent` | — | SSH agent daemon (`SSH_AUTH_SOCK` at `$XDG_RUNTIME_DIR/ssh-agent.socket`) |
| `keys-vault` | oneshot, `RemainAfterExit` | Mounts [keys-vault](https://github.com/fkzys/keys-vault) gocryptfs vault (`~/keys`) on login, unmounts on stop. After `gnome-keyring-daemon`. |
| `ssh-add` | oneshot, `RemainAfterExit` | Loads all SSH keys from `~/keys/ssh/` into agent (4 h lifetime). Requires `ssh-agent` + `keys-vault`. |
| `hypridle` | — | Idle daemon |
| `hyprpaper` | — | Wallpaper daemon |
| `hyprpolkitagent` | — | Polkit agent |
| `hyprsunset` | — | Night light. Override filters `[TRACE]` log spam via `grep -v` and uses `KillMode=control-group` for clean shutdown. |
| `waybar` | — | Status bar |
| `opentabletdriver` | — | OpenTabletDriver daemon (conditional on `tablet` flag). `PartOf=graphical-session.target`, auto-restart on failure (`RestartSec=3`). Launched via systemd instead of hyprland `exec-once`. |
| `mpd` | — | Music player daemon |
| `fcitx5` | — | Input method daemon |
| `nextcloud` | — | Nextcloud desktop client |
| `transformers_ocr` | — | OCR daemon (conditional on `ocr` flag). Drop-in override replaces `ExecStart` with `transformers_ocr start --foreground` using `%h` for home directory resolution. |

All user services are enabled via [dotm](https://github.com/fkzys/dotm) (`dotm apply`), which manages both packages and services declaratively from `dotm.toml`. System services enabled: `firewalld`, `systemd-oomd`.

## Standalone scripts (`~/.local/bin/`)

| Script | Description |
|---|---|
| `ffmpeg_jp` | Extract Japanese (`--en` for English) audio track from video files as opus. Accepts a file, directory, or `$LF_SELECTED_FILES` from lf. Auto-detects target language track by language tag or title; falls back to the only track if there is exactly one. `--track N` overrides auto-detection with a manual stream index. Two-phase pipeline: demux (I/O-bound, low parallelism) → encode (CPU-bound, high parallelism). Output is forced to stereo (`-ac 2`). |
| `rename_subs` | Rename subtitle files (.srt, .ass, .sub) to match video filenames by episode number. Supports patterns like S01E05, 1x05, Ep05, Episode 05, bare numbers, and --dry-run. |
| `audio-device-switcher` | Switch default PipeWire audio output device via `wpctl` + `dmenu`. |
| `bt-audio` | Connect/disconnect paired Bluetooth audio devices via `dmenu`, auto-switch PipeWire sink on connect. |
| `cabl` | Clipboard plumber — reads selection/clipboard, presents context-sensitive actions via `dmenu`: dictionary lookups, Anki card creation, Forvo audio download, mecab headword extraction, media downloads, QR codes, man pages. |
| `ssh-add-keys` | Loads all SSH keys from `~/keys/ssh/` into `ssh-agent` with a 4-hour lifetime. Used by `ssh-add.service` and the lock/unlock script. |
| `wofi-launcher` | Sandboxed application launcher. Parses `.desktop` files on the host, resolves icons from the GTK icon theme, sorts entries by usage count, and displays the list via wofi inside a bwrap sandbox. Selection is mapped back to the `Exec=` command and launched on the host. |
| `dmenu` | Sandboxed `wofi --dmenu` wrapper providing `dmenu`-compatible CLI interface (used by `cabl`, `audio-device-switcher`, `bt-audio`). |

`ffmpeg_jp` and `rename_subs` are integrated into lf via keybindings (`o` for ffmpeg\_jp, `Ctrl-B` for rename\_subs).

## Firefox

Firefox runs as a flatpak with [arkenfox user.js](https://github.com/arkenfox/user.js). Overrides are managed via dotm at `~/.var/app/org.mozilla.firefox/.mozilla/firefox/arkenfox/user-overrides.js`.

Custom overrides include:
- Hardware video acceleration (VA-API)
- Disabled menu access key
- JIT disabled (`ion`, `baselinejit`, `native_regexp`) for security hardening
- Session restore enabled

## Secrets

Secrets are encrypted with [SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age) and accessed in templates via `output "sops" "-d"` — dotm delegates encryption entirely to external tools.

Each machine has its own age key. Keys are stored in the encrypted vault (`~/keys`), managed by [keys-vault](https://github.com/fkzys/keys-vault).

### Structure

```yaml
# secrets.enc.yaml

# Per-host (application → hostname → keys)
hyprland:
    hostname1:
        monitor: "DP-1,1920x1080@144,0x0,1"
hyprpaper:
    hostname1:
        wallpaper: "~/Downloads/background.jpg"
    hostname2:
        wallpaper: "/usr/share/hypr/wall2.png"
containers:
    hostname1:
        graphroot: "/path/to/storage"
sing-box:
    config_url:
        hostname1: https://example.com
        hostname2: https://example.com
mpv:
    hostname1:
        anime_dir: /path/to/anime
mpd:
    hostname1:
        music_dir: /path/to/music
qbittorrent:
    hostname1:
        anime_dir: /path/to/torrents
        anime_second_dir: /path/to/second/torrents
dir_aliases:
    hostname1:
        subs: /path/to/subtitles
        anime: /path/to/anime
PortProton:
    hostname1:
        games_dir: /path/to/games

# Global (application → keys)
fcitx5:
    kb_layouts:
        - us
keepassxc:
    db_dir: /path/to/database
nextcloud:
    sync_dir: /path/to/sync
goldendict:
    dict_dir: /path/to/dictionaries
    audio_dir: /path/to/audio
anki:
    audio_sources_dir: /path/to/audio/sources
    subs2srs_dir: /path/to/subs2srs
subs2srs:
    media_dir: /path/to/anime
```

## License

AGPL-3.0-or-later
