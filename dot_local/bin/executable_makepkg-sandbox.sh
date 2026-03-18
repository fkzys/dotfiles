#!/usr/bin/env bash
# Sandboxed makepkg — consumed by aurutils (AUR_MAKEPKG) and yay (--makepkg)
set -euo pipefail
_src() { local p; p=$(verify-lib "$1" "$2") && . "$p" || exit 1; }
_src /usr/lib/bwrap-common/bwrap-common.sh /usr/lib/bwrap-common/

BUILD_DIR="$(realpath "$PWD")"

# ── Rewrite flags for sandbox ──────────────────────────────
# -s/--syncdeps → -d/--nodeps  (sudo unavailable under no_new_privs)
# -r/--rmdeps   → dropped      (same reason)
# Deps are pre-installed by aurutils/yay before makepkg runs.
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

# ── No-op fakeroot shim ────────────────────────────────────
# Real fakeroot uses LD_PRELOAD to intercept chown/stat/getuid.
# hardened_malloc in LD_PRELOAD breaks this interposition:
# fakeroot's wrapper script launches the command, but
# libfakeroot.so cannot properly intercept libc symbols when
# hardened_malloc has already replaced the allocator, causing
# chown() to hit the real kernel syscall → EINVAL in a user
# namespace where uid 0 is unmapped.
#
# The shim exec's the wrapped command without any LD_PRELOAD
# manipulation. Without fakeroot, getuid() returns the real
# uid so tar/install never attempt chown(0,0). Package tarball
# ownership is set to 0:0 by bsdtar's --uid/--gid flags that
# makepkg passes in create_package() regardless of fakeroot.
SHIM_DIR="$(mktemp -d)"
cat > "${SHIM_DIR}/fakeroot" <<'SHIM'
#!/bin/sh
# Skip all fakeroot flags, exec the trailing command.
# fakeroot synopsis: fakeroot [-l lib] [-s file] [-i file] [-u] [-b fd] [-h] [--] cmd [args]
while [ $# -gt 0 ]; do
    case "$1" in
        --)          shift; break ;;
        -l|-s|-i|-b) shift; shift ;;
        -*)          shift ;;
        *)           break ;;
    esac
done
# makepkg -F checks FAKEROOTKEY to confirm it is running inside
# fakeroot. Set a dummy value so the internal flag is accepted.
export FAKEROOTKEY=1
exec "$@"
SHIM
chmod 755 "${SHIM_DIR}/fakeroot"
trap 'rm -rf "${SHIM_DIR}"' EXIT

# ── Assemble bwrap args ─────────────────────────────────────
A=()
bwrap_base A
bwrap_lib64 A
bwrap_resolv A
A+=(--ro-bind /var/lib/pacman /var/lib/pacman
    --ro-bind /var/cache/pacman /var/cache/pacman
    --tmpfs "${HOME}"
    --bind "${BUILD_DIR}" "${BUILD_DIR}"
    --ro-bind "${SHIM_DIR}" /tmp/makepkg-shims)

for _dest in PKGDEST SRCPKGDEST LOGDEST BUILDDIR; do
    if [[ -n "${!_dest:-}" ]]; then
        mkdir -p "${!_dest}"
        A+=(--bind "${!_dest}" "${!_dest}")
    fi
done

bwrap_env_base A
# Prepend shim dir so makepkg finds our no-op fakeroot first
A+=(--setenv PATH "/tmp/makepkg-shims:/usr/bin:/bin")
bwrap_hardened_malloc A default
A+=(--unshare-ipc
    --unshare-pid
    --unshare-uts
    --unshare-cgroup-try
    --share-net
    --die-with-parent)

exec bwrap "${A[@]}" -- /usr/bin/makepkg "${INNER_ARGS[@]}"
