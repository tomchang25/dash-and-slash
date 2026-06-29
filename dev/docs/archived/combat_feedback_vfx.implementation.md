# Combat Feedback VFX Implementation Spec

## Goal

Add lightweight combat feedback for charge movement, shielded hits, guard breaks, and full-damage hits so players can read whether an attack was blocked, broke guard, or dealt full damage.

## Relational Context

- `Hitbox` owns hit cadence and source attribution only; it must keep forwarding hits to `Hurtbox` without deciding blocked, broken, or full-damage outcomes.
- `Hurtbox` is only the receiving event bridge; it must not spawn result VFX because it does not own guard, health, facing, or damage-reduction state.
- `GridEnemy` owns the shared combat-result decision for 1x1 enemies because it already resolves attacker angle, guard damage, break prediction, HP damage, SFX, health writes, and guard writes.
- Guard owns guard points and stagger state; VFX may react to predicted outcomes, but must not change guard math, stagger timing, or gameplay signal order.
- A guard-breaking hit should show guard-break feedback instead of ordinary shielded-hit feedback. Full-damage bursts should represent unguarded or already-staggered hits so the break moment stays distinct.
- Charge direction feedback belongs to `ChargeEnemy` and `ChargeEnemyChargeAttackState`; tile telegraphs still own affected-cell readability, while the new VFX owns body direction and rush motion.
- Generated VFX should be self-freeing runtime nodes parented to a stable world/effects parent when possible. Runtime-created nodes need `# node-src: ephemeral` comments.
- Do not change the `Hitbox`/`Hurtbox` contract to pass overlap points for this pass; derive effect position from source position, enemy position, and facing.

## Scope

### Included

- A reusable generated/tweened combat feedback helper.
- Shielded-hit, guard-break, and full-damage result VFX from shared enemy hit resolution.
- Charge start/front wind and active dash streak feedback for charge enemies.
- Short-lived one-shot effects with cleanup.

### Excluded

- Final sprite-sheet animation, imported art, audio rebalance, guard math, damage values, enemy AI, player attack timing, hitbox contract changes, and VFX pooling beyond self-freeing nodes.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `common/gameplay/vfx/combat_feedback_vfx.gd` | Medium | Provide reusable one-shot generated combat feedback effects. |
| `game/entities/enemies/grid_enemy.gd` | Small | Trigger shielded-hit, guard-break, and full-damage effects from the existing result branch. |
| `game/entities/enemies/charge_enemy.gd` | Small | Trigger the charge start/front wind effect when the charge telegraph begins. |
| `game/entities/enemies/states/charge_enemy_charge_attack_state.gd` | Small | Trigger rate-limited active charge trail or streak effects during rush movement. |

## Implementation Notes

The VFX helper should create simple `Polygon2D` and/or `Line2D` nodes, apply global placement before tweening, fade or move them briefly, then `queue_free()` them. Prefer the enemy parent for world-anchored effects so they can outlive enemy movement or death; use the enemy itself only as fallback.

In `GridEnemy._on_hit_received()`, derive the visual branch from existing outcome variables: `will_break_guard` produces guard-break feedback, reduced-damage hits produce shield feedback, and full-damage feedback is for already-unguarded or staggered targets. If the direction from source to enemy is zero, fall back to enemy facing or center position.

Charge start feedback should appear slightly ahead of the body along facing. Active charge streaks should use velocity or the next-cell direction and be rate-limited so long charges read as motion rather than stacked clutter.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Hit source is not a `Node2D` | Existing hit handling remains unchanged; no result VFX is required. |
| Guard-breaking hit also deals full HP damage | Guard-break VFX wins for that hit; later staggered hits use full-damage VFX. |
| Enemy dies from the hit | The effect still cleans itself up and does not depend on enemy survival. |
| Charge has no cells or zero direction | No charge VFX spawns, and existing state behavior remains unchanged. |
| Many repeated contact hits occur quickly | Effects stay short-lived and do not leave persistent nodes. |

## Acceptance Criteria

1. A charge enemy visibly communicates its rush direction before and during the charge.
2. Hitting an enemy guard produces shield feedback instead of looking like full damage.
3. Breaking guard produces a distinct effect readable without watching health or guard UI.
4. Damaging a staggered or unguarded enemy produces a different full-damage hit effect.
5. Effects clean themselves up and do not remain in the scene after their short lifetime.
