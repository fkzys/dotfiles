#!/usr/bin/env bash
# Sandboxed makepkg — consumed by aurutils (AUR_MAKEPKG) and yay (--makepkg)
set -euo pipefail
_src() { local p; p=$(verify-lib "$1" "$2") && . "$p" || exit 1; }
_src /usr/lib/bwrap-common/bwrap-common.sh /usr/lib/bwrap-common/

BUILD_DIR="$(realpath "$PWD")"

# Replace -s/--syncdeps with -d/--nodeps, strip -r/--rmdeps.
#
# bwrap sets no_new_privs=1 (kernel requirement for unprivileged user
# namespaces), preventing sudo/setuid — makepkg -s cannot call
# sudo pacman -S inside the sandbox.
#
# aurutils: aur-build handles deps via --syncdeps before makepkg.
# yay: resolves and installs deps itself before calling makepkg.
# Both cases: deps are already present when makepkg runs.
#
# -d skips pacman -T check. Files are available via --ro-bind /usr.
# Package metadata (depends=()) is unaffected.
INNER_ARGS=()
HAS_NODEPS=0
for _a in "$@"; do
    case "$_a" in
        --syncdeps|--rmdeps) ;;
        --nodeps) HAS_NODEPS=1; INNER_ARGS+=("$_a") ;;
        -*)
            if [[ "$_a" != --* && "$_a" == *[sr]* ]]; then
                _stripped="${_a//[sr]/}"
                [[ "$_stripped" != "-" ]] && INNER_ARGS+=("$_stripped")
            else
                INNER_ARGS+=("$_a")
            fi
            ;;
        *) INNER_ARGS+=("$_a") ;;
    esac
done
(( HAS_NODEPS )) || INNER_ARGS+=(-d)

A=()
bwrap_base A
bwrap_lib64 A
bwrap_resolv A
A+=(--ro-bind /var/lib/pacman /var/lib/pacman
    --ro-bind /var/cache/pacman /var/cache/pacman
    --tmpfs "${HOME}"
    --bind "${BUILD_DIR}" "${BUILD_DIR}")

for _dest in PKGDEST SRCPKGDEST LOGDEST BUILDDIR; do
    if [[ -n "${!_dest:-}" ]]; then
        mkdir -p "${!_dest}"
        A+=(--bind "${!_dest}" "${!_dest}")
    fi
done

bwrap_env_base A
bwrap_hardened_malloc A default
bwrap_sandbox A yes no

exec bwrap "${A[@]}" -- /usr/bin/makepkg "${INNER_ARGS[@]}"
