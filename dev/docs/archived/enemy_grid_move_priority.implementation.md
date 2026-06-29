# Enemy Grid Move Priority Implementation Spec

## Goal

Add deterministic priority resolution for enemies competing for the same grid destination so dense movement near the player stays predictable. Attack-position planning should beat ordinary repositioning, and ordinary conflicts should resolve by closeness to the player before deterministic registration order.

## Relational Context

- `GridArena` is the authority for occupancy and reservation truth; enemies may request reservations, but they must not locally decide that a contested cell is theirs after `GridArena` rejects or replaces a claim.
- `GridEnemy` owns movement intent and planned paths; `GridArena` should store enough reservation metadata to compare claims but should not know enemy AI state beyond metadata supplied by the caller.
- Reservation writes flow from enemy planning into `GridArena`; reservation conflict outcomes flow back as return values or callbacks that let the losing enemy clear planned movement before it starts moving.
- Ordinary movement planning stays ordinary priority; only attack-position planning via cell-origin attack setup is attack-priority in this version.
- Charge active movement is out of scope for priority handling; its target grid may be reserved or blocked, and overlap along intermediate active charge cells remains acceptable.
- `EnemyRepositionState` consumes the already planned path; it should trust only paths that still hold a valid reservation and should not re-arbitrate priority itself.
- The player cell is read by priority comparison through `GridArena`'s current player-grid state; the player does not participate as a reservation owner.
- Debug visibility must be gated by `Debug.enabled`, and debug-only nodes or labels must remain code-created with `# node-src: debug`.
- Avoid bidirectional AI coupling: losing one reservation must clear that claimant's intent without making the loser immediately steal the winner's claim in the same reservation comparison.

## Scope

### Included

- Reservation metadata for intent type, distance-to-player comparison, and deterministic registration order.
- Conflict resolution when multiple enemies reserve the same destination or active/final movement cell.
- Enemy-side handling for rejected or replaced reservations.
- Focused tests for deterministic priority behavior.
- Low-intrusion debug visibility for contested reservation decisions.

### Excluded

- Priority handling for active charge motion or charge intermediate cells.
- Crowd steering, squad AI, or formation behavior.
- Multi-cell enemy priority.
- Replacing the current pathfinding algorithm.

## Files to Change

| File                                                     | Change Size | Purpose                                                                                                  |
| -------------------------------------------------------- | ----------- | -------------------------------------------------------------------------------------------------------- |
| `common/gameplay/grid/grid_arena.gd`                     | Medium      | Own reservation metadata, deterministic registration indexes, and conflict comparison.                   |
| `game/entities/enemies/grid_enemy.gd`                    | Medium      | Submit ordinary versus attack-priority reservation intent and clear invalidated planned movement.        |
| `game/entities/enemies/states/enemy_reposition_state.gd` | Small       | Avoid consuming or continuing a path whose reservation was lost before movement begins or between steps. |
| `test/unit/test_enemy_grid_move_priority.gd`             | Medium      | Cover ordinary conflicts, attack-priority conflicts, distance ordering, and tie determinism.             |

## Implementation Notes

`GridArena` should keep reservation ownership keyed by entity while also being able to find the current owner for a cell. A claim should compare as `(is_attack, closer_to_player, earlier_registration_index)`, with higher attack priority, smaller distance, and smaller registration index winning. Registration indexes should be monotonic per entity and assigned once per registered/reserving enemy, not once per claim, so repeated replanning cannot reorder equal-priority enemies.

Reservation APIs should report whether the caller still owns the requested cells after arbitration. When a higher-priority claim replaces an existing owner, the old owner's reservation must be removed from every affected cell before the new owner is stored. The old owner should be notified through a narrow enemy-facing method if practical; otherwise the next enemy-side validation must detect the lost reservation before movement starts. Do not let replacement trigger immediate replanning inside `GridArena`.

`GridEnemy.plan_next_action()` and `plan_charge_line_action()` should submit ordinary movement intent. `GridEnemy.plan_cell_attack_action()` should submit attack-priority intent because it is planning an attack origin, not merely chasing. If its reservation is rejected, it should clear `_planned_path` and return false or safely fall back according to the existing planning flow.

`EnemyRepositionState` should avoid moving into a cell that this enemy no longer reserves. If a reservation was lost, it should stop, clear planned movement, and return to an idle/face/planning state consistent with current state-machine ownership rather than forcing a transition from `GridArena`.

Debug output should prefer small labels or existing path drawing extensions that show the winner/loser reason for contested cells only when `Debug.enabled` is true. Keep it inspectable without adding a new gameplay overlay system.

## Edge Cases

| Case                                                                                    | Expected Handling                                                                                                                      |
| --------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Two ordinary enemies reserve the same destination at the same distance                  | The enemy with the earlier registration index keeps the reservation every time.                                                        |
| A later attack-priority claim targets a cell already reserved by an ordinary move       | The attack-priority enemy replaces the ordinary reservation, and the ordinary enemy clears or abandons its planned path before moving. |
| A lower-priority enemy repeatedly replans toward the same contested cell                | The lower-priority claim is rejected consistently and does not oscillate ownership in the same frame.                                  |
| An enemy loses its active/final reserved cell before `EnemyRepositionState` consumes it | The enemy does not move into the contested cell and leaves the grid in a non-overlapping state.                                        |
| The target/player cell changes between planning attempts                                | New comparisons use the current player-grid distance without changing already assigned registration order.                             |

## Acceptance Criteria

1. Two ordinary enemies targeting the same cell do not overlap; one wins and the other replans or waits.
2. A committed attack-position planning enemy wins over an ordinary repositioning enemy for the same destination.
3. Active charge motion is not treated as attack-priority reservation and may still tolerate intermediate overlap as before.
4. Distance to the player resolves ordinary movement conflicts before registration order is used.
5. Equal-distance conflicts resolve consistently across repeated runs with the same enemy registration order.
6. A replaced reservation does not create same-frame ownership ping-pong or a deadlock where both enemies believe they own the cell.
7. The grid never ends a movement resolution frame with two enemies owning the same ordinary occupancy cell.
