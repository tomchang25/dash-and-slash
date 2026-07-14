# Tick Arena Enemy Mobility And Forced Displacement

## Goal

Turn high-speed enemy movement into readable committed attacks with deterministic occupancy rules, collision damage, and forced displacement. The plan establishes a reusable behavioral language through ChargeEnemy first, then adds DashEnemy as a distinct backline-ambush threat.

## Requirements

1. High-speed enemy attacks must lock and telegraph their route, destination, and attack timing before resolving so the player can evade through tick decisions rather than animation reaction.
2. ChargeEnemy must search a cardinal line up to five cells, turn and wind up immediately when the player is in that attack line, and resolve against the committed direction without requiring a separate facing action or retargeting during the windup.
3. Charge collisions must distinguish fixed Environment from movable collision actors: Environment stops the charge without taking damage or moving, while enemies and future Item, DestroyedObject, or generated-obstacle actors take half attack damage and attempt a one-cell lateral displacement.
4. ChargeEnemy must push a contacted player one cell along the charge direction and occupy the player's former cell; a pinned player instead stays in place, takes double damage, and forces ChargeEnemy to stop before the player.
5. DashEnemy must use a five-cell cardinal ambush: it turns and commits to the cell one step beyond the player along its approach line without a separate facing action, cancels if that landing cell is occupied before detonation, and attacks the locked player cell from the opposite side without relying on player combat facing.
6. Forced movement must update logical occupancy immediately and clear invalidated movement reservations/plans so no actor appears in two cells or continues a stale path after displacement.

## Design

### Shared collision categories

| Category                | Examples                                                | Charge result                                                                                                          |
| ----------------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Environment             | Water, map edge, fixed wall, non-land terrain           | Takes no damage, never moves, and stops ChargeEnemy in the preceding reachable cell.                                   |
| Movable collision actor | Enemy, future Item, DestroyedObject, generated obstacle | Takes half of the charge's attack damage and attempts to move one cell left or right relative to the charge direction. |
| Player                  | Tick player                                             | Takes normal damage and is pushed forward one cell when possible; takes double damage and stays in place when pinned.  |

For a movable collision actor, collect the valid lateral cells at impact. If both are valid, choose one randomly; if only one is valid, use it; if neither is valid, the actor remains and blocks further charge traversal. This small collision-time random choice does not need advance telegraphing because the committed charge route and collision risk remain visible.

### ChargeEnemy resolution

Charge range is five cells. ChargeEnemy commits when the player is aligned in a cardinal attack line; commitment turns the enemy toward that line and locks the direction and five-cell terrain-bounded path in the same funded action. The visible windup is the player's counterplay window, so no separate facing action precedes it.

On detonation, traverse the locked path in order:

1. Fixed Environment ends traversal before that cell.
2. A movable collision actor takes half damage and is displaced laterally when a valid side cell exists; ChargeEnemy continues through the freed cell. If neither side is valid, ChargeEnemy stops before the actor.
3. If the player still occupies a cell on the locked attack line and the forward push cell is open land, the player takes normal damage, moves one cell forward, and ChargeEnemy occupies the player's former cell.
4. If the player is pinned by Environment or another occupant, the player takes double damage and does not move. An occupant in the player's forward cell takes half damage and follows the same lateral-displacement rule. ChargeEnemy stops in the cell immediately before the player after resolving any occupant already there through the same half-damage lateral rule; if that cell cannot be cleared, ChargeEnemy remains at the last reachable cell.
5. If the player left the locked line or moved beyond the five-cell attack range during windup, ChargeEnemy still completes the committed path until range, Environment, or a blocking collision ends it.

### DashEnemy resolution

DashEnemy searches a cardinal line up to five cells. When the player is found, commitment turns the enemy toward the approach line and locks a landing cell one step beyond the player's locked cell along the direction from DashEnemy through the player; this is called the player's back side for this attack and does not read player facing. Its visible windup replaces any separate facing action.

The landing cell must be open land at commit time. Windup telegraphs the approach line, locked player cell, and landing cell. At detonation, an occupied or invalid landing cell cancels the entire attack. Otherwise DashEnemy teleports to the locked landing cell and attacks the locked player cell; if the player moved, the attack whiffs rather than retargeting.

Child overview:

| Child | Focus                        | Current document                                                                               |
| ----- | ---------------------------- | ---------------------------------------------------------------------------------------------- |
| 01    | ChargeEnemy Collision Rework | `tick_arena_enemy_mobility_and_forced_displacement_01_charge_enemy_collision_rework.sketch.md` |
| 02    | DashEnemy Backline Ambush    | `tick_arena_enemy_mobility_and_forced_displacement_02_dash_enemy_backline_ambush.sketch.md`    |
| 03    | Viking Smash Knockback       | `tick_arena_enemy_mobility_and_forced_displacement_03_viking_smash_knockback.sketch.md`        |

Recommended landing order: first land the player-round AP boundary, then the shared facing-free commitment and multi-step MoveAction contract from the enemy action plan. Implement ChargeEnemy next so real combat proves ordered traversal, player push, movable-actor lateral displacement, Environment blocking, occupancy refresh, and reservation invalidation. Add DashEnemy after that contract is stable, then implement Viking Smash Knockback as the first player-owned consumer of the same forced-displacement and occupancy seam.

## Non-Goals

1. Do not add destructible Environment; fixed terrain remains immune and immovable.
2. Do not add Item, DestroyedObject, or generated-obstacle systems here; only define how their future movable collision actors participate.
3. Do not redesign enemy spawn weighting, normal SmallEnemy patterns, or ModeEnemy attacks.
4. Do not make collision-side randomness part of the advance telegraph.
5. Do not define base Smash resolution when an enemy occupies its locked landing; that unresolved collision rule remains a separate Draft until its non-cancelling result is locked.
6. Do not apply ordinary multi-step MoveAction rules to Charge or Dash resolution; these are committed attack payloads with their own locked traversal and landing contracts.

## Acceptance Criteria

1. ChargeEnemy turns and presents a five-cell committed threat in one funded action, then resolves every crossed cell in order without overlapping logical occupancy.
2. A freely movable player is damaged, pushed one cell, and replaced in their former cell by ChargeEnemy.
3. A pinned player stays in place, takes double damage, and ChargeEnemy stops before them while collateral occupants receive half damage and lateral displacement when possible.
4. Fixed Environment stops charges without taking damage or moving, while movable collision actors use the half-damage lateral-displacement rule.
5. DashEnemy turns and visibly commits to a valid cell across the player in one funded action, cancels when that landing becomes unavailable, and never retargets after windup.
6. Forced movement clears stale reservations/plans and leaves every actor registered in exactly its resolved cell.
7. Viking Smash Knockback reuses the proven forced-displacement seam and keeps previewed and committed one-cell radial pushes in agreement.
