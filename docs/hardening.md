# Dotfiles

## Memory allocator hardening

[hardened\_malloc](https://github.com/GrapheneOS/hardened_malloc) is installed as a separate [gitpkg](https://github.com/fkzys/gitpkg) package ([fkzys/hardened_malloc](https://github.com/fkzys/hardened_malloc)) and deployed in two variants:

- **light**, system-wide through `/etc/ld.so.preload` (zero-on-free, slab canaries, guard slabs);
- **default**, per app through bwrap `LD_PRELOAD` (adds slot randomization, write-after-free checks, slab quarantines).

The default variant reserves ~240 GB of `PROT_NONE` guard regions, which some loaders reject, so it is applied only where it survives.

- GTK4's [glycin](https://gitlab.gnome.org/GNOME/glycin) sets `RLIMIT_AS` on its image-loader sandboxes, which conflicts with that reservation; a `libfake_rlimit.so` shim intercepts `prlimit64(RLIMIT_AS)` and returns success without applying the limit.
- Apps with their own allocator (PartitionAlloc in QtWebEngine: anki, goldendict) and `fd` opt out with `malloc=no`, which masks the library with an empty stub; `fd` additionally masks `/etc/ld.so.preload`.

## Application sandboxing

GUI and CLI apps run under [bubblewrap](https://github.com/containers/bubblewrap) through wrappers in `files/.local/bin/`. The building blocks come from [bwrap-common](https://github.com/fkzys/bwrap-common), whose docs cover the helper API, D-Bus filtering and seccomp; read the individual wrappers for the binds each app gets.

- **Filtered D-Bus is the default**: `bwrap_dbus_common` starts an `xdg-dbus-proxy` limited to XDG portals, notifications, the status notifier, screen saver and a11y. Apps add `--own`/`--talk` for extra interfaces (secrets, kwallet, `RemoteDesktop`, ...), and apps that use no bus pass `dbus=none`.
- **A default seccomp blocklist** applies unless a wrapper opts out.
- **The network is unshared** unless the app asks for it.
- **GPU nodes** are exposed only to apps that need them.
- AUR builds (`yay`, `aurutils`) run `makepkg` with an empty `$HOME` tmpfs: `-s`/`--syncdeps` is rewritten to `-d`/`--nodeps` and `-r`/`--rmdeps` dropped, because bwrap's `no_new_privs` blocks the `sudo pacman` those flags would run; a no-op fakeroot shim replaces real fakeroot, whose `LD_PRELOAD` interposition clashes with hardened\_malloc.

Desktop launchers are redirected to the wrappers through `~/.local/share/applications/`; flatpak permission overrides live in `~/.local/share/flatpak/overrides/`.

OpenCloud and fcitx5 run as sandboxed systemd user services instead of through their own autostart/daemon paths (OpenCloud's autostart entry ships with `Hidden=true`).
