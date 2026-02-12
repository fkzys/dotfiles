#!/usr/bin/env bash
# Common bubblewrap helpers
# Source this file: . "${HOME}/.local/lib/bwrap-common.sh"

XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# ── GPU + NVIDIA ──────────────────────────────────────────────────
bwrap_gpu() {
    local -n _arr=$1
    [[ -d /dev/dri ]] && _arr+=(--dev-bind /dev/dri /dev/dri)
    local dev
    for dev in /dev/nvidia{0,1,2,3,ctl,-modeset,-uvm,-uvm-tools}; do
        [[ -e "$dev" ]] && _arr+=(--dev-bind "$dev" "$dev")
    done
    [[ -d /dev/nvidia-caps ]] && _arr+=(--dev-bind /dev/nvidia-caps /dev/nvidia-caps)
    return 0
}

# ── /usr/lib64 + symlinks ─────────────────────────────────────────
bwrap_lib64() {
    local -n _arr=$1
    if [[ -d /usr/lib64 && ! -L /usr/lib64 ]]; then
        _arr+=(--ro-bind /usr/lib64 /usr/lib64 --symlink /usr/lib64 /lib64)
    else
        _arr+=(--symlink /usr/lib /lib64)
    fi
    return 0
}

# ── resolv.conf (often symlink into /run) ──────────────────────────
bwrap_resolv() {
    local -n _arr=$1
    if [[ -L /etc/resolv.conf ]]; then
        local _rd
        _rd="$(dirname "$(realpath /etc/resolv.conf)")"
        _arr+=(--ro-bind "$_rd" "$_rd")
    fi
    return 0
}

# ── Wayland (native, connect() needs write) ────────────────────────
bwrap_wayland() {
    local -n _arr=$1
    local _wl="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY:-wayland-1}"
    if [[ -S "$_wl" ]]; then
        _arr+=(
            --bind "$_wl" "$_wl"
            --setenv WAYLAND_DISPLAY "${WAYLAND_DISPLAY:-wayland-1}"
        )
        [[ -f "${_wl}.lock" ]] && _arr+=(--ro-bind "${_wl}.lock" "${_wl}.lock")
    fi
    return 0
}

# ── X11 / XWayland ─────────────────────────────────────────────────
bwrap_x11() {
    local -n _arr=$1
    if [[ -n "${DISPLAY:-}" ]]; then
        [[ -d /tmp/.X11-unix ]] && _arr+=(--ro-bind /tmp/.X11-unix /tmp/.X11-unix)
        _arr+=(--setenv DISPLAY "${DISPLAY}")
        if [[ -n "${XAUTHORITY:-}" && -f "${XAUTHORITY}" ]]; then
            _arr+=(--ro-bind "${XAUTHORITY}" "${XAUTHORITY}" --setenv XAUTHORITY "${XAUTHORITY}")
        elif [[ -f "${HOME}/.Xauthority" ]]; then
            _arr+=(--ro-bind "${HOME}/.Xauthority" "${HOME}/.Xauthority" \
                   --setenv XAUTHORITY "${HOME}/.Xauthority")
        fi
    fi
    return 0
}

# ── Audio (PipeWire + PulseAudio) ──────────────────────────────────
bwrap_audio() {
    local -n _arr=$1
    [[ -S "${XDG_RUNTIME_DIR}/pipewire-0" ]] && \
        _arr+=(--bind "${XDG_RUNTIME_DIR}/pipewire-0" "${XDG_RUNTIME_DIR}/pipewire-0")
    [[ -d "${XDG_RUNTIME_DIR}/pulse" ]] && \
        _arr+=(--bind "${XDG_RUNTIME_DIR}/pulse" "${XDG_RUNTIME_DIR}/pulse")
    return 0
}

# ── D-Bus session ──────────────────────────────────────────────────
bwrap_dbus_session() {
    local -n _arr=$1
    local _bus="${DBUS_SESSION_BUS_ADDRESS:-}"
    if [[ "$_bus" == unix:path=* ]]; then
        local _bus_path="${_bus#unix:path=}"
        if [[ -S "$_bus_path" ]]; then
            _arr+=(
                --bind "$_bus_path" "$_bus_path"
                --setenv DBUS_SESSION_BUS_ADDRESS "$_bus"
            )
        fi
    elif [[ -S "${XDG_RUNTIME_DIR}/bus" ]]; then
        _arr+=(
            --bind "${XDG_RUNTIME_DIR}/bus" "${XDG_RUNTIME_DIR}/bus"
            --setenv DBUS_SESSION_BUS_ADDRESS "unix:path=${XDG_RUNTIME_DIR}/bus"
        )
    fi
    return 0
}

# ── D-Bus system ───────────────────────────────────────────────────
bwrap_dbus_system() {
    local -n _arr=$1
    if [[ -S /run/dbus/system_bus_socket ]]; then
        _arr+=(
            --perms 0755 --dir /run
            --perms 0755 --dir /run/dbus
            --bind /run/dbus/system_bus_socket /run/dbus/system_bus_socket
        )
    fi
    return 0
}

# ── Optional read-only home paths (themes, fonts, Qt) ──────────────
bwrap_themes() {
    local -n _arr=$1
    local p
    for p in \
        "${HOME}/.config/fontconfig" \
        "${HOME}/.config/qt6ct" \
        "${HOME}/.config/qt5ct" \
        "${HOME}/.config/gtk-3.0" \
        "${HOME}/.config/Kvantum" \
        "${HOME}/.local/share/fonts" \
        "${HOME}/.local/share/icons" \
        "${HOME}/.icons"; do
        [[ -e "$p" ]] && _arr+=(--ro-bind "$p" "$p")
    done
    return 0
}

# ── Resolve file arguments to bind mounts ──────────────────────────
bwrap_resolve_files() {
    local -n _binds=$1
    local -n _args=$2
    local _mode="${3:---ro-bind}"
    shift 3
    local arg
    for arg in "$@"; do
        if [[ "$arg" != -* && -e "$arg" ]]; then
            local _real _dir
            _real="$(realpath "$arg")"
            _dir="$(dirname "$_real")"
            case "$_dir" in
                /usr/*|/etc/*|/proc/*|/dev/*|/tmp*|/sys/*) ;;
                "${HOME}")
                    # File directly in $HOME — bind the file, not all of $HOME
                    _binds+=("$_mode" "$_real" "$_real")
                    ;;
                *) _binds+=("$_mode" "$_dir" "$_dir") ;;
            esac
            _args+=("$_real")
        else
            _args+=("$arg")
        fi
    done
    return 0
}

# ── Common base bwrap args ─────────────────────────────────────────
bwrap_base() {
    local -n _arr=$1
    _arr+=(
        --ro-bind /usr /usr
        --symlink /usr/bin /bin
        --symlink /usr/bin /sbin
        --symlink /usr/lib /lib
        --proc /proc
        --ro-bind /sys /sys
        --dev /dev
        --tmpfs /tmp
        --dev-bind /dev/shm /dev/shm
        --ro-bind /etc /etc
    )
    return 0
}

# ── Common home tmpfs skeleton ─────────────────────────────────────
bwrap_home_tmpfs() {
    local -n _arr=$1
    _arr+=(
        --tmpfs "${HOME}"
        --perms 0700 --dir "${HOME}/.config"
        --perms 0700 --dir "${HOME}/.local"
        --perms 0700 --dir "${HOME}/.local/share"
        --perms 0700 --dir "${HOME}/.local/state"
        --perms 0700 --dir "${HOME}/.cache"
    )
    return 0
}

# ── Common env vars ────────────────────────────────────────────────
bwrap_env_base() {
    local -n _arr=$1
    _arr+=(
        --setenv HOME "${HOME}"
        --setenv LANG "${LANG:-en_US.UTF-8}"
        --setenv PATH "/usr/bin:/bin"
        --setenv XDG_RUNTIME_DIR "${XDG_RUNTIME_DIR}"
        --setenv XDG_CACHE_HOME "${HOME}/.cache"
    )
    return 0
}

# ── hardened_malloc ────────────────────────────────────────────────
bwrap_hardened_malloc() {
    local -n _arr=$1
    local _variant="${2:-light}"
    local _lib="/usr/local/lib/libhardened_malloc.so"
    if [[ "$_variant" == "light" ]]; then
        _lib="/usr/local/lib/libhardened_malloc-light.so"
    fi
    if [[ -f "$_lib" ]]; then
        _arr+=(--setenv LD_PRELOAD "$_lib")
    fi
    return 0
}

bwrap_no_hardened_malloc() {
    local -n _arr=$1
    _arr+=(--unsetenv LD_PRELOAD
           --ro-bind /dev/null /etc/ld.so.preload)
    return 0
}

# ── Common sandbox flags ──────────────────────────────────────────
bwrap_sandbox() {
    local -n _arr=$1
    local _net="${2:-no}"
    local _new_session="${3:-yes}"
    _arr+=(--unshare-all)
    [[ "$_net" == "yes" ]] && _arr+=(--share-net)
    [[ "$_new_session" == "yes" ]] && _arr+=(--new-session)
    _arr+=(--die-with-parent)
    return 0
}

# ── fcitx5 input method ───────────────────────────────────────────
bwrap_fcitx() {
    local -n _arr=$1
    _arr+=(
        --setenv QT_IM_MODULE fcitx
        --setenv XMODIFIERS "@im=fcitx"
    )
    [[ -d "${HOME}/.config/fcitx5" ]] && _arr+=(--ro-bind "${HOME}/.config/fcitx5" "${HOME}/.config/fcitx5")
    local sock
    for sock in /tmp/fcitx5-*; do
        [[ -e "$sock" ]] && _arr+=(--bind "$sock" "$sock")
    done
    return 0
}

