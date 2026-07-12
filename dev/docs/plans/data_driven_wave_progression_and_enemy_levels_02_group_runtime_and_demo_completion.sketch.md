# Data-Driven Wave Progression And Enemy Levels 02: Group Runtime And Demo Completion

Parent Plan: `data_driven_wave_progression_and_enemy_levels.md`

## Goal

Explore the runtime migration from a flat support-and-elite queue to ordered conditional groups, including per-spawn level application, the wave-10 boss placeholder, and the `Demo Complete` end-or-continue branch.

## Summary

The current wave owner likely remains the scene-local lifecycle authority, but its queue should represent only the currently eligible group. Group membership must survive warning, spawn, and death so predecessor thresholds are deterministic. The existing population cap and warning-cell revalidation behavior are valuable safety contracts to preserve.

Wave 10 completion adds a second successful terminal state without ending the run automatically. Completion should be recorded before the choice appears, while the choice controls whether normal results close the run or the same build advances into the endless template.

## Sketch

- `WaveController` currently constructs one random support queue, appends an elite on milestone waves, schedules warning batches from global population headroom, and completes when queue, warning, and living-enemy state are empty. The later spec should replace queue construction and completion predicates while preserving safe batch revalidation and death-driven headroom refill.
- Candidate runtime state includes the active wave definition, current group index, current group's unspawned entries, pending warning entries, and living-enemy membership by group. Later groups must not become eligible merely because total alive count falls if their predecessor group survivor threshold is not met.
- A group should become eligible once and remain eligible. Its remaining members then drain through the existing warning-batch grammar as population headroom permits. An immediate-overlap successor can become eligible at the same wave start, but authored order still determines which group's entries claim limited headroom first.
- Group transition evaluation should run after relevant deaths and after warning batches resolve. It must also handle an empty group without stalling and must not overwrite a pending warning batch.
- Wave completion requires every group to have become eligible, every authored entry to have spawned or been safely requeued, no warning batch to remain, and no living enemy from the wave to remain.
- Spawned enemies should receive their final integer level and all projected stats before engine registration or visible activation. The level should be queryable for enemy presentation and debug inspection.
- The current scaling path mutates health and stores outgoing-damage and Defense values while leaving Guard unchanged. The later spec should replace it atomically with level projection, including maximum/current Guard initialization and removal of the legacy direct tier adjustment.
- Reward-driven future-enemy count needs a deterministic target under grouped data. The favored interpretation is extra entries in the current eligible non-boss support group, constrained by the same cap and never allowed to manufacture extra boss entries or skip group gates.
- The boss placeholder should use a separately authored enemy variant with unmistakable color identity, boss display treatment, and an elevated group level offset. It may reuse Mode-enemy behavior, but runtime completion must identify the boss group through data rather than scene equality.
- Clearing the final wave-10 group should record demo completion once, freeze automatic wave advancement, and present `End Run` and `Continue Endless`. Input and enemy scheduling must remain safely paused while the branch is visible.
- `End Run` should route through the successful results path rather than player-death semantics. `Continue Endless` should dismiss the branch, preserve the current run build and player state under normal between-wave rules, and select the authored endless template for wave 11.
- Resetting or dying while a group warning or completion branch exists must clear pending group state and presentation exactly as the current run reset clears the flat queue.
- Candidate files to inspect: `game/tick_arena/wave/wave_controller.gd`, `game/tick_arena/run/tick_run_controller.gd`, `game/tick_arena/tick_arena.gd`, spawn planner/spawner collaborators, `game/entities/enemies/grid_enemy.gd`, HUD and overlay scenes, and focused wave lifecycle tests.

## Non-Goals

1. No final wave 1–10 encounter tuning or final level-curve constants.
2. No bespoke boss behavior beyond the Mode-enemy placeholder variant.
3. No post-wave-10 procedural encounter generation or changing endless grammar.
4. No unrelated run-summary redesign beyond the successful demo-completion route needed by this plan.

## Acceptance Criteria

1. Ordered groups become eligible and spawn according to authored predecessor thresholds without bypassing population headroom or warning revalidation.
2. Every spawned enemy receives the correct visible level and all four projected stats before combat participation.
3. A wave completes only after all groups, queued entries, warning batches, and living members are exhausted.
4. Wave 10 uses the distinct Mode-enemy boss placeholder and records demo completion exactly once.
5. `End Run` closes through successful completion, while `Continue Endless` preserves the build and advances to wave 11 under the endless template.
