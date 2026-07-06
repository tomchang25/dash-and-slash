# Tick Combat Rework 06d: Tick Wave Controller

## Goal

Replace the fixed tick-arena enemy set with calibrated wave progression. Spawns use player-action counted warnings, low concurrent caps, overflow queues, milestone elites, and existing run-build enemy pressure projections.

## Relational Context

- `WaveController` currently owns wave number, spawn queue, alive enemies, milestone detection, enemy-pressure reads, stat scaling, and Timer-driven wave/spawn gaps.
- `TickEngine` owns registered tick actors and must receive every spawned enemy through the same actor registration path as the current tick-arena fixed spawner.
- `EnemySpawner` currently instantiates enemies, calls their grid/player setup, connects death, and adds them to a parent; for tick arena it must also bind the tick engine and avoid depending on the legacy player type.
- `EnemySpawnPlanner` chooses cells from grid and player position; it must read the tick player's logical cell rather than a legacy player's global position.
- Spawn telegraphs should be counted by player actions. A queued spawn batch should reserve or revalidate its cells at detonation so occupancy changes during the warning cannot create illegal overlaps.
- `WaveScaling` currently uses real-time-era support-count and population-cap constants; this spec retunes total wave size and concurrent cap separately for tick pacing.
- `RunBuild` remains the source of future enemy count and enemy toughness pressure; the wave controller reads it but does not own reward state.

## Scope

### Included

- Tick-compatible wave controller setup and spawn flow.
- Player-action counted spawn warnings.
- Low concurrent cap and overflow queue draining.
- Milestone elite scheduling and enemy stat scaling.

### Excluded

- Spawn-weight data drive.
- New enemy kinds.
- Terrain mutation and reward UI integration beyond wave-complete signals.

## Files to Change

| File                                                   | Change Size | Purpose                                                                             |
| ------------------------------------------------------ | ----------- | ----------------------------------------------------------------------------------- |
| `game/scenes/stages/waves/wave_controller.gd`          | Large       | Convert spawn warning/gap flow to tick-compatible progression.                      |
| `game/scenes/stages/waves/wave_scaling.gd`             | Medium      | Retune support count, population cap, and scaling constants for tick pacing.        |
| `game/scenes/stages/waves/enemy_spawn_planner.gd`      | Medium      | Use tick player cell context and low-density spawn geometry.                        |
| `game/scenes/stages/waves/enemy_spawner.gd`            | Medium      | Bind spawned enemies to tick engine and remove legacy player assumptions.           |
| `game/scenes/stages/tick_arena/tick_run_controller.gd` | Medium      | Start waves, receive wave-complete signals, and stop using fixed enemy composition. |
| `game/scenes/stages/tick_arena/tick_engine.gd`         | Small       | Expose any narrow actor-registration support the spawner needs.                     |
| `test/unit/test_wave_controller.gd`                    | Large       | Update formulas, cap/queue, milestone, and tick spawn-warning tests.                |

## Implementation Notes

Initial total support count target is `3 + floor(wave / 2)` before future-enemy pressure. This replaces the real-time-era `5 + (wave - 1)` growth so early tick waves stay readable while still getting longer over time.

Initial concurrent cap target is `clamp(3 + floor(wave / 5), 3, 6)`. Keep wave total growth separate from concurrent cap so later waves can last longer without making a single board unreadable.

Represent spawn warnings in the same grid telegraph path as current spawn telegraphs, but do not let spawn telegraphs erase enemy attack danger.

When a spawn warning resolves into an occupied cell, choose a valid replacement cell if possible; if none exists, leave the spawn queued.

## Edge Cases

| Case                                             | Expected Handling                                                  |
| ------------------------------------------------ | ------------------------------------------------------------------ |
| Spawn cell becomes occupied during warning       | Revalidate and relocate or keep queued.                            |
| Player dies while spawns are queued              | Clear pending spawn telegraphs and stop queue drain.               |
| Elite wave support enemies exceed cap            | Queue overflow normally; elite scheduling remains milestone-owned. |
| Future-enemy pressure raises total above the cap | The wave size grows, but only cap-sized batches are alive at once. |

## Acceptance Criteria

1. Tick arena waves spawn through the wave controller rather than fixed scene constants.
2. Spawn warnings count down by player actions.
3. Wave total uses the tick-world support-count curve while concurrent enemies stay within the low tick-world cap.
4. Future enemy and toughness rewards affect later waves through the run-build store.
