# Dotfiles

## Memory allocator hardening

[hardened\_malloc](https://github.com/GrapheneOS/hardened_malloc) is deployed system-wide via `/etc/ld.so.preload` (light variant) and per-app via bwrap `LD_PRELOAD` (default variant). Installed as a separate package via [gitpkg](https://github.com/fkzys/gitpkg) — see [hardened_malloc](https://github.com/fkzys/hardened_malloc).

The light variant provides zero-on-free, slab canaries, and guard slabs. The default variant adds slot randomization, write-after-free checks, and slab quarantines.

GTK4 uses [glycin](https://gitlab.gnome.org/GNOME/glycin) for image loading, which sets `RLIMIT_AS` on its sandboxed loader processes. This is incompatible with hardened\_malloc's large virtual memory reservation (~240 GB `PROT_NONE` guard regions). A `libfake_rlimit.so` shim intercepts `prlimit64(RLIMIT_AS)` calls, returning success without applying the limit.

Applications with incompatible custom allocators (e.g. PartitionAlloc in QtWebEngine) opt out with `malloc=no`, which makes bwrap-common overlay the hardened\_malloc shared objects with an empty stub (`bwrap_no_hardened_malloc`); `fd` additionally masks the system-wide `/etc/ld.so.preload` with `--bind /dev/null /etc/ld.so.preload`.

| Allocator | Applications |
|---|---|
| default (via bwrap) | imv, keepassxc, krita, mpv, obs, nvim, lazygit, opencode, qbittorrent, gimp, swappy, makepkg, fcitx5, opencloud, otd-daemon, sparrow, wasabi, transformers\_ocr, subs2srs, subsretimer, wofi-launcher, dmenu (wofi) |
| light (system-wide) | hyprland, waybar, kitty, thunar, all other native processes |
| disabled | anki, fd, goldendict (PartitionAlloc / QtWebEngine) |
| not applicable | flatpak apps (own runtime) |

## Application sandboxing

GUI and CLI applications are sandboxed via [bubblewrap](https://github.com/containers/bubblewrap) wrappers in `~/.local/bin/`. A shared library [bwrap-common](https://github.com/fkzys/bwrap-common) (`/usr/lib/bwrap-common/bwrap-common.sh`) provides reusable helpers for GPU, Wayland/X11, audio, session/system D-Bus (including a filtered `xdg-dbus-proxy` mode), seccomp filters, XDG runtime dirs, filesystem setup, and hardened\_malloc integration. High-level wrappers use the `bwrap_gui_setup`/`bwrap_gui_finish` pair, which defaults to a filtered D-Bus proxy (`bwrap_dbus_common`: an `xdg-dbus-proxy` allowlist of portals, notifications, StatusNotifier, ScreenSaver and a11y) and the compile-cached default seccomp blocklist; wrappers that manage D-Bus themselves pass `dbus=none`, and `bwrap_exec` runs bwrap as a foreground child and tears the proxies down on exit.

Before sourcing, each wrapper validates the library with [verify-lib](https://github.com/fkzys/verify-lib) — a compiled binary that checks file ownership, permissions, and symlink integrity:

```sh
_src() { local p; p=$(verify-lib "$1" "$2") && . "$p" || exit 1; }
_src /usr/lib/bwrap-common/bwrap-common.sh /usr/lib/bwrap-common/
```

AUR builds via `yay` and `aurutils` are sandboxed — `makepkg` runs inside bwrap with `$HOME` as empty tmpfs, preventing PKGBUILD `build()` from accessing SSH keys, configs, or other sensitive data. The wrapper replaces `-s`/`--syncdeps` with `-d`/`--nodeps` and strips `-r`/`--rmdeps`, since bwrap's `no_new_privs` prevents `sudo pacman` inside the sandbox and both `yay` and `aurutils` resolve dependencies before calling `makepkg`. A no-op fakeroot shim is injected into `PATH` inside the sandbox to bypass incompatibility between real fakeroot's `LD_PRELOAD` interposition and hardened\_malloc — the shim sets a dummy `FAKEROOTKEY` and exec's the wrapped command directly; package tarball ownership is handled by makepkg's `bsdtar --uid/--gid` flags independently of fakeroot. Build output directories (`PKGDEST`, `SRCPKGDEST`, `LOGDEST`, `BUILDDIR`) are bind-mounted and re-exported (`--setenv`) into the sandbox when set by the caller, and the XDG runtime dir is recreated inside it.

System desktop entries are overridden in `~/.local/share/applications/` to redirect `Exec=` to the bwrap wrappers, ensuring applications launch sandboxed from application launchers and file associations.

Flatpak applications have per-app permission overrides in `~/.local/share/flatpak/overrides/`.

OpenCloud and fcitx5 are launched via systemd user services (`opencloud.service`, `fcitx5.service`). Both units point at the bwrap wrappers (`%h/.local/bin/opencloud`, `%h/.local/bin/fcitx5`) and are bound to `graphical-session.target`. OpenCloud's own autostart entry is neutralized: `~/.config/autostart/OpenCloud.desktop` ships with `Hidden=true`.

subs2srs and SubsReTimer have XDG desktop entries (`~/.local/share/applications/`) for launcher integration.

| Application | Display | Network | Notes |
|---|---|---|---|
| anki | Wayland | yes | QtWebEngine, Anki2 data dir, Downloads/anki, audio sources dir + subs2srs dir from secrets |
| dmenu (wofi) | Wayland | no | Sandboxed wofi --dmenu wrapper, config/cache dirs |
| fd | terminal | no | Bwrap wrapper with full filesystem access (`--dev-bind / /`), hardened_malloc disabled (`/etc/ld.so.preload` masked) |
| fcitx5 | Wayland | no | Input method daemon, socket dir shared via `/tmp/fcitx5-$UID`, D-Bus session access |
| gimp | Wayland | no | Pictures/Downloads rw |
| goldendict | XWayland | no | Dictionary + audio dirs from secrets, fcitx5 input, no hardened\_malloc |
| imv | Wayland | no | Read-only file viewer, fontconfig |
| keepassxc | Wayland | no | DB dir from secrets, fcitx5 input, isolated from network |
| krita | XWayland | no | Separate config dir trick, Pictures/Downloads rw, audio, fcitx5 input |
| lazygit | terminal | yes | CWD bind, SSH agent forwarding, `~/keys/git-rtz` + `~/.cache/git-rtz` mounted, dispatches through the git-rtz wrapper |
| mpv | Wayland | yes | subs2srs/mpvacious, Anki2 integration, watch\_later + watched state dirs, Screenshots |
| opencloud | Wayland | yes | Sync dir from secrets, filtered D-Bus (secrets, kwallet), `$XDG_RUNTIME_DIR/keyring` bound read-only |
| nvim | terminal | yes | CWD + file args, clipboard via Wayland |
| obs | Wayland | yes | Camera devices, Videos dir |
| opencode | Wayland | yes | Coding agent: config/state/cache/pnpm store and project dir bound, `opencode.json` + `auth.json` read-only, no themes, no seccomp |
| otd-daemon | Wayland (no GUI) | no | OpenTabletDriver daemon, full `/dev` access for tablet devices, Wayland socket for tablet mapping |
| qbittorrent | Wayland | yes | Download dirs from secrets |
| sparrow | XWayland | yes | Bitcoin wallet, `/opt/sparrow` read-only bind, Java AWT non-reparenting, filtered D-Bus |
| wasabi | XWayland | yes | Bitcoin wallet, `/opt/WasabiWallet` read-only bind, `~/.walletwasabi` writable, filtered D-Bus owning `org.kde.*`, no GPU, own `libHarfBuzzSharp.so` preloaded alongside hardened\_malloc |
| subs2srs | Wayland | no | Native binary, media dir read-only from secrets, output + log dirs writable, audio, fcitx5 input |
| subsretimer | XWayland | no | Mono/.NET app (SubsReTimer.exe), media dir read-only from secrets, output dir writable, fcitx5 input |
| swappy | Wayland | no | Screenshots dir, filtered D-Bus owning `me.jtheoof.swappy` |
| transformers\_ocr | Wayland | yes | OCR daemon (foreground) sandboxed with GPU access, Python venv read-only; IPC runtime dir bind-mounted for host↔sandbox FIFO/PID visibility; filtered D-Bus; client commands (recognize, hold, stop) run unsandboxed on host |
| wofi-launcher | Wayland | no | Application launcher; .desktop parsing + icon lookup on host, wofi display inside sandbox; icon dirs read-only, usage cache writable |
| yay / aurutils (makepkg) | — | yes | `$HOME` is tmpfs, `-s`→`-d` / `-r` stripped (no\_new\_privs blocks sudo), no-op fakeroot shim (hardened\_malloc compat), build dir + `PKGDEST`/`SRCPKGDEST`/`LOGDEST`/`BUILDDIR` writable |

Per-host data directories (media paths, download dirs) are configured in `secrets.enc.yaml` under each application key, keyed by hostname.

For the full list of bwrap-common functions and wrapper patterns, see [bwrap-common](https://github.com/fkzys/bwrap-common).

## License

AGPL-3.0-or-later
