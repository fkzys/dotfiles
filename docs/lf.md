# Dotfiles

## lf file manager

### Previews

Video and image previews use kitty's `icat` protocol. Videos get cached thumbnails via `ffmpegthumbnailer`.

For videos with saved mpv playback position, the resume point and total duration are overlaid on the thumbnail (e.g. `⏸ 12:34 / 25:20`). Fully watched videos (no `watch_later` entry but a marker in `~/.local/state/lf/watched/`) show a `▣` badge with total duration. The previewer reads mpv's `watch_later` state files and the watched markers (both keyed by MD5 of the absolute path) and annotates via ImageMagick. Font is auto-detected from common system paths with `fc-match` as fallback.

The previewer runs inside a bwrap sandbox with read-only access to the video directory, lf config, vidthumb cache, mpv watch\_later state, and lf watched markers. Only the vidthumb cache is writable.

### Watch tracking

An mpv script (`mark-watched.lua`) creates watched markers on playback completion (EOF) and removes them when a file is replayed.

After mpv exits, lf auto-refreshes the preview. An `on-select` hook displays the mpv resume position in the status bar when navigating to a video with saved state (e.g. `⏸ 12:34`), or `▣ watched` for fully watched videos.

### Git status

Per-file git status is shown in the right info column via `set info custom` and `addcustominfo`. An `on-load` hook runs one `git status --porcelain` call per directory, parses all entries, and sends status codes to lf via `lf -remote`. An `on-init` hook triggers a reload to ensure the lf server has registered the client before the first `on-load` fires.

Files with uncommitted changes show their two-character porcelain status code (e.g. `M `, `??`, `D `). Clean files show `clean`. Non-repository directories show no status.

### Keybindings

| Key | Action |
|---|---|
| `m` | Play with mpv (auto-refreshes preview on exit) |
| `n` | Edit with nvim |
| `o` | Extract audio with ffmpeg\_jp (Japanese by default, `--en` for English) |
| `Ctrl-B` | Rename subtitles to match videos |

## License

AGPL-3.0-or-later
