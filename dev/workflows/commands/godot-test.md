# godot-test — safe Godot test workflow

Run the safe Godot test workflow from a `/tmp` snapshot: import assets first, ignore import-phase errors, then run the real headless and unit checks.

## Required Reading

Before executing, read:

- `dev/agent_rules/sandbox_environment.md`
- `dev/agent_rules/git_operations.md`
- `dev/agent_rules/test_operations.md`

## Guardrails

- Treat git as read-only. Do not stage, commit, restore, reset, stash, switch/checkout branches, or otherwise mutate repo state. The only permitted checkout command is `git checkout-index`, and only when used exactly for the documented `/tmp` snapshot.
- Never run Godot directly against the mounted working tree.
- If the requested check must include unstaged edits, stop and ask the user to stage them on the Windows side. Do not run `git add`.
- This is an agent workflow command. Use `dev/tools/godot_test_setup.py` for snapshot/setup; do not add or rely on any other wrapper script unless the user explicitly asks for one.

## Execution

Follow `dev/agent_rules/test_operations.md` as the single source of truth for available phases, snapshot creation, commands, pass criteria, fallback, caveats, error cross-checking, and result reporting. Do not copy or improvise long command sequences here; if the test contract changes, this command follows it.

## Phases

1. **Snapshot/setup** — Build the safe `/tmp` snapshot exactly as documented in `dev/agent_rules/test_operations.md`.
2. **Import only** — Run Godot with `--headless --path "$DS" --import` to materialize `.godot` and imported assets. Ignore errors and non-zero exit status from this phase; this phase is not the test result. Stop only for setup failures such as a missing Godot binary or failed snapshot creation.
3. **Real headless check** — Run Godot with `--headless --path "$DS" --quit`. Capture output. If any unexpected error-level line appears (`SCRIPT ERROR`, `Parse`, `ERROR:`, `push_error`, or `FATAL`), report `FAIL: headless check` with the matching lines after cross-checking against the real repo files.
4. **Unit test** — Run the `--test-unit` layer from `dev/agent_rules/test_operations.md`. Report `FAIL: unit test` if Godot exits non-zero, no scripts run, the summary has failed tests/errors, or `SCRIPT ERROR` appears.

When reporting results, include:

- Whether the snapshot came from the index or the HEAD fallback.
- That unstaged working-tree edits are absent from an index snapshot.
- The result of each real phase: headless check and unit test.
- Any script/parse/error-level failures only after cross-checking them against the real repo files.
- That import-phase errors were ignored, if any appeared.
- Expected missing `assets/` or `addons/` noise only if relevant.

$ARGUMENTS
