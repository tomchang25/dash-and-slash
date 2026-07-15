# Git Operations — Read-Only

The shared default lives at `dev/foundation/core/agent_rules/git_operations.md`. This project explicitly overrides it because the sandbox mount can desynchronize `.git/`: agents must keep Git read-only even when a normal foundation consumer could accept an explicit mutation request.

Agents must NEVER run git commands that mutate repo state: no `git add`, `commit`, `restore`, `reset`, `stash`, `checkout`, `rm`, or `mv`. The sandbox mount desyncs on `.git/` (phantom `index.lock`, EEXIST on files that don't exist), so staging attempts fail unpredictably and waste tokens.

## Rules

- Read-only git is fine and reliable: `status`, `diff`, `log`, `show`, `ls-files`, `cat-file`, `check-ignore`.
- If a read-only git command fails with Git's dubious ownership / `safe.directory` protection in this Windows workspace, retry the same read-only command once with `git -c safe.directory=E:/GodotProjects/dash-and-slash ...` instead of concluding that the current directory is not a git repository.
- Keep git inspection proportional and targeted. Prefer path-scoped `git status --short -- <files>` or `git diff -- <files>` only when it helps confirm the changed surface, line-ending noise, or unexpected edits; do not run broad diffs as a ritual for docs-only work.
- When work is done, at most **suggest a commit message** (format per `dev/skills/conventional_commits.md`). The user stages and commits themselves.
- Never retry a failed git mutation "one more way" — stop at the first failure and hand off to the user.
