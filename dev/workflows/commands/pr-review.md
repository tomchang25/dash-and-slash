# pr-review - review branch and generate PR title and description

Review the current branch against the base branch, then generate a pull request title and description.

Steps:

1. Read `dev/skills/pr_convention.md` for the required format if present, and `dev/skills/conventional_commits.md` if type/scope rules are unclear.
2. Read `dev/workflows/review_standard.md` and apply it to the branch/PR scope.
3. Inspect the branch with read-only git: `git log --oneline <base>..HEAD`, `git diff <base>...HEAD --name-only`, and `git diff <base>...HEAD --stat` (assume base is `main` unless I say otherwise; never stage, commit, or push).
4. Read the full current contents of every changed file that can be reviewed as text, then read the branch diff with `git diff <base>...HEAD -- <file>` to understand the exact PR changes.
5. Search related codebase context for changed APIs, constants, data IDs, node paths, signals, resources, command workflows, and standards references.
6. Report review findings and final verdict using `dev/workflows/review_standard.md` before drafting PR text.
7. Write the PR title (conventional style, describing the PR as a whole) and description (`## Summary`, `## Changes`, plus `## Testing` / `## Breaking changes` / `## Notes` only when applicable).
8. Output the title and description in a single copy-pasteable block. Do not create files or open a PR.

Reminders: follow `dev/standards/change_summary_standard.md`, don't paste the raw commit list as Changes, don't hard-wrap prose.

$ARGUMENTS
