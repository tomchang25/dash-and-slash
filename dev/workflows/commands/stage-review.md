Review the currently git-staged files against any referenced plan spec and the shared review standard.

## Scope

The review scope is staged files only. Do not include unstaged or untracked files unless they are needed as related codebase context.

## Steps

1. Read `dev/workflows/review_standard.md` and apply it to the staged-file scope.
2. Run `git diff --cached --name-only` to get staged files.
3. Run `git diff --cached --stat` for a summary.
4. If a plan/spec file is among the staged files under `dev/docs/plans/`, read it as the spec.
5. Read the full current contents of every staged file that can be reviewed as text, then read the staged diff with `git diff --cached -- <file>` to understand the exact staged changes.
6. Search related codebase context for changed APIs, constants, data IDs, node paths, signals, resources, command workflows, and standards references.
7. Run `python dev/tools/lint_standards.py --files <staged .gd files under game/>` when there are staged `.gd` files under `game/`.
8. Report findings and final verdict using `dev/workflows/review_standard.md`.
