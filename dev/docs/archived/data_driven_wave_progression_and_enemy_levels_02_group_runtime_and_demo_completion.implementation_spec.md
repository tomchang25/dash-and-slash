# Data-Driven Wave Progression And Enemy Levels 02: Group Runtime And Demo Completion

Parent Plan: `data_driven_wave_progression_and_enemy_levels.md`

## Goal

Replace the flat, formula-driven wave path with the authored group catalog, apply final enemy levels before combat begins, and complete the wave-10 demo branch. The result is a playable data-driven runtime with a minimal terminal outcome seam for later persistent progression.

## Summary

`WaveController` will consume an injected `WaveCatalog` instead of `WaveScaling` or `RunBuild` pressure. It expands only eligible authored groups, preserves each entry's group identity through warning, spawn, and death, and uses the current wave definition's population cap and warning timing without breaking the existing revalidation contract.

Each spawned `GridEnemy` receives one final level, calculated from the one-based wave number plus its group's authored offset. The existing pre-ready callback records the typed projection, then `GridEnemy` applies all four projected stats after its Level 1 data initialization and before it is combat-active. Its level appears only in the existing `Debug.enabled` enemy readout.

This child also removes the four pressure curses and their wave/build consumers, creates a distinct authored Mode boss placeholder, and turns wave 10 into `End Run` or `Continue Endless`. Death and `End Run` create the same scene-local `RunOutcome`; continuing opens the normal wave-10 milestone reward and then starts the fixed endless template. Coin, save writes, and permanent unlocks remain outside this spec.

## Relational Context

- `TickArena` is the composition root for the authored catalog and injects it through `TickRunController` into its scene-local `WaveController`; `WaveController` owns active-wave, group, warning, and living-enemy state, while `TickRunController` owns banners, rewards, demo choices, terminal results, restart, and navigation.
- `WaveCatalog` is the sole source of demo waves, endless template, cap, group order, conditions, warning ticks, level offsets, boss role, and progression profile. `WaveController` must not retain formula fallbacks, hardcoded enemy pools, milestone cadence, pressure reads, or scene-equality boss detection.
- Each runtime entry carries its originating group index from composition expansion through warning and living-enemy bookkeeping. Predecessor survivor checks read only the immediately preceding group's living membership; global alive count remains only the population-headroom input.
- Eligible groups never become ineligible. Eligibility is evaluated in authored order after wave start, warning resolution, and relevant deaths; a later group cannot become eligible before its predecessor has become eligible. When several groups are eligible, earlier groups claim headroom first, so overlap never bypasses unspawned entries from an earlier group.
- A warning batch remains the sole in-flight reservation. Revalidation failure requeues an entry with its original group identity and ordering; deaths during a warning only trigger a later scheduling pass and cannot replace the reserved batch.
- `EnemySpawner` already calls its pre-ready callback after enemy setup and tick binding but before adding/registering the enemy. `WaveController` supplies the level-projection callback there; `GridEnemy` records it pre-ready, initializes Level 1 state, then applies projected Health, Guard, Defense, and damage multiplier without mutating `EnemyData` or attack resources.
- `RunBuild` continues to own player reward state only. Removing pressure channels means it is no longer injected into or read by `WaveController`; the reward generator's generic curse support may remain dormant, but no production artifact or run-flow path may offer or confirm a curse.
- `TickRunController` updates highest completed wave before post-wave presentation. It creates exactly one `RunOutcome` per run identity on death or `End Run`; `Continue Endless` is not terminal. The later Meta Progression plan consumes this value but must not be implemented here.
- Result and demo overlays are presentation components. They emit intents to `TickRunController`; only the controller pauses/unpauses flow, resets the run, or calls `SceneRouter.go_to_main_menu()`.

## Scope

### Included

- Catalog-driven ordered-group scheduling, weighted expansion, headroom, warning revalidation, and wave completion.
- Pre-ready level projection and debug-only level readout.
- A valid provisional production catalog, boss placeholder, and data-owned boss role; Child 03 later replaces its encounter counts and curve values with final balance.
- Pressure-curse retirement, wave-10 branch, unified scene-local terminal outcome, and minimal results UI.
- Focused runtime, projection, reward-registry, and run-flow tests.

### Excluded

- Final waves 1–10 composition, endless balance, and level-curve tuning.
- Bespoke boss behavior, replacement curses, or any new enemy mechanism.
- Coin calculation, save-backed completion, character unlocks, artifact unlock filtering, or active-run persistence.
- Main Menu redesign beyond routing back through the existing route.

## Files to Change

| File                                                                                                                                        | Change Size | Purpose                                                                                                       |
| ------------------------------------------------------------------------------------------------------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------- |
| `data/waves/definitions/wave_group_definition.gd`                                                                                           | Small       | Add the authored boss-group role used by runtime and presentation.                                            |
| `data/waves/default_wave_catalog.tres`                                                                                                      | Large       | Add a valid provisional ten-wave catalog, endless template, and profile for runtime consumption.              |
| `game/tick_arena/wave/wave_controller.gd`                                                                                                   | Large       | Replace formula queueing with catalog-driven group scheduling and level callbacks.                            |
| `game/tick_arena/wave/wave_scaling.gd` and `.uid`                                                                                           | Small       | Delete the retired formula authority.                                                                         |
| `game/entities/enemies/grid_enemy.gd`                                                                                                       | Medium      | Replace deferred legacy scaling with deferred typed level application and debug readout.                      |
| `game/entities/enemies/mode_boss.tscn`                                                                                                      | Medium      | Add the visually distinct Mode-based boss placeholder.                                                        |
| `game/tick_arena/run/run_outcome.gd`                                                                                                        | Small       | Add the terminal outcome value shared by death and successful end.                                            |
| `game/tick_arena/run/demo_completion_overlay.gd`                                                                                            | Small       | Present `End Run` and `Continue Endless` intents.                                                             |
| `game/tick_arena/run/run_result_overlay.gd`                                                                                                 | Medium      | Present terminal result data and restart/main-menu intents.                                                   |
| `game/tick_arena/run/tick_run_controller.gd`                                                                                                | Large       | Own group-completion consequences, milestone reward continuation, terminal finalization, and overlay cleanup. |
| `game/tick_arena/tick_arena.gd` and `game/tick_arena/tick_arena.tscn`                                                                       | Large       | Inject the catalog and compose the boss, completion, and results scene UI.                                    |
| `game/tick_arena/run/run_build.gd`                                                                                                          | Small       | Remove enemy-pressure channels.                                                                               |
| `game/tick_arena/reward/build_inspection_formatter.gd`                                                                                      | Small       | Remove retired pressure rows and formatting.                                                                  |
| `data/rewards/default_artifact_registry.tres`                                                                                               | Small       | Remove pressure artifacts from the production reward catalog.                                                 |
| `data/rewards/artifacts/{future_enemy,enemy_health_pressure,enemy_damage_pressure,enemy_defense_pressure}.tres`                             | Small       | Delete the four retired pressure artifacts.                                                                   |
| `test/unit/test_wave_controller.gd`                                                                                                         | Large       | Replace formula/pressure coverage with catalog, group, warning, and completion coverage.                      |
| `test/unit/test_enemy_progression_data.gd`                                                                                                  | Medium      | Replace legacy bridge coverage with runtime level-application and boss-role validation coverage.              |
| `test/unit/test_run_outcome.gd`                                                                                                             | Small       | Cover terminal-reason and immutable snapshot data.                                                            |
| `test/unit/test_tick_run_controller_reward_sequence.gd`                                                                                     | Medium      | Preserve milestone offers while removing forced-curse expectations.                                           |
| `test/unit/test_wave_reward_choice_generator.gd`, `test/unit/test_artifact_registry.gd`, and `test/unit/test_build_inspection_formatter.gd` | Medium      | Remove pressure-artifact assumptions and verify the reduced production catalog.                               |

## Execution Outline

1. Add the group boss role and provisional valid catalog, including the Mode boss scene, so the new runtime has validated production data before it replaces the legacy path.
2. Rework `WaveController` around catalog selection, seeded weighted expansion, ordered eligibility, source-group membership, per-group warning batches, and authored completion/display state; delete `WaveScaling` and its `RunBuild` dependency.
3. Replace GridEnemy's legacy scaling bridge with typed projection application and debug-only level text, then connect the wave callback through the unchanged pre-ready spawn boundary.
4. Retire pressure channels, authored artifacts, registry entries, inspection rows, and forced curse confirmation while preserving normal and milestone reward offers.
5. Add `RunOutcome`, demo-choice/results overlays, and the run-controller state transitions; wire scene nodes and catalog injection from the arena root.
6. Rewrite focused tests around the new contracts, run the standards linter on all touched scripts, run focused unit tests, and manually verify warning, demo branch, restart, and route behavior in the editor.

## Implementation Notes

- The provisional catalog must validate and keep the arena playable: ten demo definitions, one endless definition, non-zero caps and warning ticks as appropriate, a non-zero group level offset on the wave-10 boss group, and a valid profile. It is structural bootstrap content, not Child 03's reviewed encounter or numeric balance.
- Expand fixed entries in authored entry order. For weighted groups, draw exactly `weighted_total_count` entries from the injected per-run wave RNG; seed it separately from the reward RNG so reward choices cannot alter encounter composition. Tests use a fixed seed.
- Record group ownership for pending and living entries. A group can be eligible while its earlier predecessor still has unspawned entries, but the scheduler must drain eligible groups in authored order; predecessor threshold checks never use enemies from another group.
- `PREVIOUS_GROUP_CLEARED` means the preceding group's living count is zero. `PREVIOUS_GROUP_SURVIVORS_AT_MOST` compares that same count to its authored threshold. The first group is eligible by position, and chained immediate-overlap groups may all become eligible at wave start.
- A group with `warning_ticks == 0` resolves its batch immediately without creating a telegraph; positive values preserve the existing world-advance countdown and revalidation behavior.
- Add one `is_boss` group flag and carry it into spawned entries. Wave display and boss treatment may use this authored role, but no runtime path may compare a scene against the boss scene to determine boss behavior or demo completion.
- `GridEnemy` stores final level plus projection until `_ready()` has initialized authored bases. Applying the projection initializes projected max/current HP and Guard, sets Defense and damage multiplier, and leaves `EnemyData`/attack data immutable. Extend the existing debug FSM label with the level only when `Debug.enabled`; do not add normal HUD or enemy-name level UI.
- The wave-10 branch appears after the existing wave-end banner. `End Run` finalizes successfully; `Continue Endless` opens the wave-10 milestone offer and then starts wave 11 after a choice. Milestone offers retain Minor x2 / Major fallback shape but never open a curse confirmation.
- Both death and `End Run` first cancel banner/reward/demo presentation, stop wave scheduling, lock combat input, and snapshot the same run data. Results pause safely, expose restart and main-menu intents, and reset must clear result/demo state, run-finalization guard, wave group state, warning telegraphs, and highest-completed-wave state.
- The demo and result overlays must remain interactive while the scene tree is paused; their scripts expose presentation signals only and must never navigate or reset the run directly.

## Edge Cases

| Case                                                 | Expected Handling                                                                                       |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Catalog missing or invalid                           | Report a development error and do not start or advance a wave; never fall back to `WaveScaling`.        |
| A later group has an ineligible predecessor          | It remains blocked even if global alive count reaches zero.                                             |
| Multiple deaths occur while a warning is visible     | The reserved batch survives unchanged; the next scheduling pass runs only after it resolves.            |
| A group has zero warning ticks                       | Spawn it through the same cell-validation path immediately, with no stale telegraph or later countdown. |
| No valid cell exists when a warning resolves         | Requeue the entry in its source group without clearing its role or level offset.                        |
| Death during warning, banner, reward, or demo branch | Cancel all transient presentation and group state, create one death outcome, and show only results.     |
| Repeated End/Continue/result button input            | Ignore intents once the run has finalized or the relevant overlay is no longer active.                  |
| Reset from results                                   | Begin a fresh run identity with no completion/outcome state and no stale paused tree.                   |

## Acceptance Criteria

1. Ordered groups enter only after their authored predecessor condition, drain in authored order under the authored population cap, and preserve warning revalidation without dropping entries.
2. Every spawned enemy receives wave-plus-offset level and projected HP, damage, Guard, and Defense before combat participation; level is inspectable only with debug enabled.
3. A wave completes only after all eligible groups, queued entries, warnings, and living group members are exhausted.
4. No formula scaling, pressure channel, pressure artifact, or forced curse confirmation remains reachable in production.
5. Wave 10 uses a visually distinct Mode boss placeholder identified by authored group role, marks run-local demo completion once, and pauses safely for `End Run` or `Continue Endless`.
6. `End Run` and player death create exactly one terminal outcome with correct reason, selected character, highest completed wave, and demo-completion state.
7. `Continue Endless` does not finalize the run, preserves its build, awards the normal wave-10 milestone choice without a curse, and starts the unchanged endless template at wave 11.
8. Results support restart and normal Main Menu routing while exposing no Coin, save, or permanent-unlock behavior.
