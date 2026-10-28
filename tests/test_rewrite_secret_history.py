import importlib.util
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT_PATH = REPO_ROOT / "files" / ".local" / "bin" / "rewrite_secret_history.py"


def _find_real_git():
    wrapper = SCRIPT_PATH.resolve()
    for entry in os.environ.get("PATH", "").split(os.pathsep):
        if not entry:
            continue
        candidate = Path(entry) / "git"
        try:
            resolved = candidate.resolve()
        except OSError:
            continue
        if not candidate.is_file() or not os.access(candidate, os.X_OK):
            continue
        if resolved == wrapper:
            continue
        try:
            with candidate.open("rb") as handle:
                if handle.read(2) == b"#!":
                    continue
        except OSError:
            continue
        return str(resolved)
    raise RuntimeError(
        "real git binary not found in PATH (wrapper scripts are ignored)"
    )


def _build_test_path():
    real_git_dir = Path(REAL_GIT).parent.resolve()
    wrapper_dir = SCRIPT_PATH.parent.resolve()
    entries = []
    seen = set()
    for entry in os.environ.get("PATH", "").split(os.pathsep):
        if not entry:
            continue
        try:
            resolved = Path(entry).resolve()
        except OSError:
            resolved = Path(entry)
        if resolved == wrapper_dir or resolved in seen:
            continue
        seen.add(resolved)
        entries.append(entry)
    return os.pathsep.join([str(real_git_dir), *entries])


REAL_GIT = _find_real_git()
TEST_PATH = _build_test_path()
FILTER_REPO = shutil.which("git-filter-repo", path=TEST_PATH)


def _load_script():
    spec = importlib.util.spec_from_file_location(
        "rewrite_secret_history_under_test", SCRIPT_PATH
    )
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {SCRIPT_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


rsh = _load_script()


class FakeFileChange:
    def __init__(self, change_type, filename=None, blob_id=None, mode=None):
        self.change_type = change_type
        self.filename = filename
        self.blob_id = blob_id
        self.mode = mode


class FakeCommit:
    def __init__(self, original_id, file_changes=None):
        self.original_id = original_id
        self.file_changes = list(file_changes or [])


def _run_callback(callback, commit):
    namespace = {"commit": commit, "FileChange": FakeFileChange}
    exec(compile(callback, "<commit-callback>", "exec"), namespace)
    return commit.file_changes


class FakeGit:
    def __init__(self, responses):
        self.responses = responses
        self.calls = []

    def __call__(self, *args):
        self.calls.append(args)
        try:
            value = self.responses[args]
        except KeyError as exc:
            raise AssertionError(f"unexpected git call: {args!r}") from exc
        if isinstance(value, BaseException):
            raise value
        return value


class RunCapture:
    def __init__(self, error=None):
        self.error = error
        self.commands = []
        self.callback_paths = []
        self.callback_texts = []
        self.check_values = []

    def __call__(self, command, check=None):
        self.commands.append(list(command))
        self.check_values.append(check)
        callback_path = Path(command[-1])
        self.callback_paths.append(callback_path)
        self.callback_texts.append(callback_path.read_text(encoding="utf-8"))
        if self.error is not None:
            raise self.error
        return subprocess.CompletedProcess(command, 0)


@pytest.fixture
def main_env(monkeypatch, tmp_path):
    monkeypatch.setattr(rsh.tempfile, "tempdir", str(tmp_path))

    def _setup(
        *,
        tree=b"",
        history=b"",
        ancestors=b"p1\np2\n",
        target=b"deadbeef\n",
        argv=("HEAD", "secrets/**"),
        run_error=None,
    ):
        resolved = target.decode().strip()
        fake_git = FakeGit(
            {
                ("rev-parse", "--verify", f"{argv[0]}^{{commit}}"): target,
                ("rev-list", f"{resolved}^@"): ancestors,
                ("ls-tree", "-r", "-z", "--full-tree", resolved): tree,
                (
                    "log",
                    "--format=",
                    "-z",
                    "--name-only",
                    "--no-renames",
                    resolved,
                ): history,
            }
        )
        run = RunCapture(run_error)
        monkeypatch.setattr(rsh, "git", fake_git)
        monkeypatch.setattr(rsh.subprocess, "run", run)
        monkeypatch.setattr(sys, "argv", ["rewrite_secret_history.py", *argv])
        return fake_git, run

    return _setup


class TestInScope:
    @pytest.mark.parametrize(
        ("path", "patterns", "expected"),
        [
            ("secrets/a.txt", ["secrets/a.txt"], True),
            ("secrets/a.txt", ["secrets/*"], True),
            ("secrets/sub/a.txt", ["secrets/**"], True),
            ("config/secrets/a.txt", ["**/secrets/**"], True),
            ("config/secrets/a.txt", ["secrets/**"], False),
            ("secrets/a.txt", ["**/secrets/**"], False),
            ("Secrets/a.txt", ["secrets/**"], False),
            ("config/api.key", ["*.key"], True),
            ("config/sub/api.key", ["config/*.key"], True),
            ("secrets/a.txt", ["*.key"], False),
            ("config/api1.key", ["config/api[0-9].key"], True),
            ("config/api.key", ["config/???.key"], True),
            ("secrets/a.txt", [], False),
            ("secrets/a.txt", ["other/*", "secrets/*"], True),
            (b"secrets/a.txt", ["secrets/*"], True),
        ],
    )
    def test_in_scope(self, path, patterns, expected):
        assert rsh.in_scope(path, patterns) is expected


class TestBuildCallback:
    def test_non_ancestor_is_not_modified(self):
        existing = FakeFileChange(b"M", b"secret.txt", b"old", b"100644")
        commit = FakeCommit(b"self", [existing])

        callback = rsh.build_callback(
            {b"other"},
            {b"secret.txt": (b"new", b"100644")},
            {b"secret.txt"},
        )

        assert _run_callback(callback, commit) == [existing]

    def test_ancestor_replaces_existing_changes_and_adds_target_state(self):
        existing_present = FakeFileChange(b"M", b"present.txt", b"old", b"100644")
        existing_other = FakeFileChange(b"M", b"other.txt", b"other", b"100644")
        commit = FakeCommit(b"ancestor", [existing_present, existing_other])

        callback = rsh.build_callback(
            {b"ancestor"},
            {b"present.txt": (b"newblob", b"100755")},
            {b"present.txt", b"deleted.txt"},
        )
        changes = _run_callback(callback, commit)

        assert len(changes) == 3
        assert changes[0] is existing_other
        assert changes[1].change_type == b"D"
        assert changes[1].filename == b"deleted.txt"
        assert changes[2].change_type == b"M"
        assert changes[2].filename == b"present.txt"
        assert changes[2].blob_id == b"newblob"
        assert changes[2].mode == b"100755"

    def test_callback_sorts_paths(self):
        callback = rsh.build_callback(
            {b"ancestor"},
            {},
            {b"z.txt", b"a.txt", b"m.txt"},
        )
        changes = _run_callback(callback, FakeCommit(b"ancestor", []))

        assert [change.filename for change in changes] == [
            b"a.txt",
            b"m.txt",
            b"z.txt",
        ]

    def test_callback_with_no_paths_keeps_existing_changes(self):
        existing = FakeFileChange(b"M", b"other.txt", b"other", b"100644")
        callback = rsh.build_callback({b"ancestor"}, {}, set())
        changes = _run_callback(callback, FakeCommit(b"ancestor", [existing]))

        assert changes == [existing]

    def test_callback_handles_quoted_bytes_safely(self):
        weird = b"weird'\"\\\n.txt"
        callback = rsh.build_callback({b"ancestor"}, {}, {weird})
        changes = _run_callback(callback, FakeCommit(b"ancestor", []))

        assert len(changes) == 1
        assert changes[0].change_type == b"D"
        assert changes[0].filename == weird


class TestParseArgs:
    def test_defaults(self, monkeypatch):
        monkeypatch.setattr(sys, "argv", ["prog", "HEAD", "secrets/**"])

        args = rsh.parse_args()

        assert args.commit == "HEAD"
        assert args.paths == ["secrets/**"]
        assert args.force is False

    def test_multiple_paths_and_force(self, monkeypatch):
        monkeypatch.setattr(
            sys,
            "argv",
            ["prog", "HEAD~3", "secrets/**", "**/secrets/**", "--force"],
        )

        args = rsh.parse_args()

        assert args.commit == "HEAD~3"
        assert args.paths == ["secrets/**", "**/secrets/**"]
        assert args.force is True

    def test_force_can_precede_positionals(self, monkeypatch):
        monkeypatch.setattr(sys, "argv", ["prog", "--force", "HEAD", "file.txt"])

        args = rsh.parse_args()

        assert args.commit == "HEAD"
        assert args.paths == ["file.txt"]
        assert args.force is True

    @pytest.mark.parametrize(
        "argv",
        [
            ["prog"],
            ["prog", "HEAD"],
        ],
    )
    def test_missing_arguments_exit_with_usage_error(self, monkeypatch, argv):
        monkeypatch.setattr(sys, "argv", argv)

        with pytest.raises(SystemExit) as exc_info:
            rsh.parse_args()

        assert exc_info.value.code == 2

    def test_help_exits_zero_and_shows_examples(self, monkeypatch, capsys):
        monkeypatch.setattr(sys, "argv", ["prog", "--help"])

        with pytest.raises(SystemExit) as exc_info:
            rsh.parse_args()

        assert exc_info.value.code == 0
        output = capsys.readouterr().out
        assert "examples:" in output
        assert "rewrite_secret_history.py fcf3bc4" in output


class TestMain:
    def test_rewrites_existing_target_files_and_cleans_callback(self, main_env):
        fake_git, run = main_env(
            tree=b"100644 blob aaa\tsecrets/a.txt\0",
            history=b"secrets/a.txt\0keep.txt\0",
        )

        rsh.main()

        assert fake_git.calls == [
            ("rev-parse", "--verify", "HEAD^{commit}"),
            ("rev-list", "deadbeef^@"),
            ("ls-tree", "-r", "-z", "--full-tree", "deadbeef"),
            (
                "log",
                "--format=",
                "-z",
                "--name-only",
                "--no-renames",
                "deadbeef",
            ),
        ]
        assert len(run.commands) == 1
        assert run.check_values == [True]
        command = run.commands[0]
        assert command[:2] == ["git-filter-repo", "--commit-callback"]
        assert not Path(run.callback_paths[0]).exists()

        callback_text = run.callback_texts[0]
        assert (
            "target_blobs = {b'secrets/a.txt': (b'aaa', b'100644')}"
            in callback_text
        )
        assert "b'secrets/a.txt'" in callback_text
        assert "b'keep.txt'" not in callback_text
        assert "b'p1'" in callback_text
        assert "b'p2'" in callback_text

    def test_force_is_inserted_before_commit_callback(self, main_env):
        _, run = main_env(
            tree=b"100644 blob aaa\tsecrets/a.txt\0",
            history=b"secrets/a.txt\0",
            argv=("HEAD", "secrets/**", "--force"),
        )

        rsh.main()

        assert run.commands[0] == [
            "git-filter-repo",
            "--force",
            "--commit-callback",
            str(run.callback_paths[0]),
        ]

    def test_target_path_only_is_rewritten(self, main_env):
        _, run = main_env(
            tree=b"100644 blob aaa\tsecrets/a.txt\0",
            history=b"",
        )

        rsh.main()

        assert "b'secrets/a.txt'" in run.callback_texts[0]
        assert len(run.commands) == 1

    def test_no_matching_target_files_errors_even_if_history_matches(self, main_env):
        _, run = main_env(
            tree=b"",
            history=b"secrets/a.txt\0",
            argv=("HEAD", "secrets/**"),
        )

        with pytest.raises(SystemExit) as exc_info:
            rsh.main()

        assert "No files matching" in str(exc_info.value)
        assert run.commands == []

    def test_non_blob_in_scope_errors(self, main_env):
        _, run = main_env(
            tree=b"160000 commit deadbeef\tvendor/lib\0",
            history=b"",
            argv=("HEAD", "vendor/**"),
        )

        with pytest.raises(SystemExit) as exc_info:
            rsh.main()

        assert "Unexpected object type" in str(exc_info.value)
        assert run.commands == []

    def test_out_of_scope_non_blob_is_ignored(self, main_env):
        _, run = main_env(
            tree=(
                b"100644 blob aaa\tsecrets/a.txt\0"
                b"160000 commit deadbeef\tvendor/lib\0"
            ),
            history=b"secrets/a.txt\0",
        )

        rsh.main()

        callback_text = run.callback_texts[0]
        assert "b'secrets/a.txt'" in callback_text
        assert "vendor/lib" not in callback_text

    def test_scope_filters_tree_and_history(self, main_env):
        _, run = main_env(
            tree=(
                b"100644 blob aaa\tsecrets/a.txt\0"
                b"100644 blob bbb\tkeep.txt\0"
            ),
            history=b"secrets/a.txt\0keep.txt\0",
        )

        rsh.main()

        callback_text = run.callback_texts[0]
        assert "b'secrets/a.txt'" in callback_text
        assert "b'keep.txt'" not in callback_text

    @pytest.mark.parametrize(
        "error",
        [
            subprocess.CalledProcessError(1, ["git-filter-repo"]),
            FileNotFoundError("git-filter-repo"),
        ],
    )
    def test_filter_repo_failure_still_cleans_callback(self, main_env, error):
        _, run = main_env(
            tree=b"100644 blob aaa\tsecrets/a.txt\0",
            history=b"secrets/a.txt\0",
            run_error=error,
        )

        with pytest.raises(type(error)):
            rsh.main()

        assert len(run.callback_paths) == 1
        assert not run.callback_paths[0].exists()

    def test_git_error_propagates(self, monkeypatch):
        error = subprocess.CalledProcessError(1, ["git", "rev-parse"])
        fake_git = FakeGit(
            {("rev-parse", "--verify", "HEAD^{commit}"): error}
        )
        run = RunCapture()
        monkeypatch.setattr(rsh, "git", fake_git)
        monkeypatch.setattr(rsh.subprocess, "run", run)
        monkeypatch.setattr(sys, "argv", ["prog", "HEAD", "secret.txt"])

        with pytest.raises(subprocess.CalledProcessError):
            rsh.main()

        assert fake_git.calls == [("rev-parse", "--verify", "HEAD^{commit}")]
        assert run.commands == []


class GitRepo:
    def __init__(self, root):
        self.root = root
        self.repo = root / "repo"
        self.repo.mkdir()
        self.home = root / "home"
        self.home.mkdir()
        self.config_home = root / "config"
        self.config_home.mkdir()
        self.cache_home = root / "cache"
        self.cache_home.mkdir()
        self.tmp = root / "tmp"
        self.tmp.mkdir()

        self.env = {
            key: value
            for key, value in os.environ.items()
            if not key.startswith("GIT_")
        }
        self.env.update(
            {
                "PATH": TEST_PATH,
                "HOME": str(self.home),
                "XDG_CONFIG_HOME": str(self.config_home),
                "XDG_CACHE_HOME": str(self.cache_home),
                "TMPDIR": str(self.tmp),
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_AUTHOR_NAME": "Test",
                "GIT_AUTHOR_EMAIL": "test@example.com",
                "GIT_COMMITTER_NAME": "Test",
                "GIT_COMMITTER_EMAIL": "test@example.com",
                "GIT_AUTHOR_DATE": "2020-01-01T00:00:00+0000",
                "GIT_COMMITTER_DATE": "2020-01-01T00:00:00+0000",
                "GIT_TERMINAL_PROMPT": "0",
                "GCM_INTERACTIVE": "never",
                "GIT_PAGER": "cat",
                "PAGER": "cat",
            }
        )

        self.git("init", "-q")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.com")

    def git(self, *args, check=True):
        return subprocess.run(
            [REAL_GIT, *args],
            cwd=self.repo,
            env=self.env,
            check=check,
            capture_output=True,
            text=True,
        )

    def write(self, path, content):
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        return target

    def remove(self, path):
        (self.repo / path).unlink()

    def commit_all(self, message):
        self.git("add", "-A")
        self.git("commit", "-qm", message)

    def run_script(self, *args, check=True):
        return subprocess.run(
            [sys.executable, str(SCRIPT_PATH), *args],
            cwd=self.repo,
            env=self.env,
            check=check,
            capture_output=True,
            text=True,
        )

    def commits(self):
        return self.git("rev-list", "--reverse", "HEAD").stdout.split()

    def blob(self, sha, path):
        return self.git("cat-file", "-p", f"{sha}:{path}").stdout

    def has_path(self, sha, path):
        result = self.git("cat-file", "-e", f"{sha}:{path}", check=False)
        return result.returncode == 0

    def mode(self, sha, path):
        line = self.git("ls-tree", sha, "--", path).stdout.strip()
        assert line, f"{path!r} is not present in {sha}"
        return line.split()[0]


def _require_filter_repo():
    if FILTER_REPO is None:
        pytest.fail(
            "git-filter-repo not found in test PATH; install it with "
            "`python3 -m pip install git-filter-repo`"
        )


@pytest.fixture
def repo(tmp_path):
    return GitRepo(tmp_path)


class TestIntegration:
    def test_propagates_existing_target_file_to_ancestors(self, repo):
        _require_filter_repo()
        repo.write("api.key", "old\n")
        repo.write("notes.txt", "A\n")
        repo.commit_all("A")

        repo.write("api.key", "new\n")
        repo.write("notes.txt", "B\n")
        repo.commit_all("B")

        repo.run_script("HEAD", "api.key", "--force")

        commits = repo.commits()
        assert len(commits) == 2
        assert repo.blob(commits[0], "api.key") == "new\n"
        assert repo.blob(commits[1], "api.key") == "new\n"
        assert repo.blob(commits[0], "notes.txt") == "A\n"
        assert repo.blob(commits[1], "notes.txt") == "B\n"

    def test_propagates_nested_glob_to_ancestors(self, repo):
        _require_filter_repo()
        repo.write("secrets/a.txt", "old-a\n")
        repo.write("config/secrets/b.txt", "old-b\n")
        repo.write("notes.txt", "A\n")
        repo.commit_all("A")

        repo.write("secrets/a.txt", "new-a\n")
        repo.write("config/secrets/b.txt", "new-b\n")
        repo.write("notes.txt", "B\n")
        repo.commit_all("B")

        repo.run_script(
            "HEAD",
            "secrets/**",
            "**/secrets/**",
            "--force",
        )

        commits = repo.commits()
        assert len(commits) == 2
        assert repo.blob(commits[0], "secrets/a.txt") == "new-a\n"
        assert repo.blob(commits[1], "secrets/a.txt") == "new-a\n"
        assert repo.blob(commits[0], "config/secrets/b.txt") == "new-b\n"
        assert repo.blob(commits[1], "config/secrets/b.txt") == "new-b\n"
        assert repo.blob(commits[0], "notes.txt") == "A\n"
        assert repo.blob(commits[1], "notes.txt") == "B\n"

    def test_propagates_path_with_spaces(self, repo):
        _require_filter_repo()
        repo.write("secrets/with space.txt", "old\n")
        repo.write("notes.txt", "A\n")
        repo.commit_all("A")

        repo.write("secrets/with space.txt", "new\n")
        repo.write("notes.txt", "B\n")
        repo.commit_all("B")

        repo.run_script("HEAD", "secrets/*", "--force")

        commits = repo.commits()
        assert len(commits) == 2
        assert repo.blob(commits[0], "secrets/with space.txt") == "new\n"
        assert repo.blob(commits[1], "secrets/with space.txt") == "new\n"

    def test_propagates_executable_mode(self, repo):
        _require_filter_repo()
        path = repo.write("secrets/tool.sh", "old\n")
        path.chmod(0o755)
        repo.write("notes.txt", "A\n")
        repo.commit_all("A")

        path.write_text("new\n", encoding="utf-8")
        path.chmod(0o755)
        repo.write("notes.txt", "B\n")
        repo.commit_all("B")

        repo.run_script("HEAD", "secrets/*", "--force")

        commits = repo.commits()
        assert len(commits) == 2
        assert repo.blob(commits[0], "secrets/tool.sh") == "new\n"
        assert repo.blob(commits[1], "secrets/tool.sh") == "new\n"
        assert repo.mode(commits[0], "secrets/tool.sh") == "100755"
        assert repo.mode(commits[1], "secrets/tool.sh") == "100755"

    def test_deleted_target_file_is_rejected_without_rewriting(self, repo):
        _require_filter_repo()
        repo.write("secret.txt", "secret\n")
        repo.write("notes.txt", "A\n")
        repo.commit_all("A")

        repo.write("notes.txt", "B\n")
        repo.commit_all("B")

        repo.remove("secret.txt")
        repo.write("notes.txt", "C\n")
        repo.commit_all("C")

        before = repo.commits()
        result = repo.run_script(
            "HEAD",
            "secret.txt",
            "--force",
            check=False,
        )

        assert result.returncode != 0
        assert "No files matching" in result.stderr
        assert repo.commits() == before
        assert repo.has_path(before[0], "secret.txt")
        assert not repo.has_path(before[2], "secret.txt")
