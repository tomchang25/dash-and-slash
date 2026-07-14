# Tick Arena Enemy Combat Roles And Counterpressure 02: Hit-Reaction Facing

Parent Plan: `tick_arena_enemy_combat_roles_and_counterpressure.md`

## Goal

Make a surviving enemy struck outside committed windup prepare one funded facing action toward the player when it is not already front-facing. This closes repeat side/back-hit loops while preserving existing action economy, attack commitments, and Stagger priority.

## Summary

After hit resolution applies HP and Guard state, an eligible enemy that needs a turn abandons stale movement reservations and enters the existing one-step FaceTarget state. It does not turn immediately: the next normal world advance may fund the state, while a Speed free action only leaves the pending state visible. An already front-facing enemy retains its normal Idle or Reposition intent instead of paying for an empty FaceTarget action.

Only one response can be pending. Death, Guard Break/Stagger, and a committed telegraph take priority and suppress the response; recovery can retain it until the actor may act. Repeated hits never add turns, restart the cost, or cancel a committed windup.

## Relational Context

- `GridEnemy.take_hit()` is the single mutation path for normal, Dash, and Smash player damage. It decides facing response only after Health and Guard have consumed the pure resolver outcome.
- `TickHitResolver` stays pure and knows no FSM state. `GridEnemy` owns response eligibility because it can inspect live death, Guard/Stagger, committed telegraph, recovery, and planned path.
- `StateMachine.request_transition()` is the actor-owned external interrupt path. Reuse FaceTarget and its capped `tick_face_toward_target()` action; do not add a second turning state or rotate directly in hit code.
- `GridEnemy.clear_planned_path()` owns planned-path data and GridArena reservations. Response preparation must clear it before replacing Reposition intent.
- `TickEngine` funds and executes actions only during world advances. Speed free move/attack results deliberately skip it, so they cannot execute FaceTarget.
- Guard break synchronously clears energy, telegraph, recovery, and path through existing Guard signals. Response logic runs after that work and must not request FaceTarget when live Guard is staggered.

## Scope

### Included

- One pending hit-facing response in shared GridEnemy state.
- Reposition path/reservation cancellation when a valid response replaces movement intent.
- Focused state and action-order regression coverage.

### Excluded

- Guard profiles/protection, attack timing, counters, retaliation damage, and speed changes.
- Retargeting or cancelling committed attacks.
- Changes to player Speed-meter free-action rules.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `game/entities/enemies/grid_enemy.gd` | Medium | Decide, store, clear, and expose the one pending hit-facing response after live hit application. |
| `game/entities/enemies/states/enemy_face_once_state.gd` | Small | Consume the pending response exactly when its funded capped turn executes. |
| `test/unit/test_grid_enemy_hit_reaction.gd` | Large | Cover priority, path cleanup, repeat hits, recovery, free action, and normal action order. |
| `test/unit/test_enemy_pathfinding.gd` | Small | Preserve reservation cleanup expectations for abandoned movement. |

## Execution Outline

1. Add pending-response lifecycle to GridEnemy and expose only minimal state to FaceTarget.
2. Make FaceTarget consume one pending response when it receives a funded tick, preserving current capped turn and optional post-face attack commit.
3. Add focused tests for a reserved Reposition path, free action, normal action, Stagger, recovery, death, and committed telegraph.

## Implementation Notes

- Eligible means alive after HP application, no Guard break/Stagger, no pending telegraph, not Dead or Staggered, and not already facing the player. A pending response can survive recovery but cannot execute until TickEngine permits an action.
- On the first eligible hit, clear path/reservation, mark exactly one response pending, and request FaceTarget unless it is already current. A repeated hit while pending changes neither count nor action cost.
- FaceTarget still turns at most 90 degrees and may commit only through its existing post-face attack decision. Clear pending response when that state's funded action begins, not when it is prepared.
- A committed windup is immune even if a hit is non-breaking. A later hit after cancellation follows ordinary eligibility; do not branch on attack kind.
- Reset, death entry, Guard break, and any transition that makes response impossible clear pending state. Debug readout must not claim a response after reset or pooling.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| A back hit lands while Reposition has reserved a future cell | Reservation and planned path clear before FaceTarget becomes pending. |
| A front hit lands while the enemy already faces the player | Existing Idle or Reposition intent stays in place; no empty FaceTarget action is queued. |
| Two hits land before an enemy receives an action | One FaceTarget action occurs; the second adds no turn. |
| A hit breaks Guard or kills | Existing Stagger or Dead transition wins; no facing action queues. |
| A hit lands during committed telegraph | Telegraph remains locked and no response is prepared. |
| A Speed free attack prepares response | It waits; the next normal world advance may fund it. |

## Acceptance Criteria

1. A surviving non-breaking hit outside committed windup clears stale movement and prepares exactly one capped facing action only when the enemy needs to turn; a front-facing enemy keeps its current intent.
2. Free actions never execute it, while the next eligible funded action may turn and then follow normal attack decision rules.
3. Repeated hits, recovery, Guard Break, Stagger, death, reset, and committed telegraphs retain deterministic priority with no stale reservation or extra facing cost.
