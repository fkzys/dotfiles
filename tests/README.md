# Tests

## Overview

| File | Language | Framework | What it tests |
|------|----------|-----------|---------------|
| `tests/test.sh` | Bash | Custom assertions | Functional tests for `files/.local/bin/git` (the git-rtz wrapper): help and wrapper-only flags, TZ selection with and without `--wrapper`, literal flag preservation, `--regen`, `--segments`, segment-count validation, `--verbose`, YEAR validation, FBE safety, permissions, concurrent regeneration, and salt/segments mismatch. |
| `tests/test_rewrite_secret_history.py` | Python | pytest | Unit and integration tests for `files/.local/bin/rewrite_secret_history.py`: path matching, callback generation, argument parsing, `main()` orchestration, `git-filter-repo` failures, and real history rewrites that propagate existing target files into ancestors. |

## Running

```bash
bash tests/test.sh
```

The script resolves the repository root from its own location, so it can be run from any working directory. It requires Linux, bash, git, coreutils, util-linux (`flock`), openssl, and tzdata (`zone1970.tab` or `zone.tab`). No root privileges are required.

### Python tests

```bash
python3 -m pytest tests/test_rewrite_secret_history.py -v
```

Requires Python 3.9+, pytest, and `git-filter-repo` on `PATH`. Unit tests run without it; integration tests fail if `git-filter-repo` is unavailable. The integration tests create isolated temporary repositories and pass `--force` to `git-filter-repo`.

## How they work

### Harness

`tests/test.sh` uses a small custom assertion framework:

- `assert_rc`, `assert_eq`, `assert_ne` — exit status and string comparisons
- `assert_contains`, `assert_not_contains` — output checks
- `assert_file`, `assert_no_file`, `assert_empty_dir`, `assert_no_temp` — filesystem checks
- `pass` / `fail` — count results; the script exits non-zero if any test failed

The script is intentionally **not** run with `set -e`: a failed assertion must not
stop the remaining tests. It uses `set -uo pipefail` and reports the final
`N passed, M failed` summary.

### Isolation

Each scenario calls `new_env <name>` and gets a fresh directory tree under
`${TMPDIR:-/tmp}/git-rtz-test.XXXXXX/<name>`:

```text
<env>/home
<env>/config
<env>/keys
<env>/cache
<env>/repo
<env>/tmp
```

`run_wrapper` then runs `bash "$WRAPPER"` with:

- `HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME` pointed at the scenario
- `GIT_RANDOM_TZ_KEYS` pointed at the scenario's keys directory
- `GIT_RANDOM_TZ_SEGMENTS` set from `TEST_SEGMENTS` when provided
- `YEAR` set to the current UTC year (or `TEST_YEAR`)
- `TZ` set to `TEST_TZ` (default `UTC`)
- `GIT_CONFIG_NOSYSTEM=1` and Git date/config overrides unset

A separate `vgit` helper uses the same isolated home/config, so the tests never
read the user's global or system Git configuration. No files under the real
`~/keys` or `~/.cache` are touched.

On success the temporary root is removed. On failure it is kept and its path is
printed to make investigation easier.

### Test sections

1. **Help** — `--wrapper --help` and bare `--wrapper`; `--regen`, `--segments`, and `--verbose` documented.
2. **Plain commit TZ** — `git commit` without `--wrapper` still gets the schedule zone; `git status` stays a no-key fast path.
3. **Literal flags** — `git commit -m --wrapper` and `-m --regen` preserve the message; post-subcommand `--verbose` is not consumed.
4. **Wrapper-only flags without `--wrapper`** — `--regen`/`--segments`/`--verbose` go to real Git unchanged and create no keys, including before a commit.
5. **Non-TZ fast path** — status/version under `--wrapper` create no key material.
6. **`--regen`** — regenerates salt/segments, changes the salt, keeps the header in sync, enforces `0600`/`0700` modes, leaves no temp files.
7. **Segment count** — default is 6..9; `--segments` and `GIT_RANDOM_TZ_SEGMENTS` select the count; CLI overrides the environment; more than 10 is allowed but warns; invalid or missing values fail without creating keys.
8. **`--verbose`** — logs are prefixed with `git-rtz:`, show the selected zone, and never print the salt or its hash. With no subcommand, `--wrapper --verbose` prints the current state and selected zone, then exits without running Git; a missing schedule is reported without creating key material.
9. **YEAR validation** — malformed, past, and future years fail with clear messages and create no keys.
10. **FBE guard** — state without any key material refuses regeneration.
11. **Partial corruption** — state + salt without segments is repaired by `--regen`.
12. **TZ application** — every segment is forced to `Asia/Tokyo`; both wrapper and plain commits use `+0900`.
13. **`--wrapper` positions** — `-C repo --wrapper` and `--wrapper -C repo`.
14. **`-C` value named `--wrapper`** — the value is not stripped and the commit lands in the right repository.
15. **Concurrent `--regen`** — three simultaneous runs leave a consistent salt/header pair.
16. **Salt/segments mismatch** — a commit detects the mismatch; `--regen` repairs it.

### Wrapper under test

The test invokes the repository file directly:

```bash
bash "$REPO_ROOT/files/.local/bin/git" ...
```

It does not use an installed copy and does not require the executable bit. The
wrapper's own dependency checks and `flock` locking are exercised as part of the
scenarios.

## Python tests

`tests/test_rewrite_secret_history.py` covers the secret-history rewriter.

### Unit tests

- `in_scope` — exact paths, `*`/`**` globs, character classes, case sensitivity, and bytes paths.
- `build_callback` — the generated callback is valid Python, filters only ancestor commits, replaces scoped changes, emits `M` for target blobs and `D` for scoped history paths absent from the target, and handles quoted bytes.
- `parse_args` — defaults, multiple paths, `--force`, missing arguments, and help text.
- `main` — resolved commit, `ls-tree`/`log` parsing, scope filtering, non-blob rejection, the empty-target guard, temp callback creation and cleanup, `--force` placement, and propagation of git/`git-filter-repo` errors.

### Integration tests

These run `git-filter-repo` against temporary repositories and verify that
existing target files are written into every ancestor, including nested globs,
paths with spaces, and executable modes. They also verify that a target with no
matching file is rejected and the history is left untouched. Deletion-only
rewrites are intentionally out of scope: use plain `git-filter-repo` for
deletion.

## CI

`.github/workflows/ci.yml` runs on pushes and pull requests that touch
`files/.local/bin/git`, `files/.local/bin/rewrite_secret_history.py`, `tests/**`,
or the workflow file:

- **`shellcheck`** — strict `shellcheck -s bash` on the wrapper and the test
- **`test`** — `bash tests/test.sh`
- **`pytest`** — installs pytest and `git-filter-repo`, then runs the Python suite

The runner is `ubuntu-latest`. Shell tests use preinstalled Git, coreutils,
util-linux, openssl, shellcheck, and tzdata. The Python job sets up Python 3.14
and installs pytest plus `git-filter-repo`.

## Test environment

- Both suites resolve a real git binary explicitly (skipping wrapper scripts, including installed git-rtz copies) and sanitize `PATH`/`GIT_*` variables, so caller aliases, shims, `GIT_DIR`, and similar settings do not affect results
- Python integration tests use temporary git repositories with isolated `HOME`/XDG directories and fixed author/committer metadata
- The FBE case is simulated by creating `state-<year>` without salt/segments
- The TZ-override case rewrites the segment file to point every segment at `Asia/Tokyo`
- The concurrency case starts three `--regen` processes; `flock` makes the result deterministic

The test exits `2` early if the wrapper or tzdata files are missing, rather than
reporting a misleading assertion failure.
