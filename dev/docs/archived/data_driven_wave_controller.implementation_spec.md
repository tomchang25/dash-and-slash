# Data-Driven Wave Controller Implementation Spec

## Goal

Implement the data-driven wave controller slice of the first-pass roguelite wave reward loop: four normal waves, a wave 5 boss with support enemies, and reward-driven future enemy pressure.

## Relational Context

- The stage scene coordinates combat flow, HUD labels, wave banners, reward timing, enemy spawning, and run completion; it should call the wave controller for wave progression and spawn counts rather than owning fixed wave branching itself.
- The wave controller owns scene-local run wave state: current wave index, future support enemy modifier, and available support enemy pool. This state is discarded with the active stage scene and does not need save/checkpoint ownership in this phase.
- Reward application writes future enemy pressure through the wave controller. The reward applier should not own or duplicate wave state; it only calls the mutation entry point passed by the stage scene.
- Terrain truth remains owned by the grid authority. Reward terrain effects must continue to ask the grid to mutate terrain and must not copy terrain state into the wave controller.
- Player stat truth remains owned by the player/stat components. Reward stat effects must continue to mutate the player stat owner and must not pass through the wave controller.
- Enemy lifetime remains owned by enemy scripts and their health/state-machine flow. The stage scene may request forced support enemy death during boss resolution, but it must not directly bypass enemy cleanup with raw freeing.
- Boss wave completion changes from “all spawned enemies are dead” to “boss dies, remaining support enemies are force-cleared, then the run completes.” Normal wave completion remains “all enemies are dead, then open rewards.”
- Boss count and support enemy count are separate contracts. Future enemy pressure increases normal/support enemy counts only and never increases the boss count.
- Spawn telegraphs and pending spawn reservations are stage-scene transition state. Boss resolution must clear any pending support spawns or telegraphs that would otherwise materialize after the boss has died.

## Scope

### Included

- Data-driven wave definitions for four normal waves and one boss wave.
- Boss support enemy spawning affected by future enemy pressure.
- Boss death resolution that force-clears remaining support enemies before run completion.
- A focused enemy-side force-death entry point if needed to preserve existing death cleanup.

### Excluded

- YAML or designer-authored wave data.
- Save/load or checkpoint persistence for run wave state.
- Enemy spawn weighting, enemy unlock economy, or mid-wave spawning.
- Real Major reward behavior beyond the existing placeholder.

## Files to Change

| File                                          | Change Size | Purpose                                                                                                                                      |
| --------------------------------------------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `game/scenes/stages/dash_and_slash_arena.gd`  | Large       | Integrate wave controller state, spawn normal/support enemies and boss separately, and resolve boss death by force-clearing support enemies. |
| `game/scenes/stages/waves/wave_controller.gd` | Medium      | New scene-local controller for wave definitions, current wave progression, support enemy pool, and future enemy modifier.                    |
| `game/entities/enemies/grid_enemy.gd`         | Small       | Add a public forced-death path that enters the existing death cleanup flow instead of bypassing enemy ownership.                             |
| `test/unit/test_wave_controller.gd`           | Medium      | Cover wave progression, pressure-modified support counts, and fixed boss count behavior.                                                     |

## Implementation Notes

Use a scene-local RefCounted wave controller with hand-authored wave definitions. Normal definitions need an index, kind, and base support count. The boss definition needs an index, kind, fixed boss scene/id, and support base count.

The stage should build a spawn plan from the current wave definition. For normal waves, spawn only support enemies. For boss waves, spawn the fixed boss plus support enemies. Existing enemy spawn-cell selection can stay in the stage scene.

Boss death should set a boss-resolution guard before force-clearing support enemies so support enemy `died` signals cannot re-enter normal wave completion or complete the run early. Iterate over a duplicate support enemy list, request forced death through the enemy API, then complete the run after the alive list and grid occupancy are consistent.

The forced-death enemy API should route through the same death state used by combat death. Do not make the stage scene call health internals or `queue_free` enemies directly.

## Edge Cases

| Case                                                    | Expected Handling                                                                    |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Boss dies while support spawn telegraphs are pending    | Pending support spawns and telegraphs are cleared and no new support enemies appear. |
| Support enemy death signals fire during boss resolution | The resolution guard prevents reward opening or duplicate run completion.            |
| Future pressure is gained after wave 4                  | Boss support enemy count increases, while boss count stays one.                      |
| No valid support spawn cells remain                     | Existing spawn fallback behavior is preserved.                                       |

## Acceptance Criteria

1. The run progresses through four normal waves and then a wave 5 boss wave.
2. Normal and boss-support enemy counts use wave base counts plus accumulated future enemy pressure.
3. The boss wave always spawns exactly one boss.
4. Killing the boss force-clears remaining support enemies before the run completes.
5. Normal wave clears still open exactly three reward choices before the next wave starts.
6. Future enemy pressure from rewards affects later normal/support spawns without increasing boss count.
