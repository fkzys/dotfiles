#!/usr/bin/env bash
# Sandboxed makepkg — called by yay via $MAKEPKG
set -euo pipefail
. "${HOME}/.local/lib/bwrap-common.sh"

BUILD_DIR="$(realpath "$PWD")"

A=()
bwrap_base A
bwrap_lib64 A
bwrap_resolv A
A+=(--ro-bind /var/lib/pacman /var/lib/pacman
    --ro-bind /var/cache/pacman /var/cache/pacman
    --tmpfs "${HOME}"
    --bind "${BUILD_DIR}" "${BUILD_DIR}")
bwrap_env_base A
bwrap_hardened_malloc A default
bwrap_sandbox A yes no

exec bwrap "${A[@]}" -- /usr/bin/makepkg "$@"
