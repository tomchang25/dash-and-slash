# Godot Tests — Unit Tests (How to Run)

The automated test layer is a command-line flag handled by `GameManager._ready()`; it exits non-zero on failure.

- **Unit tests** (`--test-unit`): GameManager skips normal boot and routes to `test/test_runner.tscn`. GUT runs everything under `res://test/unit/` (subdirectories included), prints a summary line (`TestRunner: N scripts, N tests, N passed, N failed, N errors`), and quits 0/1.

Canonical invocations live in `.github/workflows/ci.yml` and `.vscode/tasks.json` ("CI: unit tests").

## Sandbox procedure

Never run the test layer against the mounted working tree (`sandbox_environment.md`). Build a `/tmp` snapshot with `dev/tools/godot_test_setup.py --env` as in `godot_test_check.md`, and ensure `/tmp` is container-native Linux storage, not a Windows bind mount such as `E:/tmp:/tmp`. The `--import` step is setup only; ignore errors and non-zero exit status from that phase. Then:

```bash
# Unit tests
timeout 40 "$GODOT_BIN" --headless --path "$DS" --test-unit 2>&1 | tail -30; echo "exit=$?"
```

Pass criteria: exit 0 and a summary line with 0 failed / 0 errors.

As with the headless check: the snapshot is the **index**, not the working tree — ask the user to `git add` first if results must reflect unstaged edits, and cross-check any failure against the Windows side (Read/Grep file tools) before reporting it as a real bug.

## Windows side (user-run)

The VS Code tasks must point at the `_console.exe` Godot binary. The regular Windows exe is a GUI-subsystem app that detaches from the console immediately, so Run Task ends after the version banner with no test output and no usable exit code. If a task shows only the banner and finishes instantly, that is the cause — not a test failure.
