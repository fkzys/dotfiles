#!/usr/bin/env bash
# Sandboxed makepkg — called by yay/aurutils
set -euo pipefail
_src() { local p; p=$(verify-lib "$1" "$2") && . "$p" || exit 1; }
_src /usr/lib/bwrap-common/bwrap-common.sh /usr/lib/bwrap-common/

BUILD_DIR="$(realpath "$PWD")"

A=()
bwrap_base A
bwrap_lib64 A
bwrap_resolv A
A+=(--ro-bind /var/lib/pacman /var/lib/pacman
    --ro-bind /var/cache/pacman /var/cache/pacman
    --tmpfs "${HOME}"
    --bind "${BUILD_DIR}" "${BUILD_DIR}")

# aur-build sets PKGDEST to /var/tmp/... for collecting built packages
# makepkg.conf may also set SRCPKGDEST, LOGDEST, BUILDDIR
for _dest in PKGDEST SRCPKGDEST LOGDEST BUILDDIR; do
    if [[ -n "${!_dest:-}" ]]; then
        mkdir -p "${!_dest}"
        A+=(--bind "${!_dest}" "${!_dest}")
    fi
done

bwrap_env_base A
bwrap_hardened_malloc A default
bwrap_sandbox A yes no

exec bwrap "${A[@]}" -- /usr/bin/makepkg "$@"
