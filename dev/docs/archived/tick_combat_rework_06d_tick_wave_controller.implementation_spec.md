# Tick Combat Rework 06d: Tick Wave Controller

## Goal

Replace the fixed tick-arena enemy set with calibrated wave progression. Spawns use player-action counted warnings, low concurrent caps, overflow queues, milestone elites, and existing run-build enemy pressure projections.

## Relational Context

- `WaveController` currently owns wave number, spawn queue, alive enemies, milestone detection, enemy-pressure reads, stat scaling, and Timer-driven wave/spawn gaps; this spec keeps wave-number, queue, alive-enemy, milestone, pressure, and scaling ownership there, but removes Timer-driven spawn timing from the tick path.
- `TickRunController` owns when a wave starts and what happens after a wave completes; `WaveController` should emit wave-started/wave-completed signals and should not open rewards, mutate terrain, show death UI, or own restart flow.
- `TickEngine` owns tick count, actor scheduling, and registered actor truth; `WaveController` may ask spawned enemies to register with the engine through a narrow spawner/bind path, but it must not duplicate the engine's scheduling state.
- `TickEngine.world_advanced` is the clock source for spawn warnings. Free actions do not call `advance_world()`, so they do not emit `world_advanced` and therefore do not reduce spawn warnings.
- `EnemySpawner` currently instantiates enemies, calls their grid/player setup, connects death, and adds them to a parent; for the tick arena it must also bind enemies to the tick engine before or immediately after they enter the tree and must avoid depending on the legacy `Player` type.
- `EnemySpawnPlanner` currently derives the player cell from a legacy player's global position; in the tick arena it must read an explicit player-cell provider or `TickPlayer.cell`, because the logical cell is authoritative while tweens are visual.
- Spawn warnings use `GridArena.TelegraphPhase.SPAWNING` through the same telegraph storage as enemy danger, with a distinct source object so spawn telegraphs can be cleared without erasing enemy attack telegraphs.
- Spawn cells chosen for a warning are reservations for presentation only, not guaranteed final spawn truth; when the warning resolves, each cell must be revalidated against current land, player cell, and living enemy occupancy.
- `WaveScaling` currently uses real-time-era support-count and population-cap constants; this spec retunes total support count and concurrent cap separately for tick pacing.
- `RunBuild` remains the source of future enemy count and enemy toughness pressure. The wave controller reads run-build totals when preparing a wave or applying scaling; reward effects write to the store elsewhere.
- Milestone elite scheduling remains wave-owned: milestone waves include one elite in addition to support count, but the concurrent cap still governs how many enemies may be alive at once.
- Existing enemy death signals remain the wave controller's alive-count input. When a player hit kills an enemy, the action controller or engine path must still lead to the wave controller's death callback so queue draining and wave completion stay correct.

## Scope

### Included

- Tick-compatible wave start, spawn queue, alive-enemy tracking, and wave completion.
- Player-action counted spawn warnings driven by `world_advanced`.
- Total support-count retune, low concurrent cap, and overflow queue draining.
- Milestone elite scheduling and enemy stat scaling from wave tier plus run-build pressure.
- Test updates for formulas, queueing, spawn-warning countdown, revalidation, and completion.

### Excluded

- Spawn-weight data drive or pattern director.
- New enemy kinds.
- Reward UI, terrain mutation, death overlay, or restart flow beyond signals consumed by later specs.
- File/folder relocation.

## Files to Change

| File                                                      | Change Size | Purpose                                                                                                  |
| --------------------------------------------------------- | ----------- | -------------------------------------------------------------------------------------------------------- |
| `game/scenes/stages/waves/wave_controller.gd`             | Large       | Convert Timer-driven spawn flow into tick-warning flow while keeping wave/queue/alive/scaling ownership. |
| `game/scenes/stages/waves/wave_scaling.gd`                | Medium      | Retune support count, population cap, and tests for tick pacing.                                         |
| `game/scenes/stages/waves/enemy_spawn_planner.gd`         | Medium      | Use logical tick player cell context and low-density spawn geometry.                                     |
| `game/scenes/stages/waves/enemy_spawner.gd`               | Medium      | Bind spawned enemies to tick engine and remove legacy player assumptions.                                |
| `game/scenes/stages/tick_arena/tick_run_controller.gd`    | Medium      | Start waves, pass dependencies, receive completion, and stop using fixed enemy composition.              |
| `game/scenes/stages/tick_arena/tick_engine.gd`            | Small       | Expose or preserve narrow actor registration hooks needed by tick spawning.                              |
| `game/scenes/stages/tick_arena/tick_action_controller.gd` | Small       | Ensure enemy kills notify the wave controller path used for alive-count tracking.                        |
| `test/unit/test_wave_controller.gd`                       | Large       | Update formulas, cap/queue, milestone, spawn-warning countdown, revalidation, and completion tests.      |

## Implementation Notes

The wave lifecycle should be: the run controller requests the next wave, the wave controller advances the wave number, prepares the full spawn queue, emits wave started, schedules the first warning batch up to current headroom, counts that warning down on `world_advanced`, revalidates cells when the countdown reaches zero, spawns valid enemies, then schedules more batches whenever deaths create headroom. The wave completes only when the spawn queue is empty, no warning batch is pending, and no alive enemies remain.

Initial total support count target is `3 + floor(wave / 2)` before future-enemy pressure. Future-enemy pressure adds to this support total and therefore increases wave duration, not simultaneous density.

Initial concurrent cap target is `clamp(3 + floor(wave / 5), 3, 6)`. The cap counts all living wave enemies, including milestone elites. If a milestone elite plus support enemies exceed the cap, overflow remains queued.

Spawn warning duration starts at 2 world advances. Store it as an integer tick countdown on the current warning batch rather than a Timer. A free move/attack or mobility refund must not reduce this countdown because no world advance occurred.

Do not keep the old wave-gap Timer in the tick wave controller. Between-wave UI timing belongs to the run controller and reward/death integration specs.

When scheduling a warning batch, choose cells for at most `population_cap - alive_count` entries and place one SPAWNING telegraph source over those cells. Do not schedule a second warning batch while one is pending; deaths during a pending warning should only create headroom that the next scheduling pass can use after the current batch resolves.

When a warning resolves, clear its SPAWNING telegraphs before spawning. For each entry, revalidate its cell. If the cell is no longer valid, ask the spawn planner for a replacement using already accepted cells from this resolving batch as reserved cells. If no valid replacement exists, push that entry back onto the front of the queue so it can try again later.

Enemy stat scaling remains applied at spawn time. Health multiplier, damage multiplier, and defense are wave-tier values plus non-negative run-build pressure. Guard still does not scale.

The spawn planner should prefer readable geometry over density: cells far enough from the player to be legible, spread away from other cells in the same batch, and never on the player or an occupied enemy. Exact scoring can stay simple, but it must use the tick player's logical cell.

## Edge Cases

| Case                                                      | Expected Handling                                                                          |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Spawn cell becomes occupied during warning                | Revalidate and relocate; if no valid cell exists, return that entry to the queue.          |
| Player moves onto a spawn-warning cell before it resolves | The spawn relocates or requeues; it never spawns on the player.                            |
| Death creates headroom while a warning batch is pending   | Do not overwrite the pending batch; schedule more only after the current batch resolves.   |
| Player dies while spawns are queued or warning            | Clear pending spawn telegraphs and stop queue drain through the run-controller death path. |
| Elite wave support enemies exceed cap                     | Queue overflow normally; the elite is still part of the milestone wave plan.               |
| Future-enemy pressure raises total above the cap          | The wave size grows, but only cap-sized batches are alive or warning at once.              |
| Spawn planner cannot find any valid cell                  | Keep the entry queued and avoid soft-locking; later movement or kills can create space.    |
| Spawn warning overlaps enemy attack danger                | Both sources remain tracked; clearing spawn warning does not clear attack danger.          |

## Acceptance Criteria

1. Tick arena waves spawn through the wave controller rather than fixed scene constants.
2. Spawn warnings count down by player actions that advance the world and do not count down on free actions.
3. Wave total uses the tick-world support-count curve while concurrent enemies stay within the low tick-world cap.
4. Overflow enemies queue and drain as kills create headroom, without overwriting pending spawn-warning batches.
5. Spawn warnings revalidate their cells on resolution and never spawn onto the player or a living enemy.
6. Milestone waves include elite scheduling and still obey the concurrent cap.
7. Future enemy and toughness rewards affect later waves through the run-build store.
