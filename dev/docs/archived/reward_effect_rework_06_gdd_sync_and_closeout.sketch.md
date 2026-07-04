# Reward Effect Rework — GDD Sync and Closeout

## Goal

Once Phases 1 through 5 have shipped, update the project's design document so it describes the new Tile Op cadence and the now-resolved Chain Dash/Smash exclusivity question instead of the rules they supersede, then run this project's standard closeout workflow so the plan stops being a second source of truth once its design is folded into the design document and the code.

## Requirements

1. The design document's terrain section no longer describes Move Land / Break Land as pickable reward cards with a per-wave removal cap — that rule no longer exists in code after Phase 2. It instead describes the fixed, automatic, once-per-wave Tile Op that replaced it.
2. The design document's open-question section no longer lists Chain Dash vs. Smash mutual exclusivity as unresolved — Phase 5 answers it (mutually exclusive), via the exclusivity-group mechanism, even though neither ability is implemented yet. The document should say the question is resolved and point at the mechanism, not claim the abilities themselves exist.
3. The design document's Major/Minor description reflects that the unified per-effect-object architecture, the run-scoped applied-effect store with stat projection, and the Major cap/exclusivity scaffold are now implemented, while ability overrides and triggered effects are explicitly still not — a reader should not conclude more is built than actually is.
4. This phase makes no new design decisions of its own — every claim it adds to the design document is already decided by Phases 1 through 5 and this plan's own Requirements/Design sections. If a GDD edit would require a decision this plan hasn't already made, that's a signal the edit belongs to a different, later piece of work, not this one.
5. After the design document is synced, this project's standard closeout workflow runs for the whole plan: the shipped scope is recorded in the shipped-work history, this plan's pointer is removed from the open-work list, and this plan's phase files move to the shipped-work archive.

## Sketch (non-normative)

GDD edits (in `dash_and_slash_gdd_v0_4.md`):

- The terrain-effect classification table: remove the "kept as random reward-pool pressure" framing from the Move Land / Break Land rows; describe them as the fixed once-per-wave Tile Op instead (cadence, the two fixed shapes, and that it no longer appears in the reward-choice screen).
- The already-decided-rules section: replace the old "Break Land capped per wave" bullet with the new Tile Op's cadence/shape description.
- The open-questions section: move the Chain Dash/Smash exclusivity question out of "unresolved" and into "decided" — mutually exclusive, enforced via an exclusivity-group check, abilities themselves still unbuilt.
- The terminology/glossary entry for the player's run-build container: note that the applied-effect store (with minor stat projection) and the Major cap/exclusivity pieces are implemented, that reward effects are now unified self-contained objects rather than an effect-type enum, and that ability overrides and triggered effects are not.

Closeout sequence (follow this project's existing closeout command exactly — see `dev/workflows/commands/closeout.md`; nothing here overrides its rules):

1. Identify this plan's phase files under `dev/docs/plans/`.
2. Append one CHANGELOG entry (or a small tightly-scoped few, only if the shipped work has clearly separate user-visible outcomes) summarizing the reward-effect rework.
3. Remove this plan's one-line pointer from `TODO.md`.
4. Move this plan's main file and every phase file to `dev/docs/archived/`.
5. Confirm the resulting state, and leave the actual commit/PR steps to whatever the project's normal git workflow is at that time — this phase does not itself stage, commit, or push anything.

## Non-Goals

1. No new design decision is made in this phase — it only transcribes decisions Phases 1 through 5 already made into the design document.
2. This phase does not redefine what the closeout workflow produces (CHANGELOG wording, archive timing, commit-message suggestion) — it defers entirely to that workflow's own existing rules.

## Acceptance Criteria

1. The design document's terrain section and its Chain Dash/Smash open-question entry both match shipped behavior, with no remaining contradiction between the document and the code.
2. Running closeout after all five prior phases ship leaves no open-work pointer to this plan and no phase file from this plan outside the shipped-work archive.
