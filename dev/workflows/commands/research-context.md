# research-context — retrieve relevant codebase context

Retrieve relevant codebase context for an idea, scratchboard entry, draft, or small plan so the user can do further research.

This command is read-only. Do not edit files, stage changes, commit, run formatters, or implement the idea.

## Input

The user may provide free-form notes, for example:

```text
[Talk about an idea or a scratchboard entry, draft, small plan]

Please retrieve all relative codebase for me for further research
```

Treat the note as a research brief, not as an implementation request.

## Required Reading

Before searching, read:

- `dev/agent_rules/agent_startup.md`
- Any standards, workflows, docs, or plans that the brief directly names

## Steps

1. Restate the research target in one compact sentence.
2. Identify likely domains, systems, scenes, data, tests, docs, and standards from the brief.
3. Search the repo for relevant terms, symbols, scene names, data names, and related concepts. Prefer `Glob` and `Grep` over shell text tools.
4. Read the most relevant files directly. Do not bulk-read unrelated files or dump broad directories.
5. Trace the current ownership of relevant data and behavior, the surface that the intended work will replace, migrate, or rewire, and the existing behavioral contracts that must survive that work.
6. Follow discovered references when they materially change that context, but stop before turning retrieval into implementation design.
7. Distinguish an expected old path that the brief already intends to replace from a genuine conflict that would affect behavior outside the intended refactor. Do not report the former as a conflict merely because it differs from the target design.
8. Identify only the decisions that live code cannot answer and that must be settled before an implementation spec can be written. Present evidence and decision boundaries without choosing an implementation direction.
9. Report only codebase context. Do not propose code changes unless the user asks for implementation planning.

## Output

Return a concise research map with these sections, in this order:

1. **Research Target** — the inferred topic and scope.
2. **Relevant Codebase Context** — one cohesive account combining current ownership of relevant data and behavior, the refactor surface that must be replaced, migrated, or rewired, and the existing contracts that must survive. Include constraining rules or docs where they materially affect that context. Organize by system relationship or responsibility rather than by file, and cite file paths only where they help substantiate a claim.
3. **Spec-Time Decisions** — decisions that live code cannot resolve and that must be settled before an implementation spec can be written. State the evidence and the boundary of each decision without recommending or selecting an implementation. Omit this section only when no such decisions exist.
4. **Summary** — a compact final synthesis written in Traditional Chinese. State what the codebase context means for the intended work, what must be preserved, and whether any spec-time decisions remain. Do not introduce facts or recommendations that are absent from the preceding sections.

## Guardrails

- Keep retrieval scoped to relevant codebase context. Do not retrieve the whole repo.
- Do not produce a file-by-file inventory or reading checklist. The report should explain relationships, ownership, refactor surface, and preserved contracts rather than ask the user to inspect individual files.
- Do not label an existing path as a conflict when the brief already intends to replace it. Report a conflict only when it exposes an incompatible requirement, an affected behavior outside the intended refactor, or a preservation contract the proposed direction would break.
- Keep `Spec-Time Decisions` neutral. Research may expose a choice, but selecting or recommending an implementation belongs to planning or spec authoring.
- Do not write a plan, sketch, spec, or implementation unless explicitly asked after the retrieval.
- Do not run tests unless the user specifically asks; this command is for research context, not verification.

$ARGUMENTS
