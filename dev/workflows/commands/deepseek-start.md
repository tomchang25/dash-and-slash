# deepseek-start — load request-relevant rules

Prepare for the user's request by reading the repo startup instructions and every rule, standard, workflow, skill, or doc that is relevant to the request before acting.

This command is a startup and context-loading workflow. It does not replace the specific workflow for any later slash command; if the request names another command, read that command workflow too.

## Input

The user may provide a free-form request after the command:

```text
/deepseek-start [request]
```

Treat the text after the command as the request whose relevant rules must be loaded and followed.

## Required Reading

Always read, in this order:

1. `AGENTS.md`
2. `dev/agent_rules/agent_startup.md`

Then read every request-relevant file referenced by those startup instructions, including applicable files under:

1. `dev/agent_rules/`
2. `dev/workflows/`
3. `dev/standards/`
4. `dev/skills/`
5. `dev/docs/`

## Steps

1. Identify the user's requested task from `$ARGUMENTS`.
2. Read `AGENTS.md` and `dev/agent_rules/agent_startup.md` before answering or editing.
3. From the request and startup instructions, identify all relevant rules, standards, workflows, skills, and docs.
4. Read the relevant files before acting. If a matching slash-command workflow exists under `dev/workflows/commands/`, read it and follow it exactly.
5. If the request is ambiguous and the startup rules require clarification, ask the user before implementing.
6. Carry out the request while following every loaded instruction.
7. Before finishing, run the verification required by the loaded rules and the changed surface.

## Guardrails

- Do not claim a rule, standard, workflow, skill, or doc was followed unless it was read or already present in context.
- Do not bulk-read unrelated files just to appear exhaustive; relevance is based on the user's request, discovered references, and changed surface.
- Do not skip more specific command workflows. This command loads startup context; it does not override command-specific workflows.

$ARGUMENTS
