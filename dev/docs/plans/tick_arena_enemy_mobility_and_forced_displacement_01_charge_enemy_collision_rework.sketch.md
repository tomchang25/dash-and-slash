# Tick Arena Enemy Mobility And Forced Displacement 01: ChargeEnemy Collision Rework

Parent Plan: `tick_arena_enemy_mobility_and_forced_displacement.md`

## Goal

Explore the implementation boundary for turning ChargeEnemy's current damage-line/farthest-landing snap into ordered collision traversal with player push, pinned-player punishment, movable-actor collateral, and fixed-Environment blocking.

## Summary

The likely implementation should keep ChargeEnemy's existing alignment, turn cost, five-cell authored line, warning countdown, recovery, presenter cues, and telegraph ownership. The major change is detonation: instead of damaging the player if present and selecting the farthest open landing independently, one ordered traversal result should decide damage, displacement, final ChargeEnemy position, occupancy updates, and feedback together.

This slice is also the proving ground for forced displacement that Viking Smash Knockback will reuse later. The later implementation spec should extract only the smallest reusable collision/displacement rule justified by ChargeEnemy rather than building a speculative universal physics layer for future Item or DestroyedObject types that do not exist yet.

## Sketch

- `ChargeEnemy._can_charge_now()` currently requires cardinal alignment, completed facing, and the player inside `get_charge_cells()`. That is the favored commit contract to preserve.
- `ChargeEnemy.begin_attack_telegraph()` stores the current charge cells and the tick runtime locks them for warning/charge display. The stored ordered line is the likely committed route; detonation must not recompute toward the player's new location.
- `ChargeEnemy._tick_detonate()` currently calls the shared player-line damage helper, then `GridEnemy.get_charge_landing_cell()` and one `tick_snap_to_cell()`. The later spec should replace this split resolution with one ordered traversal outcome so damage and landing cannot disagree.
- `GridArena` owns occupancy/reservation truth, while `TickEngine` exposes living-enemy lookup and open-cell checks. Forced movement likely needs a narrow grid-actor relocation API or explicit callbacks for player and GridEnemy rather than direct field mutation from ChargeEnemy.
- `GridEnemy.tick_snap_to_cell()` already updates logical enemy occupancy before tweening presentation, but forced displacement also needs to clear the displaced enemy's planned path/reservation and refresh its visual position without granting an action.
- The player currently has no general forced-move API. The later spec should add one player-owned relocation entry that updates cell/position without consuming a verb, filling Speed, ticking cooldowns, or advancing the world.
- Collision traversal should classify a cell in this order: Environment validity, player, living enemy, future movable collision actor, then empty land. A future actor interface may be sketched, but ChargeEnemy should not depend on concrete Item or DestroyedObject classes that are not present.
- Lateral displacement uses cells perpendicular to the committed charge direction. Collect valid land/unoccupied candidates at impact; choose the sole candidate or randomly choose between two; no candidate leaves the collided actor in place and stops traversal before it.
- Player contact resolves after any earlier path collisions. An open forward cell receives the player and frees the old cell for ChargeEnemy. A blocked forward cell produces double player damage; a movable occupant there takes half damage and attempts lateral displacement, but the player remains pinned regardless of whether that occupant moves.
- The cell immediately before a pinned player must also be cleared through the same collateral rule before ChargeEnemy can occupy it. If it cannot be cleared, the charger stays in its last reachable cell rather than overlapping the blocker.
- Presentation should show traversal/collision in path order with short visual beats, but logical outcomes resolve synchronously inside the detonation tick. Tweens must not become occupancy or damage clocks.
- Candidate files to inspect: `game/entities/enemies/charge_enemy.gd`, `game/entities/enemies/grid_enemy.gd`, `game/entities/enemies/enemy_tick_runtime.gd`, `common/gameplay/grid/grid_arena.gd`, `game/tick_arena/combat/tick_engine.gd`, `game/tick_arena/player/tick_player.gd`, `game/tick_arena/view/tick_grid_view.gd`, `game/entities/enemies/data/charge_enemy.tres`, and focused ChargeEnemy/grid reservation tests.

## Non-Goals

1. No DashEnemy implementation.
2. No Viking Smash Knockback implementation.
3. No concrete Item, DestroyedObject, or generated-obstacle feature.
4. No change to the five-cell range, facing turn cost, warning duration, recovery duration, or base attack damage outside the explicit half/double collision multipliers.
5. No real-time physics collision or animation-driven resolution.

## Acceptance Criteria

1. ChargeEnemy resolves the committed five-cell route in order and ends in the same cell the collision result reports.
2. Player push, pinned double damage, movable-actor half damage/lateral displacement, and fixed-Environment blocking follow the parent plan.
3. Forced actors update occupancy and abandon stale reservations/plans immediately while visual motion remains presentation-only.
4. Existing ChargeEnemy facing, windup, telegraph, recovery, stagger cancellation, and death cleanup remain readable and functional.

