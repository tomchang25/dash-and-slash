# Godot Headless Check — Authoritative Safe Procedure

This file is the canonical safe snapshot and plain headless check procedure for the `/godot-test` slash command and any agent-run Godot headless check. Command wrappers should link here instead of duplicating the steps. Unit test layer lives in `godot_tests.md`.

Running `Godot --headless` directly against the mounted working tree is **forbidden**: the mount serves tail-truncated views of recently-modified files (see `sandbox_environment.md`), so Godot reports bogus parse errors that don't exist in the real files.

## When to run

- Run this procedure when the user asks for `/godot-test`, when a GDScript/scene/resource change needs Godot parser/import validation, or when a gameplay behavior change cannot be verified by a narrower test.
- Do not run Godot checks for docs-only, TODO-only, workflow-only, or agent-rule-only changes unless the user explicitly asks.
- If a change only updates planning docs, run the standards linter instead; Godot cannot add useful signal for that work.

## Cross-OS mount warning

The safe snapshot procedure only works when `/tmp` is a container-native Linux filesystem. Do not point Godot editor/import/headless at any project directory or temporary snapshot path backed by a Windows bind mount.

Bad Docker Compose example:

```yaml
volumes:
  - 'E:/GodotProjects/dash-and-slash:/workspace'
  - 'E:/tmp:/tmp'
```

The second mount defeats the procedure: `/tmp/ds.*` becomes another Windows/Docker Desktop mount, so Godot import can see stale or truncated files and emit bogus `.import`, UID, or resource-cache failures.

## Procedure (verified working)

Materialize a clean snapshot from the git index into a sandbox-local directory and run there. Index/object-DB reads bypass the mount's unreliable working-tree reads.

```bash
cd <repo mount>
eval "$(python3 dev/tools/godot_test_setup.py --env)"       # creates $DS, copies dev/tools/bin, regenerates data/tres/
timeout 90 "$GODOT_BIN" --headless --path "$DS" --import   # import/setup phase: regenerate .godot/.import; ignore errors and non-zero exit here
timeout 90 "$GODOT_BIN" --headless --path "$DS" --quit 2>&1 | grep -E "SCRIPT ERROR|Parse|ERROR:|push_error|FATAL"
```

`dev/tools/godot_test_setup.py` prints `DS`, `GODOT_TEST_SNAPSHOT_SOURCE`, and `GODOT_BIN` when called with `--env`. Report `GODOT_TEST_SNAPSHOT_SOURCE` with results: `index` means staged content; `HEAD` means the helper had to fall back to `git archive HEAD`, so staged-but-uncommitted changes are absent.

The helper requires PyYAML to already be installed for `python3`. In the `node:22-bookworm` agent image, install it once in the image/container with `apt-get update && apt-get install -y python3-yaml`; do not reinstall it during every test run.

The `--import` invocation is setup only and is not the pass/fail result. The real plain-headless check is the second invocation: any unexpected error-level line there is a failure after applying the caveats below and cross-checking against the real repo files.

Multiple agents/sessions share `/tmp`, and files created by another session's user are not removable (`Permission denied`). That is why a fixed path like `/tmp/ds` is forbidden: `mktemp -d` guarantees a private dir. Don't bother cleaning up other sessions' leftovers — just ignore them.

## Caveats

- If `checkout-index` fails with `unknown index entry format`, the mount is serving a stale `.git/index` (typically right after the user ran git on the Windows side). Don't attempt repairs.
- If `checkout-index` fails, `dev/tools/godot_test_setup.py` falls back to `git archive HEAD` because object-DB reads are unaffected by the stale index. The snapshot is then **HEAD, not the index**: staged-but-uncommitted changes are absent. State clearly that the check ran against HEAD when reporting results.
- **The snapshot is the INDEX, not the working tree.** Unstaged edits are absent. If results must reflect latest edits, ask the user to `git add` first; otherwise state clearly that the check ran against staged content.
- `*.uid` files are tracked and come along with checkout-index. If UID errors appear (`Unrecognized UID`, `Failed to instantiate an autoload`), the cause is a stale `.godot/` from an import that ran before the `.uid` files were in place — `rm -rf .godot` and re-import.
- `assets/` is gitignored ⇒ missing-texture/resource warnings in /tmp runs are expected noise, not findings. `addons/gut` and `*.uid` files are tracked baseline dependencies and should come along with `checkout-index`.
- Single-script checks (`--check-only -s <file>`) outside `--path "$DS"` collide with the project's `class_name` registrations and report spurious "hides a global script class" errors — always run with `--path "$DS"`.
- Any SCRIPT ERROR found in /tmp must be cross-checked against the Windows side (Read/Grep file tools) before being reported as a real bug.
