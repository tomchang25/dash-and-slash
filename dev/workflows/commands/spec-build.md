# spec-build — build a verified implementation spec

Build the final codebase-verified implementation spec for a focused work item, then update the source document and tracking pointers so the spec is the only actionable implementation handoff.

This command writes documentation only. It does not implement code, stage changes, commit, push, create a PR, or run engine validation.

## Input

The user may provide a plan child, sketch, actionable probe, existing draft, narrow feature request, or another focused target:

```text
/spec-build <target or free-form brief>
```

The command may follow `/spec-discuss` in the same conversation or be invoked directly. Decisions explicitly confirmed in the current conversation are part of the input and must be folded into the spec.

## Required Reading

Before editing, read:

1. `dev/agent_rules/agent_startup.md`.
2. `dev/workflows/implementation_spec_standard.md` in full.
3. `dev/docs/README.md`.
4. The named source document and its parent plan, when either exists.
5. The source artifact's workflow or standard when it is a plan, sketch, or probe.
6. Every request-relevant rule, standard, system doc, or skill discovered from the target, including `dev/agent_rules/lint_before_finish.md`.

## Decision Gate

Before any edit:

1. Collect the behavior, scope, compatibility, and numerical decisions already locked by the source documents and current conversation.
2. Re-read the relevant live code independently of any earlier research or sketch. Verify current ownership, call direction, data flow, lifecycle behavior, presentation hooks, cleanup paths, tests, and replacement surface across the full blast radius.
3. Resolve implementation architecture from approved intent and repository constraints. Do not ask the user to choose file placement, API shape, reference shape, migration mechanics, test placement, or other technical details the spec author can determine safely.
4. If any unresolved choice would change a requirement, player-observable behavior, product scope, compatibility promise, or numerical meaning, stop before editing. Present all such decisions in one batch with codebase evidence, viable options, and a recommended default. Continue this command after the user confirms them.
5. If live code contradicts a previously locked decision, explain the concrete conflict and stop for confirmation rather than silently changing the approved behavior.

## Steps

1. Classify the target as a plan child or standalone spec and determine the destination required by `dev/workflows/implementation_spec_standard.md`.
2. Build the verified implementation model from live code: every touched system relationship, changed integration contract, ownership rule, wrong shape to avoid, file responsibility, safe landing order, implementation hazard, meaningful edge case, and observable acceptance outcome.
3. Write the implementation spec entirely in English using the exact structure and content rules from `dev/workflows/implementation_spec_standard.md`. The Summary is the human approval surface; Relational Context must cover every relationship inside the Files to Change blast radius.
4. Apply the correct lifecycle update:
   - For a plan child, point the parent plan's child overview entry to the new `.implementation_spec.md`, preserve parent-owned requirements, remove the replaced child sketch from active `dev/docs/plans/`, and do not add a `TODO.md` entry.
   - For a standalone spec, keep or create exactly one one-line pointer in `TODO.md`: preserve `## Active` when the source was already active, otherwise use `## Plan`. Remove the replaced Draft section or stale pointer instead of duplicating it.
   - When an actionable probe or standalone sketch is converted, remove it from active `dev/docs/plans/` after the spec and pointers are complete. Archive it only when its historical discussion remains useful; otherwise delete it. Never leave two active sources of truth for the same work.
   - When building directly from a feature request with no source file, create only the required spec and lifecycle pointer.
5. Search the updated parent, `TODO.md`, and `dev/docs/plans/` for stale references to the replaced source filename or document form. Fix only references owned by this lifecycle transition.
6. Run `python dev/tools/lint_standards.py --files <every changed Markdown file>` and correct all reported violations.
7. Inspect the final diff and report the created spec, replaced or archived source, pointer updates, locked behavioral decisions captured, and lint result. Do not claim implementation is complete.

## Guardrails

- A sketch or earlier research is context, not verified authority. Re-check every codebase claim before placing it in the spec.
- Do not start document edits before the Decision Gate passes.
- Do not include unresolved questions or an `Open Questions` section in the spec.
- Do not duplicate parent requirements in a child spec or give a child its own TODO pointer.
- Do not add speculative future scope, incidental cleanup, new systems, assets, VFX, audio, tests, or migrations unless the approved behavior and verified blast radius require them.
- Do not preserve legacy names, compatibility paths, or old files when the approved scope explicitly removes them, unless live external consumers establish a compatibility requirement.
- Do not run `/godot-test`, project tests, formatters, or implementation validation for a documentation-only spec build.
- Keep unrelated user changes untouched.

$ARGUMENTS
