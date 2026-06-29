# Lint Before Finishing

If you are an agent without the in-loop lint hook (i.e. not Claude Code), run the standards linter on the files you changed before finishing:

```bash
python dev/tools/lint_standards.py --files <changed files>
```

## Scope verification to the work

- Docs-only or TODO-only changes: run only the standards linter on the changed Markdown files.
- GDScript or scene changes: run the standards linter on the changed `.gd` and `.tscn` files, plus any changed docs that must pass standards checks.
- Gameplay, state-machine, data-loading, or scene-routing behavior changes: after linting, run the narrowest relevant test/check required by the change or requested by the user.
- Additional engine validation is opt-in only. Discuss it only when the user explicitly asks for `/godot-test` or a dedicated test agent.

Prefer the smallest verification that proves the touched surface. Do not run broad tests for documentation-only work.

See `dev/standards/standards_enforcement.md` for what the linter checks and how to add new rules.
