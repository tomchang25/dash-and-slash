# Data-Driven Wave Progression And Enemy Levels 02: Group Runtime And Demo Completion

Parent Plan: `data_driven_wave_progression_and_enemy_levels.md`

## Goal

Explore the runtime migration from a flat support-and-elite queue to ordered conditional groups, including per-spawn level application, retirement of the existing enemy-pressure curse paths, the wave-10 boss placeholder, and the `Demo Complete` end-or-continue branch.

## Summary

The current wave owner likely remains the scene-local lifecycle authority, but its queue should represent only eligible authored groups. Group membership must survive warning, spawn, and death so predecessor thresholds are deterministic. The existing population cap and warning-cell revalidation behavior are valuable safety contracts to preserve.

The same cutover replaces every legacy enemy-strength path with the level projection established by Child 01. It also removes the four pressure artifacts and the forced single-curse confirmation so displayed level remains the only explanation for enemy numeric strength.

Wave 10 completion adds a second successful terminal state without ending the run automatically. Completion should be recorded before the choice appears, while the choice controls whether normal results close the run or the same build advances into the endless template.

## Sketch

- `WaveController` currently constructs one random support queue, appends an elite on milestone waves, schedules warning batches from global population headroom, and completes when queue, warning, and living-enemy state are empty. The later spec should replace queue construction and completion predicates while preserving safe batch revalidation and death-driven headroom refill.
- Candidate runtime state includes the active wave definition, eligible group indices, each group's unspawned entries, pending warning entries, and living-enemy membership by source group. Later groups must not become eligible merely because total alive count falls if their predecessor threshold is not met.
- A group should become eligible once and remain eligible. Its remaining members then drain through the existing warning-batch grammar as population headroom permits. An immediate-overlap successor can become eligible at the same wave start, but authored order still determines which group's entries claim limited headroom first.
- Group transition evaluation should run after relevant deaths and warning-batch resolution. It must handle empty groups without stalling and must never overwrite an in-flight warning batch.
- Wave completion requires every group to have become eligible, every authored entry to have spawned or been safely requeued, no warning batch to remain, and no living enemy from the wave to remain.
- Spawned enemies should receive their final integer level and typed projection before engine registration or visible activation. The level should be queryable for enemy presentation and debug inspection.
- The current scaling path mutates Health and stores damage and Defense while leaving Guard unchanged. The later spec should replace this compatibility path atomically with the Child 01 projection contract, including maximum/current HP and Guard initialization and deletion of the direct tier formula.
- The runtime cutover should remove Raise Pressure, Enemy Vitality, Enemy Ferocity, and Enemy Armor from authored rewards; remove their run-build channels and wave consumers; and remove the forced post-milestone single-curse confirmation. Normal and milestone reward selection otherwise remains intact.
- The boss placeholder should use a separately authored enemy variant with unmistakable color identity, boss display treatment, and an elevated group level offset. It may reuse Mode-enemy behavior, but runtime completion must identify the boss group through authored data rather than scene equality.
- Clearing the final wave-10 group should record demo completion once, freeze automatic wave advancement, and present `End Run` and `Continue Endless`. Input and enemy scheduling must remain safely paused while the branch is visible.
- `End Run` should route through the successful results path rather than player-death semantics. `Continue Endless` should dismiss the branch, preserve the current player build and state under normal between-wave rules, and select the authored endless template for wave 11.
- Resetting or dying while a group warning or completion branch exists must clear pending group state and presentation exactly as the current run reset clears the flat queue.
- Candidate files to inspect: the wave controller and its planner/spawner collaborators, the run controller and arena root, enemy spawn-stat and presentation paths, reward registry/content/run-build channels, completion overlays, and focused wave/reward lifecycle tests.

## Non-Goals

1. No final wave 1–10 encounter tuning or final level-curve constants.
2. No bespoke boss behavior beyond the Mode-enemy placeholder variant.
3. No post-wave-10 procedural encounter generation or changing endless grammar.
4. No replacement trade-off curses, forced three-choice curse offer, or Nemesis-style hunter.
5. No unrelated run-summary redesign beyond the successful demo-completion route needed by this plan.

## Acceptance Criteria

1. Ordered groups become eligible and spawn according to authored predecessor thresholds without bypassing population headroom or warning revalidation.
2. Every spawned enemy receives the correct visible level and all four projected stats before combat participation.
3. A wave completes only after all groups, queued entries, warning batches, and living members are exhausted.
4. Legacy tier scaling, all enemy-pressure rewards/channels, and the forced single-curse confirmation are absent after the cutover.
5. Wave 10 uses the distinct Mode-enemy boss placeholder and records demo completion exactly once.
6. `End Run` closes through successful completion, while `Continue Endless` preserves the build and advances to wave 11 under the endless template.
