# Tests

Two suites:

| File | Covers |
|---|---|
| `tests/test.sh` | functional tests for the `git` (git-rtz) wrapper |
| `tests/test_rewrite_secret_history.py` | unit and integration tests for `rewrite_secret_history.py` |

## Running

```bash
bash tests/test.sh
python3 -m pytest tests/test_rewrite_secret_history.py -v
```

`tests/test.sh` needs Linux, bash, git, coreutils, util-linux (`flock`), openssl and tzdata, and no root. The Python suite needs Python 3.9+, pytest and `git-filter-repo`; unit tests run without `git-filter-repo`, integration tests fail without it.

## Design

- `tests/test.sh` uses a small `assert_*` helper set and does **not** enable `set -e`, so one failed assertion does not hide the rest; it prints a `N passed, M failed` summary and exits non-zero on any failure.
- Each scenario runs in its own throwaway tree (`$TMPDIR/git-rtz-test.XXXXXX/<name>`) with isolated `HOME`/XDG and a `vgit` helper that resolves the real git binary, so the tests never read the caller's git config or touch the real `~/keys`/`~/.cache`. The tree is removed on success and kept on failure.
- The Python integration tests build temporary repositories and run `git-filter-repo --force`. Deletion-only rewrites are out of scope — use plain `git-filter-repo` for that.

## CI

`.github/workflows/ci.yml` runs when the two scripts, `tests/**` or the workflow change: `shellcheck` on the wrapper and `tests/test.sh`, `bash tests/test.sh`, and the pytest suite (Python 3.14).
