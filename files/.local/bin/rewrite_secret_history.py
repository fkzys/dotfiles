#!/usr/bin/env python3

import argparse
import fnmatch
import os
import subprocess
import tempfile


def git(*args):
    return subprocess.check_output(["git", *args])


def in_scope(path, patterns):
    path = os.fsdecode(path)
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)


def build_callback(ancestor_ids, target_blobs, all_paths):
    return f"""\
ancestor_ids = {ancestor_ids!r}
target_blobs = {target_blobs!r}
all_paths = {all_paths!r}

if commit.original_id in ancestor_ids:
    commit.file_changes = [
        change
        for change in commit.file_changes
        if change.filename not in all_paths
    ]

    for path in sorted(all_paths):
        if path in target_blobs:
            blob_id, mode = target_blobs[path]
            commit.file_changes.append(FileChange(b"M", path, blob_id, mode))
        else:
            commit.file_changes.append(FileChange(b"D", path))
"""


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Propagate the state of the given paths at COMMIT into all of "
            "its ancestors, so the target state is used throughout earlier "
            "history."
        ),
        epilog="""\
Paths are repo-relative and support fnmatch globs. Use --force when
git-filter-repo refuses to run on a non-fresh clone.

examples:
  rewrite_secret_history.py fcf3bc4 'secrets/**'
  rewrite_secret_history.py HEAD~3 'secrets/**' '**/secrets/**' --force
  rewrite_secret_history.py 4a1b2c3 config/credentials.json config/api.key
""",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "commit",
        help="commit whose path state is propagated to its ancestors",
    )
    parser.add_argument(
        "paths",
        nargs="+",
        metavar="PATH",
        help=(
            "repo-relative file path or glob pattern (fnmatch) to move into "
            "earlier commits"
        ),
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="pass --force to git-filter-repo",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    target = git(
        "rev-parse", "--verify", f"{args.commit}^{{commit}}"
    ).strip().decode()

    ancestor_ids = set(git("rev-list", f"{target}^@").splitlines())

    raw_tree = git("ls-tree", "-r", "-z", "--full-tree", target)

    target_blobs = {}

    for row in raw_tree.split(b"\0"):
        if not row:
            continue

        metadata, path = row.split(b"\t", 1)
        mode, object_type, blob_id = metadata.split()

        if not in_scope(path, args.paths):
            continue

        if object_type != b"blob":
            raise SystemExit(
                f"Unexpected object type for {path!r}: {object_type!r}"
            )

        target_blobs[path] = (blob_id, mode)

    if not target_blobs:
        raise SystemExit(
            "No files matching the given paths at COMMIT. "
            "Check COMMIT and the path patterns."
        )

    raw_history = git(
        "log",
        "--format=",
        "-z",
        "--name-only",
        "--no-renames",
        target,
    )

    all_paths = {
        path
        for path in raw_history.split(b"\0")
        if path and in_scope(path, args.paths)
    }
    all_paths.update(target_blobs)

    callback = build_callback(ancestor_ids, target_blobs, all_paths)

    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        suffix=".py",
        delete=False,
    ) as callback_file:
        callback_file.write(callback)
        callback_path = callback_file.name

    command = ["git-filter-repo", "--commit-callback", callback_path]
    if args.force:
        command.insert(1, "--force")

    try:
        subprocess.run(command, check=True)
    finally:
        os.unlink(callback_path)


if __name__ == "__main__":
    main()
