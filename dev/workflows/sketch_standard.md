# Sketch Standard

Use this standard to produce a sketch: the single document for a small feature, replacing both the Plan and Implementation Spec stages.

A Sketch carries everything a small feature needs in one pass: behavioral requirements at Plan depth, plus a non-normative implementation sketch with pseudo-code, proposed names, data shapes, and migration steps written down from the design conversation.

| Document | Code references | Verification contract |
| --- | --- | --- |
| Plan | forbidden | none needed; durable by construction |
| Sketch | allowed | non-normative; intent only, implementer verifies on contact |
| Spec | required | normative; every claim carries a codebase-verified coordinate |

The non-normative marker makes code in a sketch safe: names and snippets are illustrative, and the codebase wins every disagreement. The author is not required to explore the codebase; light spot-checks are fine, but exhaustive evidence-gathering means you should write a spec instead.

Use this for:

- Small features whose design was fully settled in the planning conversation
- Changes confined to one system, or with a blast radius the author already understands without exploration
- Work where a Plan's only purpose would be to be transcribed into a spec immediately

Do not use this for:

- Changes with non-obvious cross-system ownership or call-direction questions; those need a Spec's relational context from codebase evidence
- Designs worth keeping after shipping, such as mechanics, economy, or invariants; those need a Plan that survives refactors
- Anything still carrying an unresolved design decision; ask during the conversation, because a sketch never contains open questions

---

## Output Structure

Sections 1-3 and 5-6 follow the Plan Standard's rules exactly: behavioral level, no code coordinates, and why stated inline. Only section 4 may contain code.

### 1. Goal

One to three sentences: capability, reason, gap.

### 2. Requirements

Numbered list at the product/behavioral level, why stated inline when non-obvious.

### 3. Design

Optional behavioral design: mechanics, numbers, tables, worked examples. No code coordinates here.

### 4. Sketch (non-normative)

The section that defines this document type. Pseudo-code, proposed class/file/function names, data-shape examples, and an ordered migration/step list. Everything here is a proposal, not a claim about the codebase.

- Names are suggestions; the implementer renames freely to match conventions on the ground.
- Snippets express intent and shape; they are not expected to compile or match real signatures.
- References to existing code are recalled, not verified; when the codebase disagrees, the codebase wins silently.
- Anything the author does not know is left out, not guessed.

### 5. Non-Goals

Optional numbered exclusions, when the boundary is not obvious.

### 6. Acceptance Criteria

Numbered, observable, behavioral. No file paths or function names.

---

## Rules

1. Write entirely in English.
2. The Sketch section heading must carry the literal marker `(non-normative)`.
3. Code and code coordinates appear only inside the Sketch section.
4. No retrieval obligation and no retrieval theater; if the change genuinely needs verified coordinates, stop and write a Plan + Spec.
5. No open questions; unresolved decisions are resolved in the planning conversation before the sketch is written.
6. Do not hard-wrap prose lines at a column boundary. Tables and code blocks are exempt.

---

## Lifecycle

- File name: `dev/docs/plans/<scope>_<short_description>.sketch.md`, with the usual one-line pointer in `TODO.md`.
- Implementation goes straight from the sketch; there is no spec stage and no separate scout stage.
- Shipped work gets a `CHANGELOG.md` entry, archives the sketch, and deletes the TODO line, same as a plan.

---

## Template

```md
# <Title>

## Goal

<One to three sentences: capability, reason, gap.>

## Requirements

1. <Requirement at product/behavioral level. Why inline if non-obvious.>
2. <Requirement at product/behavioral level.>

## Design

<Optional. Behavioral design only; no code coordinates.>

## Sketch (non-normative)

<Pseudo-code, proposed names, data shapes, migration steps. All illustrative; the codebase wins every disagreement.>

## Non-Goals

1. <Explicit exclusion.>

## Acceptance Criteria

1. <Observable outcome.>
2. <Observable outcome.>
```
