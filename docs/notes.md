# Dotfiles

## Per-host configuration

Feature flags are chosen by `dotm init` and stored under `~/.local/state/dotm/`. The prompts and what each flag toggles live in `dotm.toml`; the per-host data they pull in (monitor line, wallpaper, container graphroot, directory aliases) lives per hostname in `secrets.enc.yaml`.

## Shell

zsh with no framework: prompt, completions and keybindings are hand-rolled in `files/.zshrc.tmpl`.

- `~/.local/bin` and the pnpm bin are prepended and deduplicated through zsh's `path` array (`typeset -U path`).
- `nomalloc` re-runs a command with hardened\_malloc masked from outside any sandbox, for the occasional app that misbehaves under the preload.

## Systemd user services

Services are declared in `dotm.toml`. Login order matters: `keys-vault` mounts the gocryptfs vault first, then `ssh-add` loads keys from it after `ssh-agent`.

- `hyprsunset` filters its own `[TRACE]` log spam and uses `KillMode=control-group` so it shuts down cleanly.
- `transformers_ocr` runs `start --foreground` under systemd (with `%h`) instead of daemonizing itself.
- `opentabletdriver` is a systemd unit (`PartOf=graphical-session.target`) rather than a Hyprland `exec-once`, so it survives Hyprland restarts.

## Hyprland scripts

- `lock.sh` (bound to `SUPER+CTRL+L`, and the `hypridle` `lock_cmd`) de-authorizes USB devices and closes the vault before running `hyprlock`, then restores both — so nothing new can be attached while the session is locked.
- `screenshot.sh` (`SUPER+SHIFT+F`) pipes a `slurp` region through `grim` into `swappy`.

## Scripts

Wrappers and tools live in `files/.local/bin/`; each script's header/`--help` is its reference.

- `git` (git-rtz) assigns commit and tag dates a random IANA time zone, chosen per year from a salt in `~/keys/git-rtz`. The salt must be encrypted at rest, and past years' key material is shredded for forward secrecy. Wrapper-only flags (`--regen`, `--segments N`, `--verbose`) require `--wrapper`.
- `rewrite_secret_history.py` is a `git-filter-repo` callback that writes a file's current content into its ancestor commits — used to scrub a leaked secret from history.

## Firefox

Firefox is a flatpak running [arkenfox user.js](https://github.com/arkenfox/user.js). The overrides in `files/.var/app/org.mozilla.firefox/.mozilla/firefox/arkenfox/user-overrides.js` disable JIT and WebGL and turn off password saving and form autofill — hardening, at some speed and convenience cost.

## Secrets

Secrets are SOPS + age, one key per machine; templates read values via `output "sops" "-d"` and dotm delegates encryption to those tools. `secrets.enc.yaml` is namespaced:

- per host: `hyprland.monitor`, `hyprpaper.wallpaper`, `containers.graphroot`, `sing-box.config_url`, `mpv`/`mpd`/`qbittorrent` dirs, `PortProton.games_dir`, and `dir_aliases` (per-host `cd` shortcuts)
- global: `fcitx5.kb_layouts`, `keepassxc.db_dir`, `opencloud.sync_dir`, `goldendict.dict_dir`/`audio_dir`, `anki.audio_sources_dir`/`subs2srs_dir`, `subs2srs.media_dir`

SSH keys live in `~/keys/ssh/`; `github.com` and `aur.archlinux.org` use a dedicated `git-id_ed25519` (also the commit signing key), everything else uses `id_ed25519`. The git-rtz salt under `~/keys/git-rtz` must be encrypted at rest — `GIT_RANDOM_TZ_REQUIRE_MOUNT=yes` aborts when it is not a mount point.
