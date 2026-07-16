# Test Operations — Authoritative Godot Verification Contract

This file is the single source of truth for every agent-run test or Godot headless check in Tickstrike. Workflow commands must link here instead of duplicating setup, commands, pass criteria, caveats, or reporting rules.

Running Godot directly against the mounted working tree is forbidden: the mount can serve tail-truncated views of recently modified files, causing bogus parse, import, UID, or resource-cache failures. All agent-run Godot verification uses the safe `/tmp` snapshot below. Runtime and visual confirmation remains a manual responsibility in the real Godot editor.

## When To Run

- Run the applicable phases when the user asks for `/godot-test`, when a GDScript, scene, or resource change needs parser/import validation, or when gameplay behavior cannot be verified by a narrower non-engine check.
- Do not run Godot for documentation-only, TODO-only, workflow-only, or agent-rule-only changes unless the user explicitly asks.
- Use the narrowest available phase that proves the changed behavior. The `/godot-test` workflow runs the full available sequence: setup/import, plain headless check, then unit tests.

## Available Phases

1. **Snapshot/setup** — Materialize tracked content in a fresh sandbox-local directory and copy the gitignored Godot binary.
2. **Import only** — Populate `.godot` and imported assets. This is setup, not a pass/fail result; ignore import-phase errors and non-zero exit status unless setup itself cannot continue.
3. **Plain headless check** — Start and quit the project to detect parser, script, resource, and boot errors.
4. **Unit tests** — Run the GUT suite under `res://test/unit/` through the `--test-unit` flag handled by `GameManager._ready()`.

No automated smoke, interactive, screenshot, timing, animation, hitbox, or visual verification layer is currently available to agents in this project.

## Snapshot And Setup

The procedure only works when `/tmp` is a container-native Linux filesystem. Never use a Windows bind mount such as `E:/tmp:/tmp` for `/tmp`; doing so recreates the unreliable cross-OS mount inside the snapshot.

From the repository mount:

```bash
eval "$(python3 dev/tools/godot_test_setup.py --env)"
```

The helper:

- creates a fresh private `/tmp/ds.*` directory and exports it as `DS`;
- materializes the git index with `git checkout-index`, falling back to `git archive HEAD` when the index is unreadable;
- copies the gitignored Godot binary into the snapshot;
- exports `GODOT_TEST_SNAPSHOT_SOURCE` and `GODOT_BIN`.

Multiple agents and sessions share `/tmp`. Always use the fresh directory produced by the helper; never reuse a fixed path or attempt to clean up another session's directory.

## Execution And Pass Criteria

### Import Only

```bash
timeout 90 "$GODOT_BIN" --headless --path "$DS" --import
```

Ignore errors and non-zero exit status from this phase. Stop only when a setup failure prevents later phases, such as a missing Godot binary or an unusable snapshot.

### Plain Headless Check

```bash
timeout 90 "$GODOT_BIN" --headless --path "$DS" --quit 2>&1 | grep -E "SCRIPT ERROR|Parse|ERROR:|push_error|FATAL"
```

Pass when no unexpected error-level line remains after applying the caveats below and cross-checking every reported failure against the real repository files. Any confirmed matching line is a failure.

### Unit Tests

```bash
set -o pipefail
timeout 40 "$GODOT_BIN" --headless --path "$DS" --test-unit 2>&1 | tail -30
echo "exit=$?"
```

Pass when Godot exits `0`, at least one test script runs, the summary reports zero failed tests and zero errors, and no `SCRIPT ERROR` appears. The expected summary shape is `TestRunner: N scripts, N tests, N passed, N failed, N errors`.

Canonical user-side invocations live in `.github/workflows/ci.yml` and `.vscode/tasks.json` under `CI: unit tests`.

## Snapshot Semantics And Caveats

- Report `GODOT_TEST_SNAPSHOT_SOURCE` with every result. `index` means staged content; `HEAD` means the helper fell back to `git archive HEAD` and staged-but-uncommitted changes are absent.
- An index snapshot does not contain unstaged edits. If verification must include them, ask the user to stage them on the Windows side; agents must not run `git add` under this project's Git policy.
- If `checkout-index` fails with `unknown index entry format`, treat it as a stale mounted `.git/index`. Do not repair or mutate Git; let the helper use the HEAD fallback.
- `*.uid` files are tracked. UID or autoload-instantiation errors can come from stale `.godot` import state; use a fresh snapshot and import before treating them as real failures.
- `assets/` is gitignored, so missing source-asset warnings may be expected noise. `addons/gut` and `*.uid` files are tracked and must be present.
- Single-script checks outside the snapshot project path can collide with `class_name` registrations and report spurious global-class errors. Always run Godot with `--path "$DS"`.
- Cross-check every script, parse, UID, resource, or test failure against the authoritative Windows-side files before reporting it as a real defect.

## Result Reporting

Report:

- whether the snapshot came from `index` or the `HEAD` fallback;
- that unstaged working-tree edits are absent when applicable;
- the result of each phase actually run;
- confirmed failure lines only after cross-checking them against the real repository files;
- that import-phase errors were ignored, when relevant; and
- expected missing-asset noise only when it affected interpretation.

## Windows-Side Manual Runs

VS Code tasks must use the Godot `_console.exe` binary. The regular Windows executable is a GUI-subsystem app that detaches from the console, so a task may end after the version banner without test output or a usable exit code; that behavior is not a test failure.
