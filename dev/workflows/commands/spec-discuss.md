# spec-discuss — resolve implementation-spec decisions

Inspect a proposed implementation-spec target against the live codebase, discuss the decisions that require user authority, and establish a locked input for `/spec-build`.

This command is read-only. Do not edit files, rename or remove source documents, update lifecycle pointers, run formatters, or implement the work.

## Input

The user may provide a plan child, sketch, probe, existing draft, feature request, or other focused work description:

```text
/spec-discuss <target or free-form brief>
```

Treat decisions already confirmed in the current conversation or explicitly locked in the source document as authoritative unless live code reveals a direct conflict. Do not reopen them merely because another implementation is possible.

## Required Reading

Before discussing the target, read:

1. `dev/agent_rules/agent_startup.md`.
2. `dev/workflows/implementation_spec_standard.md`.
3. The named source document and its parent plan, when either exists.
4. The source artifact's workflow or standard when it is a plan, sketch, or probe.
5. `dev/docs/README.md` and every request-relevant rule, standard, system doc, or skill discovered from the target.

## Steps

1. Restate the intended spec boundary in one compact sentence and identify whether it is a plan child or standalone work.
2. Read the source and parent, then extract the requirements, non-goals, acceptance criteria, and user decisions that are already locked. Keep parent-owned requirements in the parent; do not propose duplicating them in a child spec.
3. Inspect the relevant live code independently of the source document. Trace current ownership, call direction, data flow, lifecycle behavior, presentation hooks, cleanup paths, tests, and the old surface the work intends to replace. Follow references only while they materially affect the target's blast radius or a user-facing decision.
4. Separate user-authority decisions from spec-author decisions. Ask the user only about choices that would change a requirement, player-observable behavior, product scope, compatibility promise, or numerical meaning. Resolve file placement, API shape, ownership wiring, migration mechanics, test placement, and other implementation architecture from the approved intent and codebase constraints.
5. For every decision that needs confirmation, present the codebase evidence, the behavioral boundary between the viable options, and one recommended default with a concise reason. Batch all known decisions into one response.
6. Answer follow-up questions with additional evidence while remaining read-only. When the user confirms the direction, return a compact `Locked Decisions` recap and a `Build Readiness` statement identifying the source and expected spec target, then direct the user to `/spec-build`. Do not automatically start the build or edit files.
7. If no user-authority decision remains, say so explicitly, summarize the already locked behavior, and report that the target is ready for `/spec-build`.

## Output

Write the discussion in the user's language, keeping code identifiers and file paths exact. Use only the sections needed from this shape:

1. **Target** — the intended implementation-spec boundary and lifecycle type.
2. **Codebase Fit** — the evidence that constrains the direction, organized by system relationship rather than as a file inventory.
3. **Decisions to Confirm** — each decision with evidence, viable options, and a recommended default. Omit when none remain.
4. **Locked Decisions** — confirmed or source-owned behavior that `/spec-build` must preserve.
5. **Build Readiness** — whether the target is ready and what document `/spec-build` should produce or replace.

## Guardrails

- Do not write a spec, sketch, plan, probe, or implementation.
- Do not use an `Open Questions` section. Decisions are resolved in conversation and are never parked in the eventual spec.
- Do not turn technical implementation choices into user questions when the approved behavior and repository constraints already determine them.
- Do not manufacture a conflict from an old path the target explicitly intends to replace. Surface it only when behavior outside the intended refactor or a preservation contract would be affected.
- Recommendations must cite concrete codebase or design evidence; do not present preference as architecture necessity.
- Do not run tests. This command verifies context and decision boundaries, not implementation correctness.

$ARGUMENTS
