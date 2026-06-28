# Pull Request Convention

A lightweight convention for PR titles and descriptions. Extends `conventional_commits.md` and `dev/standards/change_summary_standard.md` — read those first; this document only covers what differs at the PR level.

## Title

The PR title follows the same format as a commit subject line:

```
<type>[optional scope][!]: <description>
```

- Same types, scopes, and `!` breaking-change marker as `conventional_commits.md`.
- Describe the PR as a whole, not its largest commit. If the PR mixes types, pick the type of the primary change (a `feat` PR that includes incidental `fix`/`refactor` commits is still `feat:`).
- The title becomes the squash-merge commit subject, so it MUST stand alone in the git log: imperative mood, no trailing period, ideally ≤ 72 characters.

## Description

Use these sections, in this order. `## Summary` and `## Changes` are REQUIRED; the rest appear only when useful.

### `## Summary` (required)

1–3 sentences: what changed and why. Written for a reviewer with no context — lead with the problem or goal, not the implementation.

### `## Changes` (required)

The logical changes the PR makes. Format is free for simple PRs: use prose or a bullet list with one logical change per `-` bullet. Bullets, when used, follow the same imperative style as commit bodies (e.g. `- Add dodge-cancel windows to light attacks`). Summarize logical changes, not commits — the two need not map 1:1.

For a PR large enough to warrant grouping, use `###` subheadings inside `## Changes`. Do not use bold-label bullets as section substitutes (for example, avoid `- **Enemy AI** — ...` or `**Enemy AI** — ...`). Pick whichever grouping fits the PR; default to **by area** when in doubt:

- **By area / module** (default) — group bullets under `###` headings for the module or scene they touch (`### Grid enemy`, `### Player combat`, …). Matches how a reviewer reads the diff, so it's the safe choice for most PRs.
- **By feature / theme** — group under each self-contained sub-feature or theme (`### Dodge-cancel timing`, `### Incidental fixes`, …). Use only when one PR genuinely carries several independent strands; if the strands are fully independent, prefer splitting into separate PRs instead.

### `## Testing` (optional)

List commands run and any meaningful manual verification. If no tests were run, say so and explain why.

### `## Breaking changes` (when applicable)

Required whenever the title carries `!` or any commit has a `BREAKING CHANGE:` footer. State what breaks and the migration path (e.g. save-store migration version, YAML schema change requiring regeneration).

### `## Notes` (optional)

Anything the reviewer should know that isn't a change: known limitations, follow-up work, review focus areas, screenshots for UI changes.

## Rules

- The description describes _what changed in the codebase_ — follow `dev/standards/change_summary_standard.md` for tone, content, and administrative-housekeeping exclusions.
- Do not paste the commit list as the description; `## Changes` summarizes logical changes, which may not map 1:1 to commits.
- Do not hard-wrap prose at a column boundary — let the client wrap.
- Reference issues/plans with closing keywords where supported (e.g. `Closes #123`) at the end of the Summary, not as a separate section.

## Example

Simple PR:

```
feat(player): add dodge-cancel windows to light attacks

## Summary

Light attacks previously locked the player into the full animation, making combat feel sluggish. This adds a configurable dodge-cancel window to each light attack so the player can fluidly transition into a dodge.

## Changes

- Add dodge-cancel window to light attack animations
- Expose cancel timing in attack resource definitions
```

Grouped PR:

```
refactor(enemies): extract shared attack cell shape helpers

## Summary

Grid enemies duplicated attack-cell-shape helper logic across three enemy types, making it hard to add new attack patterns consistently. This consolidates the helpers into a shared utility.

## Changes

### Charge enemy

- Migrate charge-telegraph shape computation to shared helper
- Remove inline shape logic from charge attack state

### Puff enemy

- Migrate puff-area shape computation to shared helper
- Remove inline shape logic from puff attack state

### Grid enemy

- Migrate arc-attack shape computation to shared helper
- Remove inline shape logic from grid enemy attack state

## Testing

- `godot_console --headless --path /tmp/snapshot --test-unit`
- Manually verified attack telegraphs match visual grid overlay for all three enemy types
