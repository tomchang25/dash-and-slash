# Enemy Kind Unification — State-Identity Override Cleanup

## Goal

Remove state-identity query overrides on individual enemy kinds that only restate the shared default from `GridEnemy`, so a remaining override reliably signals that the kind's behavior for that lifecycle step genuinely differs.

## Requirements

1. Every enemy kind's idle, reposition, face, recovery, staggered, and dead state-identity query is deleted from that kind wherever it returns the same value `GridEnemy` already returns, because an override that restates the inherited value carries no behavior and only obscures which kinds truly diverge.
2. Overrides that do differ from the shared default are left exactly as they are — this cleanup changes no behavior anywhere.
3. A kind that already has no override for a given query (PuffEnemy has none for recovery) stays that way; the absence is correct today, not an oversight to fix.

## Design

Every kind extends `GridEnemy`, which supplies a default for each of six lifecycle queries: idle, reposition, face, recovery, staggered, dead. All four kinds currently restate all six (or, for PuffEnemy, five of six) verbatim. None of these restatements changes the returned value. Each kind also has a small set of queries that genuinely diverge per kind — those are the only overrides that should remain after this cleanup.

## Sketch (non-normative)

Per-kind deletions, based on what's on disk today:

**SmallEnemy** (`game/entities/enemies/small_enemy.gd`) — delete: `get_idle_state_id`, `get_reposition_state_id`, `get_face_state_id`, `get_recovery_state_id`, `get_staggered_state_id`, `get_dead_state_id`. Keep: `get_pre_plan_state_id`, `get_after_face_state_id` (both gate on `can_attack()`, genuinely different from the base `-1`/`IDLE` defaults).

**ChargeEnemy** (`game/entities/enemies/charge_enemy.gd`) — delete the same six. Keep: `get_pre_plan_state_id`, `get_arrival_override_state_id`, `get_attack_state_id`, `get_recovery_duration` (all genuinely kind-specific).

**PuffEnemy** (`game/entities/enemies/puff_enemy.gd`) — delete: `get_idle_state_id`, `get_reposition_state_id`, `get_face_state_id`, `get_staggered_state_id`, `get_dead_state_id` (five — there is no `get_recovery_state_id` override to delete, it already has none). Keep: `get_pre_plan_state_id`, `get_arrival_override_state_id`.

**ModeEnemy** (`game/entities/enemies/mode_enemy.gd`) — delete the same six as SmallEnemy/ChargeEnemy. Keep: `get_pre_plan_state_id`, `get_arrival_override_state_id`, `get_after_face_state_id`.

No other files change. `GridEnemy`'s defaults are untouched.

## Acceptance Criteria

1. No enemy kind overrides a state-identity query whose return value matches `GridEnemy`'s default for that query.
2. Every kind's actual state-transition behavior — idle/reposition/face/recovery/staggered/dead routing, plus each kind's genuinely divergent pre-plan/arrival/attack-state overrides — is unchanged.
3. PuffEnemy still has no `get_recovery_state_id()` override.
