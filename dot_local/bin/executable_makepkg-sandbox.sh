#!/usr/bin/env bash
# Sandboxed makepkg — called by yay via $MAKEPKG
set -euo pipefail
. "${HOME}/.local/lib/bwrap-common.sh"

BUILD_DIR="$(realpath "$PWD")"

A=(
    --ro-bind /usr /usr
    --symlink /usr/bin /bin
    --symlink /usr/bin /sbin
    --symlink /usr/lib /lib
    --proc /proc
    --dev /dev
    --tmpfs /tmp
    --ro-bind /etc /etc
    --ro-bind /var/lib/pacman /var/lib/pacman
    --ro-bind /var/cache/pacman /var/cache/pacman
    --tmpfs "${HOME}"
    --bind "${BUILD_DIR}" "${BUILD_DIR}"
)

bwrap_lib64 A
bwrap_resolv A

A+=(--setenv HOME "${HOME}"
    --setenv PATH "/usr/bin:/bin"
    --setenv LANG "${LANG:-en_US.UTF-8}"
    --unshare-all
    --share-net
    --die-with-parent)

exec bwrap "${A[@]}" -- /usr/bin/makepkg "$@"
