# Probe Standard

A probe is an early project artifact that makes a problem, architectural friction, design tension, or unresolved discussion portable before it becomes a plan, implementation spec, sketch, system doc, or durable decision.

A probe is allowed to be exploratory. It may describe only the current problem and discussion shape. It does not need an implementation plan, acceptance criteria, TODO pointer, or chosen direction.

## Use Cases

Use a probe for:

- Problem observations that need a stable link for review or external discussion.
- Architecture or design friction discovered during codebase review.
- Early thoughts that are more structured than a `TODO.md` Draft section but not yet actionable.
- Discussion handoff notes for another agent or collaborator.
- Codebase review conclusions that are not a staged review report and do not belong in `CHANGELOG.md`.

Do not use a probe for:

- A committed implementation sequence. Use `dev/workflows/implementation_spec_standard.md`.
- A multi-phase feature plan. Use `dev/workflows/plan_standard.md` or the matching sketch workflow.
- A current evergreen system description. Graduate the conclusion to `dev/docs/systems/` when the design locks.
- A permanent decision memory that intentionally omits implementation detail. Use the decision-note format instead.

## Placement

Probes live in `dev/docs/plans/` when they are tied to an active or likely work stream. Use the naming pattern:

```text
<flow_or_system>_<short_topic>.probe.md
```

Archive or delete the note when it stops being useful. If the discussion becomes actionable, convert it into the appropriate plan/spec/sketch and keep only one active source of truth.

## Format

Start with one bold title line:

```md
**Enemy FSM ownership split**
```

Then include these two metadata lines:

```md
Status: Draft probe.

Decision: none yet.
```

Use `Decision:` to record the current decision state. Valid examples:

- `Decision: none yet.`
- `Decision: deferred until Fable review.`
- `Decision: keep as observation only.`
- `Decision: resolved into <target doc or system>.`

After the metadata, write the body in prose. The note should explain the problem clearly enough that it still makes sense without the surrounding chat thread.

Use optional bullets when they make the discussion easier to scan. Bullet format:

```md
- **Short facet name** — One or two sentences explaining the evidence, consequence, or discussion angle.
```

Use `Open question:` lines for known unknowns. Each open question should be specific enough to guide a follow-up conversation.

## Content Rules

- Problem-only notes are valid.
- Codebase evidence is allowed, including class names, method names, fields, and high-level file references, because these notes may be discussion handoffs rather than durable design memory.
- Avoid line numbers and narrow diff details unless the note is explicitly a review handoff and the reference will remain useful after the current branch moves.
- Keep implementation proposals framed as discussion options unless a direction has actually been chosen.
- Do not include a task checklist unless the note has become actionable; convert it to a plan/spec instead.
- Do not duplicate the same conclusion in `TODO.md`, a plan, and a system doc. Keep one source of truth and link or move the content as it matures.
- Markdown prose follows the repo-wide no-hard-wrap rule.

## Common Shape

```md
**Topic noun phrase**

Status: Draft probe.

Decision: none yet.

One or two paragraphs describing the problem, why it matters, and what makes it worth discussing now.

- **Evidence or facet** — One or two sentences naming a concrete symptom, codebase pressure point, design tension, or consequence.

- **Second facet** — One or two sentences with another angle.

The discussion target is a short paragraph describing what the next conversation needs to decide or clarify. This is not an implementation plan.

Open question: the first unresolved decision is phrased as a direct question.

Open question: the second unresolved decision is phrased as a direct question.
```

## Graduation

When the discussion resolves:

- If it becomes work, convert it into the appropriate plan, sketch, or implementation spec and remove or archive the probe.
- If it becomes evergreen design, graduate the conclusion into a `dev/docs/systems/` doc and archive the probe.
- If it becomes a durable rationale without implementation detail, rewrite it as a decision note.
- If it becomes irrelevant, delete it.
