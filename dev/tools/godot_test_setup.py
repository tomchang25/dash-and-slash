"""
godot_test_setup.py - Prepare a safe /tmp snapshot for Godot test runs.

This helper is intentionally setup-only. It creates the sandbox-local project
copy, copies the gitignored Godot binary directory, verifies PyYAML is available,
and regenerates data/tres from the snapshot.
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


GODOT_BINARY_PATTERN = "Godot*_linux.x86_64"


def _log(message: str) -> None:
    print(message, file=sys.stderr)


def _run(args: list[str], cwd: Path, *, stdout=None) -> subprocess.CompletedProcess:
    return subprocess.run(args, cwd=cwd, text=True, stdout=stdout, stderr=sys.stderr)


def _checkout_index(repo_root: Path, snapshot: Path) -> str:
    prefix = f"{snapshot}/"
    result = _run(["git", "checkout-index", "-a", f"--prefix={prefix}"], cwd=repo_root)
    if result.returncode == 0:
        return "index"

    _log("git checkout-index failed; falling back to git archive HEAD.")
    archive = subprocess.Popen(
        ["git", "archive", "HEAD"],
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=sys.stderr,
    )
    extract = subprocess.Popen(
        ["tar", "-x", "-C", str(snapshot)],
        cwd=repo_root,
        stdin=archive.stdout,
        stderr=sys.stderr,
    )
    if archive.stdout is not None:
        archive.stdout.close()

    extract_status = extract.wait()
    archive_status = archive.wait()
    if archive_status != 0 or extract_status != 0:
        raise RuntimeError("Both git checkout-index and git archive HEAD failed.")
    return "HEAD"


def _copy_godot_bin(repo_root: Path, snapshot: Path) -> Path:
    source = repo_root / "dev" / "tools" / "bin"
    if not source.is_dir():
        raise RuntimeError(f"Godot binary directory not found: {source}")

    target_parent = snapshot / "dev" / "tools"
    target_parent.mkdir(parents=True, exist_ok=True)
    target = target_parent / "bin"
    shutil.copytree(source, target, dirs_exist_ok=True)

    matches = sorted(target.glob(GODOT_BINARY_PATTERN))
    if not matches:
        raise RuntimeError(f"No Godot binary matching {GODOT_BINARY_PATTERN} in {target}")
    return matches[0]


def _require_yaml() -> None:
    if importlib.util.find_spec("yaml") is None:
        raise RuntimeError(
            "PyYAML is not installed for this Python. In node:22-bookworm, install "
            "it once with: apt-get update && apt-get install -y python3-yaml"
        )


def _generate_tres(snapshot: Path) -> None:
    script = snapshot / "dev" / "tools" / "yaml_to_tres.py"
    result = _run(
        [sys.executable, str(script), "--godot-root", str(snapshot)],
        cwd=snapshot,
        stdout=sys.stderr,
    )
    if result.returncode != 0:
        raise RuntimeError("YAML to TRES generation failed.")


def _print_env(snapshot: Path, source: str, godot_bin: Path) -> None:
    values = {
        "DS": str(snapshot),
        "GODOT_TEST_SNAPSHOT_SOURCE": source,
        "GODOT_BIN": str(godot_bin),
    }
    for key, value in values.items():
        print(f"export {key}={shlex.quote(value)}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Prepare a safe /tmp snapshot for Godot headless and unit tests."
    )
    parser.add_argument(
        "--repo-root",
        default=os.getcwd(),
        help="Repository root to snapshot. Defaults to the current directory.",
    )
    parser.add_argument(
        "--env",
        action="store_true",
        help="Print shell exports for DS, GODOT_TEST_SNAPSHOT_SOURCE, and GODOT_BIN.",
    )
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    snapshot = Path(tempfile.mkdtemp(prefix="ds.", dir="/tmp"))

    try:
        _log(f"Snapshot: {snapshot}")
        source = _checkout_index(repo_root, snapshot)
        godot_bin = _copy_godot_bin(repo_root, snapshot)
        _require_yaml()
        _generate_tres(snapshot)
    except Exception as exc:
        print(f"godot-test setup failed: {exc}", file=sys.stderr)
        return 1

    if args.env:
        _print_env(snapshot, source, godot_bin)
    else:
        print(snapshot)
        _log(f"Snapshot source: {source}")
        _log(f"Godot binary: {godot_bin}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
