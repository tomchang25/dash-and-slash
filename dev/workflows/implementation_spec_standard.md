# Implementation Spec Standard

Use this standard to produce the final implementation handoff: a codebase-verified document that tells an implementation agent exactly what to change, what order to land it in, what relationships must be preserved, and what observable behavior proves completion. In conversation and in other documents, "spec" is always short for implementation spec.

An implementation spec is not a plan and not a sketch. A plan owns durable product/design intent. A sketch may explore a plan child before the final handoff. The spec is written last, against the codebase as it exists at that moment, and is the only document intended to be executed directly.

## Lifecycle Position

Common routes:

- `feature request` or actionable `probe` -> implementation spec, when the work is narrow enough that a durable plan would add little.
- `probe` -> plan -> child sketch -> implementation spec, when the work needs durable design, decomposition, or sequencing. Skip the sketch only for small, obvious child boundaries.

All upstream stages may retrieve codebase context. That context is allowed to influence the plan or sketch, but it is not a substitute for spec-time verification. Before writing the implementation spec, the authoring agent re-reads the relevant live code and updates or replaces the earlier approach as needed.

## Roles and Quality Gate

The spec is authored by a high-capability agent after independent codebase exploration. It is executed by an implementation agent that translates clear instructions into code but **cannot reliably infer cross-system relationships**. Every relationship the change depends on must be stated; an omitted relationship will be invented, and the executing agent will not notice it was wrong.

Before handoff, the human reviews the Goal and Summary. Those sections are the approval surface; everything below them is for execution. The spec plus that review is the last quality gate before code is written.

## Output Structure

The first line under the title is always the parent marker:

```md
Parent Plan: `<plan_filename.md>`
```

For standalone specs, write:

```md
Parent Plan: none (standalone spec)
```

### 1. Goal

One to three sentences: what capability is being added or changed, and why. Condensed from the parent plan when one exists. No implementation detail here.

### 2. Summary

The human approval surface. It should be easy to scan, approve, or reject without reading the execution-only sections first.

Use the shape that fits the work: a few short paragraphs, a bullet list with context-specific labels, or a compact table when comparison matters. Do not force every Summary into the same four headings. The reviewer should still be able to answer these questions from it: why the change is worth doing, what changes, roughly how the change will be made, and what the result will look like once it lands.

Defined by content obligations, not length. There is no length cap: the failure mode is omission, not verbosity. The Summary only condenses the rest of the document; it never carries a fact stated nowhere else, and any disagreement between the Summary and the body is a document bug.

### 3. Requirements (standalone only)

Numbered behavioral requirements at Plan depth, with the why stated inline when non-obvious. Only standalone specs carry this section; a plan child omits it because the parent plan owns the requirements and children never duplicate them.

### 4. Relational Context

A flat bullet list. No subsections.

Write the constraints and decisions an implementation agent would get wrong without being told. Include whichever of the following apply:

- **Call direction** between touched systems: who calls who, and whether it is a read or a write.
- **Ownership rules**: which system is the single authority for a piece of state.
- **Changed integration contracts**: before -> after for any cross-system interface this change modifies.
- **Wrong shapes to avoid**: describe the incorrect coupling pattern in terms of system responsibility, not function names.

**Completeness rule, load-bearing:** Every system relationship that a Files-to-Change entry participates in must appear here, even one that would be "obvious" to a strong reader. The executing agent does not infer, so an unstated relationship is an unspecified one. The boundary that keeps this from becoming noise is **blast radius**, not obviousness: document every relationship the change touches; do not document relationships elsewhere in the codebase that the change does not interact with.

### 5. Scope

#### Included

Short bullet list of what this document covers.

#### Excluded

Short bullet list of what is intentionally out of scope. Keep it tight to prevent scope bleed during implementation.

### 6. Files to Change

| File     | Change Size            | Purpose                                          |
| -------- | ---------------------- | ------------------------------------------------ |
| `<file>` | Small / Medium / Large | What this file is responsible for in this change |

Identifies ownership and change effort. Does not prescribe line-by-line edits.

### 7. Execution Outline

The implementation-facing sequence. This is the bridge between the verified architecture contract above and the actual edit loop below.

Use numbered steps for the recommended landing order. Each step should be a reviewable implementation beat, not a line-by-line recipe. A good step names the file or system touched, states the concrete edit outcome, and explains ordering only when order matters.

Include test/update beats in the same sequence when they are part of the safest landing path. For example, extract pure helper -> add focused tests -> switch first caller -> switch second caller -> delete old path -> run verification.

Do not duplicate the Files to Change table. Do not spell out code the agent can read directly. Do not hide relationship rules here; relationship rules still live in Relational Context.

### 8. Implementation Notes

Write only the decisions and constraints the implementation agent is likely to get wrong.

Organize by file or system when grouping helps. Use bullets or short paragraphs.

Do not write step-by-step instructions. Do not reproduce logic the agent can read from the codebase. Include pseudocode only for non-obvious branching logic or state transitions.

### 9. Edge Cases

| Case     | Expected Handling     |
| -------- | --------------------- |
| `<case>` | `<expected behavior>` |

Omit this section if no meaningful edge cases exist.

### 10. Acceptance Criteria

Numbered list of observable, behavioral outcomes, at the same level as a Plan's acceptance criteria.

Do not include file paths or function names.

## Rules

1. Write entirely in English.
2. No open questions; unresolved decisions are resolved in conversation before the spec is written.
3. The first line under the title is `Parent Plan: ...`; use the parent plan filename for plan children and `Parent Plan: none (standalone spec)` for standalone specs.
4. Requires codebase exploration before authoring. Never fill Relational Context or Files to Change from the plan or sketch alone.
5. Apply the completeness rule: every cross-system relationship within the change's blast radius is stated, even the obvious ones; relationships outside the blast radius stay undocumented.
6. Do not mix future scope into this document.
7. Do not hard-wrap prose lines. Tables and code blocks are exempt.
8. Execution Outline is expected for non-trivial specs. Omit it only when Files to Change plus Implementation Notes already make the edit sequence obvious.
9. Execution Outline is a landing sequence, not a script. It should be specific enough for a lower-capability implementation agent to proceed without inventing order, but it must not become line-by-line code instructions.
10. Implementation Notes stay shorter than a full per-file plan. If you are writing step-by-step per-file instructions, move the order into Execution Outline and keep notes to hazards/constraints.
11. Do not include implementation detail the executing agent can discover from the codebase, except where the completeness rule requires stating a relationship explicitly.
12. Target under 800 words for Relational Context through Edge Cases; exceed only when relational complexity or execution ordering genuinely requires it. The Summary is exempt because completeness beats brevity there.

## Lifecycle

- Standalone specs live at `dev/docs/plans/<scope>_<short_description>.implementation_spec.md` with the usual one-line pointer in `TODO.md`.
- Plan-child specs live next to the parent plan as `dev/docs/plans/<parent_scope>_<NN>_<slug>.implementation_spec.md` and are pointed to only from the parent plan's child overview table; they get no separate `TODO.md` line.
- When a child sketch exists, creating the spec is a rewrite-and-verify step, not a promotion-by-trust step: read the sketch as context, re-check the live codebase, keep what survives, and freely delete or replace what no longer fits.
- Shipped work gets a `CHANGELOG.md` entry and archives the spec. A shipped child is also cut from the parent's child overview table; a shipped standalone deletes its `TODO.md` line.

## Template

```md
# <Title>

Parent Plan: `<plan_filename.md>` <!-- or: Parent Plan: none (standalone spec) -->

## Goal

<One to three sentences.>

## Summary

<Scannable approval summary. Use short paragraphs, context-specific bullets, or a compact table as appropriate. It should answer why this is needed, what changes, roughly how it changes, and what the landed result looks like without forcing those exact headings.>

## Requirements

<Standalone specs only. Numbered behavioral requirements, why inline.>

## Relational Context

- <Call direction, ownership rule, changed contract, or wrong shape to avoid.>
- <Every relationship within the change's blast radius, including the obvious ones.>

## Scope

### Included

- <Included change>

### Excluded

- <Excluded change>

## Files to Change

| File     | Change Size            | Purpose   |
| -------- | ---------------------- | --------- |
| `<file>` | Small / Medium / Large | <Purpose> |

## Execution Outline

1. <First reviewable implementation beat and why it comes first if order matters.>
2. <Second beat.>
3. <Cleanup, tests, and verification beat.>

## Implementation Notes

<Organized by file or system. Bullets or short paragraphs. Pseudocode only when branching is non-obvious.>

## Edge Cases

| Case     | Expected Handling     |
| -------- | --------------------- |
| `<case>` | `<expected behavior>` |

## Acceptance Criteria

1. <Observable outcome.>
2. <Observable outcome.>
```
