# Tick Arena Enemy Combat Roles And Counterpressure 05: Ranged Enemy Cross Pressure

Parent Plan: `tick_arena_enemy_combat_roles_and_counterpressure.md`

## Goal

Add one stable Ranged role that creates cross-board pressure from a readable distance band and retreats when crowded, breaking the all-enemies-chase convergence without introducing hidden attack variants.

## Summary

Ranged is a Small-profile enemy with Level 1 HP 100, Defense 0, Guard 32, tick speed 75, and one 10-damage attack. It may commit from Manhattan distance three through five, never from the adjacent ring, and ordinary attack commitment does not require it to first spend a facing action. Telegraph start immediately faces the target cell. The shared hit-triggered FaceOnce response still applies outside committed windup.

At commitment, Ranged snapshots the player's cell and locks a five-cell Cross consisting of that center plus its four orthogonal neighbors. The two-tick warning, danger countdown, and detonation all use that exact snapshot; later movement never retargets it. Bounds clip the Cross, while terrain, occupants, and reservations do not block it.

The role reuses the SmallEnemy telegraph, recovery, Guard/Stagger/death cleanup, and visual-presentation scaffold with a feature-owned Ninja Adventure Eye sheet. A fixed one-enemy Wave 1 group follows the existing Bomb group with one spawn-warning tick and population headroom five, exposing Ranged for provisional manual testing without adding it to weighted or endless composition.

## Relational Context

- `RangedEnemy` extends `SmallEnemy`, reusing its controller, telegraph, tick speed, detonation/recovery, and cancellation hooks while replacing attack selection, range planning, target-centered preparation, and arrival commitment.
- `GridEnemy` owns paths and reservations; its distance-band planner calls the unchanged stateless `EnemyPathPlanner`, blocks the player cell, reserves an attack destination, chooses the shortest reachable band cell with existing deterministic tie-breaks, and never falls back to melee approach.
- `EnemyIdleState` commits immediately because Ranged has no facing gate, and `EnemyRepositionState` commits on band entry. `EnemyFaceOnceState` remains the funded hit response and may commit afterward; the Ranged commit itself immediately faces the target cell without spending an action, while no state owns countdowns.
- `ranged_enemy.tres` solely authors HP 100, Defense 0, Small Guard, one TILE attack, damage 10, warning two, recovery one, and five symmetric `CUSTOM_OFFSETS`; invalid attack counts fail safely instead of selecting a fallback variant.
- Ranged transforms those offsets around the live player cell with a canonical orientation, immediately faces that cell for the telegraph, and passes the cells to `EnemyAttackController.prepare_cells()`. The controller feeds `EnemyTickRuntime`, which solely owns committed cells/countdown/recovery; `TickEngine` resolves the player's post-action cell and `TickArena` paints the same danger payload.
- Cross cells are bounds-clipped only; terrain and occupants neither block them nor become damage targets.
- `ranged_enemy.tscn` inherits the Thrust component tree and Small presenter scaffold while overriding behavior, data, and Eye texture. The PNG becomes a feature-owned asset; no runtime path or `.import` metadata comes from the ignored vendor tree.
- `default_wave_catalog.tres` remains encounter authority: Wave 1 is support -> Bomb -> Ranged in authored immediate-overlap order with cap five. Ranged remains absent from weighted and endless composition.
- Focused tests lock planning, commitment, hit response, footprint lifecycle, cleanup, data/scene wiring, and provisional catalog behavior.

## Scope

### Included

- Add Ranged behavior, scene/data, Eye identity, shared distance-band planning, focused coverage, and one fixed Wave 1 test group after Bomb with cap five.

### Excluded

- Charge facing changes, formations, final balance, weighted/endless integration, variants, projectiles, line of sight, cover, ammo, hazards, ally damage, Curse Artifacts, bespoke audio, and new VFX architecture.

## Files to Change

| File                                                             | Change Size | Purpose                                          |
| ---------------------------------------------------------------- | ----------- | ------------------------------------------------ |
| `game/entities/enemies/grid_enemy.gd`                            | Medium      | Add deterministic Manhattan-band planning.       |
| `game/entities/enemies/ranged_enemy.gd`                          | Large       | Own range policy and target-centered commitment. |
| `game/entities/enemies/ranged_enemy.tscn`                        | Medium      | Define the inherited Ranged scene identity.      |
| `game/entities/enemies/data/ranged_enemy.tres`                   | Small       | Author fixed stats and Cross attack.             |
| `game/entities/enemies/assets/ranged_enemy/eye_sprite_sheet.png` | Small       | Own the selected Eye art.                        |
| `data/waves/default_wave_catalog.tres`                           | Small       | Add the provisional Wave 1 group/headroom.       |
| `test/unit/test_enemy_pathfinding.gd`                            | Medium      | Cover distance-band planning.                    |
| `test/unit/test_ranged_enemy_cross_pressure.gd`                  | Large       | Cover the Ranged combat lifecycle.               |
| `test/unit/test_enemy_progression_data.gd`                       | Small       | Lock data and scene wiring.                      |
| `test/unit/test_wave_controller.gd`                              | Small       | Lock catalog ordering and roster boundaries.     |

## Execution Outline

1. Add shared distance-band planning and focused path regressions without changing generic search or melee policy.
2. Author the sole attack/data, implement Ranged on the Small lifecycle, and cover combat behavior and cleanup.
3. Copy Eye into feature ownership, create the inherited scene, and cover scene initialization.
4. Append the fixed Wave 1 group after Bomb, raise cap to five, and preserve weighted/endless entries.
5. Lint all touched files and run the narrow pathfinding, Ranged, progression-data, and wave suites; manually verify Eye mapping and Wave 1 readability.

## Implementation Notes

- Distance is `abs(dx) + abs(dy)`. An in-band start needs no movement; otherwise choose the shortest claimable band path, or clear reservations and retry without melee fallback.
- Author center/right/left/down/up offsets. Transform them around the target using a canonical orientation, then immediately face the target cell before warning; keep existing enum values and use `CUSTOM_OFFSETS` plus the shared executor.
- A qualifying hit still queues funded FaceOnce, which may commit afterward if the player remains in band; Ranged is not exempt from hit reaction.
- Copy only `assets/Ninja Adventure - Asset Pack/Actor/Monster/Eye/Eye.png`, retain the four-by-four integer-scale scaffold, and omit its `.import` sidecar.

## Edge Cases

| Case                                                     | Expected Handling                                                              |
| -------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Player is closer than three, farther than five, or cannot reach the band | Ranged repositions or waits without firing or melee fallback.                  |
| Player moves during warning                              | The original five cells remain authoritative and hit only by final membership. |
| Cross reaches bounds or SEA/occupants                    | Bounds clip; every in-bounds cell remains warned and unblocked.                |
| Guard break, death, or reset interrupts windup           | Runtime, telegraph, VFX, presenter, and reservations clear with no later hit.  |
| Ranged is hit outside windup                             | Funded FaceOnce remains normal; facing still does not gate attacks.            |

## Acceptance Criteria

1. Ranged has Level 1 HP 100, Defense 0, Small Guard 32, speed 75, and exactly one 10-damage, two-tick-warning, one-recovery attack.
2. Ranged attacks without a facing action prerequisite from Manhattan distance three through five, immediately faces the target cell when its telegraph starts, retreats or repositions when closer, approaches when farther, and never falls back to melee pursuit.
3. Every commitment locks the player's current cell plus four orthogonal neighbors; warning, danger countdown, and detonation agree on that snapshot and never retarget.
4. Bounds clip the Cross, while terrain and other actors neither block it nor receive damage.
5. Hit-triggered FaceOnce, Guard, Stagger, death, recovery, and cancellation retain their shared timing and priority around the facing-independent attack.
6. The Eye identity presents direction, movement, preparation, commit, damage, Stagger, and cleanup through the established Small visual scaffold.
7. Every fresh run exposes one fixed Ranged after the Wave 1 Bomb group with population headroom five, while weighted and endless composition remain unchanged.
