# Dotfiles

## lf file manager

### Previews

Video and image previews use kitty's `icat` protocol, with `ffmpegthumbnailer` for video thumbnails. Videos with saved mpv position show the resume point and total duration overlaid; fully-watched files (a lf watched marker but no `watch_later` entry) get a `▣` badge. It reads mpv's `watch_later` files and lf's watched markers — both keyed by the MD5 of the absolute path — and annotates with ImageMagick.

The previewer runs in a bwrap sandbox with read-only access to the video directory, lf config, the vidthumb cache, mpv state and the watched markers; only the cache is writable.

### Watch tracking

An mpv script (`mark-watched.lua`) writes a watched marker on EOF and removes it on replay. lf then refreshes the preview and shows the resume position (or `▣ watched`) in the status bar.

### Git status

The info column shows per-file git status. It is computed once per directory — a single `git status --porcelain` parsed and pushed to lf via `lf -remote` — rather than per file, so large directories stay responsive.

## Keybindings

`m` play (mpv), `n` edit (nvim), `o` audio extraction (ffmpeg\_jp), `Ctrl-B` rename subtitles. See `files/.config/lf/lfrc` for the rest.
