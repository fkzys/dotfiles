#!/usr/bin/env bash
# Functional tests for files/.local/bin/git (git-rtz wrapper).
set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
WRAPPER="$REPO_ROOT/files/.local/bin/git"
CURRENT_YEAR=$(TZ=UTC date +%Y)

if [[ ! -f "$WRAPPER" ]]; then
    echo "wrapper not found: $WRAPPER" >&2
    exit 2
fi

# Resolve a real git explicitly instead of trusting whatever "git" the
# caller's PATH resolves to (it may be this wrapper or another shim).
find_real_git() {
    local dir candidate resolved wrapper_resolved first2
    wrapper_resolved=$(readlink -f -- "$WRAPPER")
    local IFS=:
    for dir in $PATH; do
        [[ -n "$dir" ]] || continue
        candidate="$dir/git"
        [[ -f "$candidate" && -x "$candidate" ]] || continue
        resolved=$(readlink -f -- "$candidate" 2>/dev/null) || continue
        [[ "$resolved" == "$wrapper_resolved" ]] && continue
        first2=$(head -c 2 -- "$candidate" 2>/dev/null) || first2=""
        [[ "$first2" == "#!" ]] && continue
        printf '%s\n' "$candidate"
        return 0
    done
    return 1
}

REAL_GIT=$(find_real_git) || {
    echo "real git binary not found in PATH (wrapper scripts are ignored)" >&2
    exit 2
}
REAL_GIT=$(readlink -f -- "$REAL_GIT")
REAL_GIT_DIR=$(dirname -- "$REAL_GIT")
WRAPPER_DIR=$(dirname -- "$(readlink -f -- "$WRAPPER")")

path_without_dir() {
    local remove=$1 path=$2 entry out=""
    local IFS=:
    for entry in $path; do
        [[ -n "$entry" ]] || continue
        if [[ "$(readlink -f -- "$entry" 2>/dev/null)" == "$remove" ]]; then
            continue
        fi
        out+="${out:+:}$entry"
    done
    printf '%s\n' "$out"
}

SAFE_PATH=$(path_without_dir "$WRAPPER_DIR" "$PATH")
SAFE_PATH="$REAL_GIT_DIR${SAFE_PATH:+:$SAFE_PATH}"

for tab in /usr/share/zoneinfo/zone1970.tab /usr/share/zoneinfo/zone.tab; do
    [[ -r "$tab" ]] && break
done
if [[ ! -r "$tab" ]]; then
    echo "tzdata not found: need zone1970.tab or zone.tab" >&2
    exit 2
fi

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/git-rtz-test.XXXXXX")
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL  %s  (%s)\n' "$1" "${2:-}"; }

assert_rc() {
    local name=$1 expected=$2 actual=$3
    if [[ "$actual" == "$expected" ]]; then pass "$name"; else fail "$name" "expected rc $expected, got $actual"; fi
}

assert_eq() {
    local name=$1 expected=$2 actual=$3
    if [[ "$actual" == "$expected" ]]; then pass "$name"; else fail "$name" "expected [$expected], got [$actual]"; fi
}

assert_ne() {
    local name=$1 unexpected=$2 actual=$3
    if [[ "$actual" != "$unexpected" ]]; then pass "$name"; else fail "$name" "value must differ from [$unexpected]"; fi
}

assert_contains() {
    local name=$1 needle=$2 haystack=$3
    if [[ "$haystack" == *"$needle"* ]]; then pass "$name"; else fail "$name" "missing [$needle] in output: [$haystack]"; fi
}

assert_not_contains() {
    local name=$1 needle=$2 haystack=$3
    if [[ "$haystack" != *"$needle"* ]]; then pass "$name"; else fail "$name" "unexpected [$needle] in output"; fi
}

assert_file() {
    local name=$1 path=$2
    if [[ -e "$path" ]]; then pass "$name"; else fail "$name" "missing $path"; fi
}

assert_no_file() {
    local name=$1 path=$2
    if [[ ! -e "$path" ]]; then pass "$name"; else fail "$name" "unexpected file $path"; fi
}

assert_empty_dir() {
    local name=$1 path=$2
    if [[ ! -d "$path" ]]; then pass "$name"; return; fi
    if [[ -z "$(find "$path" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        pass "$name"
    else
        fail "$name" "directory not empty: $path"
    fi
}

assert_no_temp() {
    local name=$1 path=$2
    if [[ -z "$(find "$path" -maxdepth 1 \( -name '.salt-*' -o -name '.segments-*' \) -print -quit 2>/dev/null)" ]]; then
        pass "$name"
    else
        fail "$name" "temp files left in $path"
    fi
}

assert_segment_count() {
    local name=$1 expected=$2 file=$3 actual
    actual=$(( $(wc -l < "$file") - 1 ))
    assert_eq "$name" "$expected" "$actual"
}

new_env() {
    local name=$1
    ENV_ROOT="$TEST_ROOT/$name"
    KEYS="$ENV_ROOT/keys"
    CACHE="$ENV_ROOT/cache"
    CACHE_DIR="$CACHE/git-rtz"
    REPO="$ENV_ROOT/repo"
    mkdir -p "$ENV_ROOT/home" "$ENV_ROOT/config" "$KEYS" "$CACHE" "$REPO" "$ENV_ROOT/tmp"
    vgit init -q "$REPO"
    vgit -C "$REPO" config user.name Test
    vgit -C "$REPO" config user.email test@example.com
}

# Verification git: avoid the user's global/system config and signing hooks.
vgit() {
    (
        unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
            GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE \
            GIT_PREFIX GIT_EXEC_PATH GIT_CONFIG GIT_CONFIG_GLOBAL \
            GIT_CONFIG_SYSTEM GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS \
            GIT_AUTHOR_DATE GIT_COMMITTER_DATE GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL \
            GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_CEILING_DIRECTORIES
        HOME="$ENV_ROOT/home" \
        XDG_CONFIG_HOME="$ENV_ROOT/config" \
        GIT_CONFIG_NOSYSTEM=1 \
        GIT_PAGER=cat \
        PAGER=cat \
        "$REAL_GIT" "$@"
    )
}

run_wrapper() {
    (
        cd "$ENV_ROOT/tmp" || exit 1
        unset GIT_COMMITTER_DATE GIT_AUTHOR_DATE GIT_CONFIG GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM \
            GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
            GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE \
            GIT_PREFIX GIT_EXEC_PATH GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS \
            GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL \
            GIT_CEILING_DIRECTORIES GIT_RANDOM_TZ_SEGMENTS
        export PATH="$SAFE_PATH"
        export HOME="$ENV_ROOT/home"
        export XDG_CONFIG_HOME="$ENV_ROOT/config"
        export XDG_CACHE_HOME="$CACHE"
        export GIT_RANDOM_TZ_KEYS="$KEYS"
        export GIT_CONFIG_NOSYSTEM=1
        export GIT_PAGER=cat
        export PAGER=cat
        export YEAR="${TEST_YEAR:-$CURRENT_YEAR}"
        export TZ="${TEST_TZ:-UTC}"
        if [[ -n "${TEST_SEGMENTS:-}" ]]; then
            export GIT_RANDOM_TZ_SEGMENTS="$TEST_SEGMENTS"
        fi
        bash "$WRAPPER" "$@"
    )
}

new_env help
OUT=$(run_wrapper --wrapper --help 2>&1); RC=$?
assert_rc "help exits 0" 0 "$RC"
assert_contains "help documents --regen" "--regen" "$OUT"
assert_contains "help documents --segments" "--segments" "$OUT"
assert_contains "help documents segment default" "6..9" "$OUT"
assert_contains "help documents segment warning" "More than 10" "$OUT"
assert_contains "help documents segment env" "GIT_RANDOM_TZ_SEGMENTS" "$OUT"
assert_contains "help documents --verbose" "--verbose" "$OUT"

OUT=$(run_wrapper --wrapper 2>&1); RC=$?
assert_rc "bare --wrapper shows help" 0 "$RC"
assert_contains "bare --wrapper help text" "Usage: git --wrapper" "$OUT"

new_env nowrapper
OUT=$(run_wrapper -C "$REPO" commit --allow-empty -m plain 2>&1); RC=$?
assert_rc "plain git commit works" 0 "$RC"
assert_eq "plain git subject" "plain" "$(vgit -C "$REPO" log -1 --format=%s)"
assert_file "plain git commit creates salt" "$KEYS/salt-$CURRENT_YEAR"
assert_file "plain git commit creates segments" "$KEYS/segments-$CURRENT_YEAR"
assert_file "plain git commit creates state" "$CACHE_DIR/state-$CURRENT_YEAR"
NOW=$(vgit -C "$REPO" log -1 --format=%ct)
PLAIN_ZONE=$(awk -v now="$NOW" '$1 <= now && now < $2 { print $3; exit }' "$KEYS/segments-$CURRENT_YEAR")
PLAIN_EXPECTED=$(TZ="$PLAIN_ZONE" date -d "@$NOW" +%z)
OFFSET=$(vgit -C "$REPO" log -1 --format=%cd --date=format:%z)
assert_eq "plain git commit uses scheduled zone" "$PLAIN_EXPECTED" "$OFFSET"

new_env nowrapper_nontz
OUT=$(run_wrapper -C "$REPO" status 2>&1); RC=$?
assert_rc "plain git status works" 0 "$RC"
assert_empty_dir "plain git status creates no keys" "$KEYS"
assert_no_file "plain git status creates no state" "$CACHE_DIR/state-$CURRENT_YEAR"

new_env literal
OUT=$(run_wrapper -C "$REPO" commit --allow-empty -m --wrapper 2>&1); RC=$?
assert_rc "commit -m --wrapper works without wrapper" 0 "$RC"
assert_eq "literal --wrapper kept as message" "--wrapper" "$(vgit -C "$REPO" log -1 --format=%s)"
assert_file "literal --wrapper commit creates keys" "$KEYS/salt-$CURRENT_YEAR"

OUT=$(run_wrapper -C "$REPO" commit --allow-empty -m --regen 2>&1); RC=$?
assert_rc "commit -m --regen works without wrapper" 0 "$RC"
assert_eq "literal --regen kept as message" "--regen" "$(vgit -C "$REPO" log -1 --format=%s)"

new_env verbose_after
OUT=$(run_wrapper --wrapper -C "$REPO" commit --allow-empty --verbose -m va 2>&1); RC=$?
assert_rc "commit --verbose after subcommand works" 0 "$RC"
assert_not_contains "post-subcommand --verbose not consumed by wrapper" "git-rtz:" "$OUT"

new_env bareflags
OUT=$(run_wrapper --regen 2>&1); RC=$?
assert_ne "bare --regen fails in real git" 0 "$RC"
assert_empty_dir "bare --regen creates no keys" "$KEYS"
OUT=$(run_wrapper --verbose 2>&1); RC=$?
assert_ne "bare --verbose fails in real git" 0 "$RC"
assert_empty_dir "bare --verbose creates no keys" "$KEYS"

new_env bareflags_commit
OUT=$(run_wrapper --regen commit --allow-empty -m nope 2>&1); RC=$?
assert_ne "bare --regen with commit fails in real git" 0 "$RC"
assert_empty_dir "bare --regen with commit creates no keys" "$KEYS"
OUT=$(run_wrapper --verbose commit --allow-empty -m nope 2>&1); RC=$?
assert_ne "bare --verbose with commit fails in real git" 0 "$RC"
assert_empty_dir "bare --verbose with commit creates no keys" "$KEYS"

new_env nontz
OUT=$(run_wrapper --wrapper -C "$REPO" status 2>&1); RC=$?
assert_rc "--wrapper status works" 0 "$RC"
assert_empty_dir "status creates no keys" "$KEYS"
OUT=$(run_wrapper --wrapper --version 2>&1); RC=$?
assert_rc "--wrapper --version works" 0 "$RC"
assert_contains "--version output" "git version" "$OUT"
assert_empty_dir "--version creates no keys" "$KEYS"
OUT=$(run_wrapper --wrapper --verbose -C "$REPO" status 2>&1); RC=$?
assert_rc "--wrapper --verbose status works" 0 "$RC"
assert_contains "verbose status logs fast path" "does not need a time zone" "$OUT"

new_env regen
OUT=$(run_wrapper --wrapper --regen 2>&1); RC=$?
assert_rc "--regen exits 0" 0 "$RC"
assert_contains "--regen message" "regenerated salt and segment schedule" "$OUT"
assert_file "salt exists" "$KEYS/salt-$CURRENT_YEAR"
assert_file "segments exist" "$KEYS/segments-$CURRENT_YEAR"
assert_file "state exists" "$CACHE_DIR/state-$CURRENT_YEAR"

BEFORE=$(<"$KEYS/salt-$CURRENT_YEAR")
OUT=$(run_wrapper --wrapper --regen 2>&1); RC=$?
AFTER=$(<"$KEYS/salt-$CURRENT_YEAR")
assert_rc "second --regen exits 0" 0 "$RC"
assert_ne "--regen changes salt" "$BEFORE" "$AFTER"

SALT=$(<"$KEYS/salt-$CURRENT_YEAR")
HASH=$(printf '%s' "$SALT" | sha256sum | cut -d' ' -f1)
HEADER=$(head -1 "$KEYS/segments-$CURRENT_YEAR")
assert_eq "segments header matches salt" "#salt=$HASH" "$HEADER"
assert_eq "salt mode" "600" "$(stat -c %a "$KEYS/salt-$CURRENT_YEAR")"
assert_eq "segments mode" "600" "$(stat -c %a "$KEYS/segments-$CURRENT_YEAR")"
assert_eq "keys dir mode" "700" "$(stat -c %a "$KEYS")"
assert_eq "cache dir mode" "700" "$(stat -c %a "$CACHE_DIR")"
assert_no_temp "no temp files after regen" "$KEYS"

new_env segments_default
OUT=$(run_wrapper --wrapper --regen 2>&1); RC=$?
assert_rc "default segments regen" 0 "$RC"
DEFAULT_SEGMENTS=$(( $(wc -l < "$KEYS/segments-$CURRENT_YEAR") - 1 ))
if (( DEFAULT_SEGMENTS >= 6 && DEFAULT_SEGMENTS <= 9 )); then
    pass "default segment count is 6..9"
else
    fail "default segment count is 6..9" "got $DEFAULT_SEGMENTS"
fi

new_env segments_cli
OUT=$(run_wrapper --wrapper --regen --segments 4 2>&1); RC=$?
assert_rc "segments CLI regen" 0 "$RC"
assert_segment_count "segments CLI count" 4 "$KEYS/segments-$CURRENT_YEAR"
assert_not_contains "segments CLI no warning at 4" "more than 10" "$OUT"

new_env segments_env
OUT=$(TEST_SEGMENTS=5 run_wrapper --wrapper --regen 2>&1); RC=$?
assert_rc "segments env regen" 0 "$RC"
assert_segment_count "segments env count" 5 "$KEYS/segments-$CURRENT_YEAR"

new_env segments_override
OUT=$(TEST_SEGMENTS=5 run_wrapper --wrapper --regen --segments=7 2>&1); RC=$?
assert_rc "segments CLI overrides env" 0 "$RC"
assert_segment_count "segments CLI override count" 7 "$KEYS/segments-$CURRENT_YEAR"

new_env segments_large
OUT=$(run_wrapper --wrapper --regen --segments 11 2>&1); RC=$?
assert_rc "large segment count is allowed" 0 "$RC"
assert_segment_count "large segment count applied" 11 "$KEYS/segments-$CURRENT_YEAR"
assert_contains "large segment warning" "more than 10 segments" "$OUT"

new_env segments_invalid
OUT=$(run_wrapper --wrapper --regen --segments 0 2>&1); RC=$?
assert_ne "zero segments fails" 0 "$RC"
assert_contains "zero segments message" "positive integer" "$OUT"
assert_empty_dir "zero segments creates no keys" "$KEYS"
OUT=$(run_wrapper --wrapper --regen --segments abc 2>&1); RC=$?
assert_ne "non-numeric segments fails" 0 "$RC"
assert_contains "non-numeric segments message" "positive integer" "$OUT"
assert_empty_dir "non-numeric segments creates no keys" "$KEYS"
OUT=$(run_wrapper --wrapper --regen --segments 2>&1); RC=$?
assert_ne "missing segment value fails" 0 "$RC"
assert_contains "missing segment value message" "positive integer" "$OUT"
assert_empty_dir "missing segment value creates no keys" "$KEYS"

new_env segments_env_invalid
OUT=$(TEST_SEGMENTS=0 run_wrapper --wrapper --regen 2>&1); RC=$?
assert_ne "invalid segment env fails" 0 "$RC"
assert_contains "invalid segment env message" "GIT_RANDOM_TZ_SEGMENTS" "$OUT"
assert_empty_dir "invalid segment env creates no keys" "$KEYS"

new_env segments_bare
OUT=$(run_wrapper --segments 4 -C "$REPO" commit --allow-empty -m nope 2>&1); RC=$?
assert_ne "bare --segments fails in real git" 0 "$RC"
assert_empty_dir "bare --segments creates no keys" "$KEYS"

new_env segments_existing
OUT=$(run_wrapper --wrapper --regen --segments 4 2>&1); RC=$?
assert_rc "existing schedule setup" 0 "$RC"
OUT=$(run_wrapper --wrapper --segments 7 -C "$REPO" commit --allow-empty -m existing 2>&1); RC=$?
assert_rc "segments without regen commit works" 0 "$RC"
assert_segment_count "segments without regen keeps schedule" 4 "$KEYS/segments-$CURRENT_YEAR"

new_env verbose
OUT=$(run_wrapper --wrapper --verbose --regen 2>&1); RC=$?
assert_rc "verbose --regen exits 0" 0 "$RC"
assert_contains "verbose logs are prefixed" "git-rtz:" "$OUT"
assert_contains "verbose mentions segments/zones" "segment" "$OUT"
SALT=$(<"$KEYS/salt-$CURRENT_YEAR")
assert_not_contains "verbose does not print salt" "$SALT" "$OUT"
assert_not_contains "verbose does not print salt hash" "salt sha256=" "$OUT"

new_env verbose_commit
OUT=$(run_wrapper --wrapper --verbose -C "$REPO" commit --allow-empty -m verbose-commit 2>&1); RC=$?
assert_rc "verbose commit exits 0" 0 "$RC"
assert_contains "verbose commit logs selected zone" "selected zone=" "$OUT"
assert_contains "verbose commit logs exec" "exec " "$OUT"
SALT=$(<"$KEYS/salt-$CURRENT_YEAR")
assert_not_contains "verbose commit does not print salt" "$SALT" "$OUT"
assert_not_contains "verbose commit does not print salt hash" "salt sha256=" "$OUT"

new_env verbose_state
OUT=$(run_wrapper --wrapper --regen 2>&1); RC=$?
assert_rc "verbose state setup" 0 "$RC"
OUT=$(run_wrapper --wrapper --verbose 2>&1); RC=$?
assert_rc "verbose state dump exits 0" 0 "$RC"
assert_contains "verbose state dump flags" "wrapper=1 regen=0 verbose=1" "$OUT"
assert_contains "verbose state dump empty subcommand" "subcommand=''" "$OUT"
assert_contains "verbose state dump state flags" "state_exists=1 salt_exists=1 seg_exists=1" "$OUT"
assert_contains "verbose state dump zone tab" "zone tab=" "$OUT"
assert_contains "verbose state dump zone count" "zones=" "$OUT"
assert_contains "verbose state dump segment count" "n_segments=" "$OUT"
assert_contains "verbose state dump first segment" "segment 0:" "$OUT"
assert_not_contains "verbose state dump does not exec git" "exec " "$OUT"
assert_not_contains "verbose state dump does not show help" "Usage: git --wrapper" "$OUT"

new_env verbose_state_empty
OUT=$(run_wrapper --wrapper --verbose 2>&1); RC=$?
assert_rc "verbose empty state dump exits 0" 0 "$RC"
assert_contains "verbose empty state dump state flags" "state_exists=0 salt_exists=0 seg_exists=0" "$OUT"
assert_contains "verbose empty state dump hint" "no complete schedule" "$OUT"
assert_empty_dir "verbose empty state dump creates no keys" "$KEYS"

new_env years
OUT=$(TEST_YEAR=abc run_wrapper --wrapper --regen 2>&1); RC=$?
assert_ne "malformed YEAR fails" 0 "$RC"
assert_contains "malformed YEAR message" "four-digit" "$OUT"

OUT=$(TEST_YEAR=$((CURRENT_YEAR - 1)) run_wrapper --wrapper --regen 2>&1); RC=$?
assert_ne "past YEAR fails" 0 "$RC"
assert_contains "past YEAR message" "past" "$OUT"

OUT=$(TEST_YEAR=$((CURRENT_YEAR + 1)) run_wrapper --wrapper --regen 2>&1); RC=$?
assert_ne "future YEAR fails" 0 "$RC"
assert_contains "future YEAR message" "future" "$OUT"
assert_empty_dir "invalid YEARs create no keys" "$KEYS"

new_env fbe
mkdir -p "$CACHE_DIR"
: > "$CACHE_DIR/state-$CURRENT_YEAR"
OUT=$(run_wrapper --wrapper --regen 2>&1); RC=$?
assert_ne "--regen refuses missing keys with existing state" 0 "$RC"
assert_contains "FBE hint shown" "FBE" "$OUT"
assert_no_file "FBE guard creates no salt" "$KEYS/salt-$CURRENT_YEAR"
assert_no_file "FBE guard creates no segments" "$KEYS/segments-$CURRENT_YEAR"

new_env partial
mkdir -p "$CACHE_DIR"
: > "$CACHE_DIR/state-$CURRENT_YEAR"
printf '%064d' 7 > "$KEYS/salt-$CURRENT_YEAR"
OUT=$(run_wrapper --wrapper --regen 2>&1); RC=$?
assert_rc "--regen repairs partial state" 0 "$RC"
SALT=$(<"$KEYS/salt-$CURRENT_YEAR")
HASH=$(printf '%s' "$SALT" | sha256sum | cut -d' ' -f1)
assert_eq "partial regen header matches" "#salt=$HASH" "$(head -1 "$KEYS/segments-$CURRENT_YEAR")"

new_env tz
OUT=$(run_wrapper --wrapper --regen 2>&1); RC=$?
assert_rc "TZ setup regen" 0 "$RC"
awk 'NR == 1 { print; next } { print $1, $2, "Asia/Tokyo" }' \
    "$KEYS/segments-$CURRENT_YEAR" > "$KEYS/segments.test.tmp"
mv -f "$KEYS/segments.test.tmp" "$KEYS/segments-$CURRENT_YEAR"

OUT=$(run_wrapper --wrapper -C "$REPO" commit --allow-empty -m wrapper-tz 2>&1); RC=$?
assert_rc "wrapper commit works" 0 "$RC"
OFFSET=$(vgit -C "$REPO" log -1 --format=%cd --date=format:%z)
assert_eq "wrapper commit uses forced zone" "+0900" "$OFFSET"

OUT=$(run_wrapper -C "$REPO" commit --allow-empty -m plain-tz 2>&1); RC=$?
assert_rc "plain commit works with forced segments" 0 "$RC"
OFFSET=$(vgit -C "$REPO" log -1 --format=%cd --date=format:%z)
assert_eq "plain commit uses forced zone" "+0900" "$OFFSET"

new_env regen_status
OUT=$(run_wrapper --wrapper --regen -C "$REPO" status 2>&1); RC=$?
assert_rc "--regen status exits 0" 0 "$RC"
assert_file "--regen status creates salt" "$KEYS/salt-$CURRENT_YEAR"
assert_file "--regen status creates state" "$CACHE_DIR/state-$CURRENT_YEAR"

new_env regen_commit
OUT=$(run_wrapper --wrapper --regen -C "$REPO" commit --allow-empty -m regen-commit 2>&1); RC=$?
assert_rc "--regen commit exits 0" 0 "$RC"
assert_eq "--regen commit subject" "regen-commit" "$(vgit -C "$REPO" log -1 --format=%s)"
assert_file "--regen commit creates salt" "$KEYS/salt-$CURRENT_YEAR"

new_env forms
OUT=$(run_wrapper -C "$REPO" --wrapper commit --allow-empty -m form1 2>&1); RC=$?
assert_rc "--wrapper after -C works" 0 "$RC"
OUT=$(run_wrapper --wrapper -C "$REPO" commit --allow-empty -m form2 2>&1); RC=$?
assert_rc "--wrapper before -C works" 0 "$RC"
assert_eq "both forms committed" "2" "$(vgit -C "$REPO" rev-list --count HEAD)"

new_env dashc
mkdir -p "$ENV_ROOT/tmp/--wrapper"
vgit init -q "$ENV_ROOT/tmp/--wrapper"
vgit -C "$ENV_ROOT/tmp/--wrapper" config user.name Test
vgit -C "$ENV_ROOT/tmp/--wrapper" config user.email test@example.com
OUT=$(cd "$ENV_ROOT/tmp" && run_wrapper -C --wrapper commit --allow-empty -m dashc 2>&1); RC=$?
assert_rc "-C value named --wrapper works" 0 "$RC"
assert_eq "commit made in --wrapper dir" "dashc" "$(vgit -C "$ENV_ROOT/tmp/--wrapper" log -1 --format=%s)"
assert_file "-C value named --wrapper commit creates keys" "$KEYS/salt-$CURRENT_YEAR"

new_env conc
pids=()
for i in 1 2 3; do
    run_wrapper --wrapper --regen > "$ENV_ROOT/regen-$i.log" 2>&1 &
    pids+=("$!")
done
CONC_FAIL=0
for pid in "${pids[@]}"; do
    wait "$pid" || CONC_FAIL=1
done
assert_eq "concurrent --regen all succeed" "0" "$CONC_FAIL"
SALT=$(<"$KEYS/salt-$CURRENT_YEAR")
HASH=$(printf '%s' "$SALT" | sha256sum | cut -d' ' -f1)
assert_eq "concurrent regen header matches" "#salt=$HASH" "$(head -1 "$KEYS/segments-$CURRENT_YEAR")"
assert_no_temp "concurrent regen leaves no temp files" "$KEYS"

new_env mismatch
OUT=$(run_wrapper --wrapper --regen 2>&1); RC=$?
assert_rc "mismatch setup regen" 0 "$RC"
printf '%064d' 9 > "$KEYS/salt-$CURRENT_YEAR"
OUT=$(run_wrapper --wrapper -C "$REPO" commit --allow-empty -m mismatch 2>&1); RC=$?
assert_ne "salt mismatch fails" 0 "$RC"
assert_contains "salt mismatch message" "does not match" "$OUT"

OUT=$(run_wrapper --wrapper --regen 2>&1); RC=$?
assert_rc "--regen repairs salt mismatch" 0 "$RC"
SALT=$(<"$KEYS/salt-$CURRENT_YEAR")
HASH=$(printf '%s' "$SALT" | sha256sum | cut -d' ' -f1)
assert_eq "repaired header matches" "#salt=$HASH" "$(head -1 "$KEYS/segments-$CURRENT_YEAR")"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if (( FAIL > 0 )); then
    printf 'test root kept: %s\n' "$TEST_ROOT"
    exit 1
fi
rm -rf "$TEST_ROOT"
exit 0
