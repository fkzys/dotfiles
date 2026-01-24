#!/bin/bash
set -euo pipefail

command -v hyprsunset &>/dev/null || { echo "hyprsunset not found" >&2; exit 1; }
[[ -n "${WAYLAND_DISPLAY:-}" ]] || { echo "Wayland session required" >&2; exit 1; }

readonly NIGHT_TEMP=${NIGHT_TEMP:-4000}
readonly DAY_TEMP=${DAY_TEMP:-6500}
readonly NIGHT_START=${NIGHT_START:-22}
readonly NIGHT_END=${NIGHT_END:-7}
readonly CHECK_INTERVAL=${CHECK_INTERVAL:-60}

validate_config() {
    local errors=0
    [[ "$NIGHT_TEMP" =~ ^[0-9]+$ ]] && (( NIGHT_TEMP >= 1000 && NIGHT_TEMP <= 10000 )) || { echo "Invalid NIGHT_TEMP" >&2; ((errors++)); }
    [[ "$DAY_TEMP" =~ ^[0-9]+$ ]] && (( DAY_TEMP >= 1000 && DAY_TEMP <= 10000 )) || { echo "Invalid DAY_TEMP" >&2; ((errors++)); }
    [[ "$NIGHT_START" =~ ^[0-9]+$ ]] && (( NIGHT_START >= 0 && NIGHT_START <= 23 )) || { echo "Invalid NIGHT_START" >&2; ((errors++)); }
    [[ "$NIGHT_END" =~ ^[0-9]+$ ]] && (( NIGHT_END >= 0 && NIGHT_END <= 23 )) || { echo "Invalid NIGHT_END" >&2; ((errors++)); }
    (( errors == 0 )) || exit 1
}
validate_config

readonly PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/hyprsunset-manager.pid"

if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Already running (PID $(cat "$PIDFILE"))" >&2
    exit 1
fi
echo $$ > "$PIDFILE"

cleanup() {
    pkill -x hyprsunset 2>/dev/null || true
    rm -f "$PIDFILE"
    exit 0
}
trap cleanup SIGTERM SIGINT SIGHUP EXIT

apply_temp() {
    local temp=$1
    pkill -x hyprsunset 2>/dev/null || true
    sleep 0.1
    hyprsunset -t "$temp" &>/dev/null &
    local pid=$!
    sleep 0.2
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "Failed to start hyprsunset" >&2
        return 1
    fi
    disown "$pid"
    log "Applied temperature: ${temp}K"
}

get_target_temp() {
    local hour
    hour=$(date +%-H)
    if (( hour >= NIGHT_START || hour < NIGHT_END )); then
        echo "$NIGHT_TEMP"
    else
        echo "$DAY_TEMP"
    fi
}

main() {
    local current_temp="" target
    
    while true; do
        target=$(get_target_temp)
        if [[ "$target" != "$current_temp" ]]; then
            apply_temp "$target"
            current_temp="$target"
        fi
        sleep "$CHECK_INTERVAL" &
        wait $! 2>/dev/null || true
    done
}

main "$@"
