# Review Standard

Use this standard when a command asks for a code review of a change scope. The command that references this file defines the scope, such as staged files or branch/PR files. This standard defines how to review that scope.

## Review Inputs

1. Identify the changed files from the calling command's scope.
2. Read the full current contents of every changed source, scene, data, test, and workflow file in scope. Do not limit review to diff hunks.
3. Read the relevant diff for each changed file to understand what changed and why.
4. If a plan/spec is part of the scope, or the calling command identifies one, review against every requirement, implementation note, edge case, and acceptance criterion.
5. Pull in nearby or referenced codebase context whenever the changed file depends on another script, scene, resource, registry, save path, signal, data ID, command workflow, or standard.

## Review Depth

Review findings are not limited to modified lines. Treat the full changed file as reviewable because a small diff can make older code stale, redundant, unreachable, or unsafe.

For every changed file, check for:

1. Behavioral bugs, regressions, missing edge cases, and incorrect assumptions.
2. Stale references to renamed or removed APIs, constants, data IDs, node paths, signals, resource paths, imports, workflow steps, or documentation claims.
3. Redundant or divergent old logic left beside the new path, including unused helpers, duplicate guards, obsolete adapters, dead branches, and comments/TODOs that no longer match behavior.
4. Robustness gaps for null, empty, missing, invalid, duplicated, out-of-order, lifecycle, initialization, save/load, migration, and resource-loading cases.
5. Standards violations from `dev/standards/`, command workflow violations from `dev/workflows/`, and agent rule violations from `dev/agent_rules/` that apply to the changed files.
6. Missing or weakened tests, fixtures, data coverage, validation, or lint coverage where the change creates meaningful risk.

## Related Codebase Search

Search beyond the changed files when the diff introduces, removes, renames, or changes behavior for any public or cross-file concept. Examples include method names, signal names, constants, resource IDs, save keys, scene paths, YAML fields, registry APIs, command names, and documented workflows.

Use the search to answer:

1. Are old names or removed behaviors still referenced anywhere?
2. Are new names or behaviors wired into all required callers, tests, docs, and data?
3. Did the change make any existing code redundant or contradictory?
4. Does related code rely on ordering, side effects, defaults, or invariants that the changed file no longer preserves?

## Reporting

Report findings first, ordered by severity. Include file and line references when possible.

Use English for every report section except `Summary`, unless the user explicitly asks for another language. Write `Summary` in Traditional Chinese.

Use this verdict language:

1. `pass` — no blocking or material issues found.
2. `needs changes` — issues found that should be fixed before merge/commit.
3. `blocked` — review could not be completed because required context, files, or commands are unavailable.

Use this section order:

1. `Findings`
2. `Per-File Review Summary`
3. `Stale/Redundant Check`
4. `Robustness Check`
5. `Standards, Lint, And Tests`
6. `Summary`

The report must include:

1. Findings first. If there are no findings, say that explicitly.
2. A per-file review summary for every changed file in scope, including whether the full file was reviewed and whether related codebase search was needed.
3. A stale/redundant check result.
4. A robustness check result.
5. Standards, lint, or test checks that were run, plus any checks that were skipped and why.
6. A final `Summary` section, written in Traditional Chinese, that briefly states the overall review reasoning, the reviewer's assessment of the update, any notable non-blocking risks or thoughts, or says there is nothing else worth calling out.
7. The final verdict, included inside `Summary` as `Verdict: ` followed by one of the required verdict labels.

Do not add a separate `Final Verdict` section; `Summary` is the final section and owns the verdict.
