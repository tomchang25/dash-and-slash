# Unify Enemy Attack And State Behavior Across Enemy Kinds

## Goal

Finish bringing the four enemy kinds onto one consistent shape. Four of the original five pieces are resolved — the shared tile/point attack executors, the single attack-node lookup convention, and the state-identity override cleanup have shipped, and the fallback-default-profile consolidation was dropped as low-value dead-code archiving (see Dropped below). One piece remains: one shared charge-traversal implementation so a charge attack looks identical regardless of which kind performs it.

## Remaining Requirement

Charge traversal — see `enemy_kind_unification_05_charge_traversal.implementation_spec.md`. The behavior of driving an enemy through a sequence of grid cells at charge speed — including mid-charge streak feedback and per-cell telegraph clearing — is implemented once and used by every enemy performing a charge-style attack, so a dedicated ChargeEnemy and a ModeEnemy CHARGE mode look and feel identical to the player. Today only `ChargeEnemyChargeAttackState` carries the streak VFX and per-cell telegraph clear; ModeEnemy runs CHARGE through the generic attack state with a hand-rolled cell-by-cell `_move_to_charge_cell` and no VFX.

## Dropped

Fallback default-profile consolidation (was phase 4) was dropped. After the attack-executors phase landed, the one item that forced it — relocating `ModeEnemyAttackController._create_origin_candidate_attack_data` — no longer exists, and the remainder was archiving never-exercised dead numbers into one file while being barred from deduplicating their values and while severing each fallback's link to its owning kind's constants. The per-kind inline fallbacks stay where they are.

## Non-Goals

1. No balance or numeric changes — every authored attack value stays numerically identical.
2. No new enemy kinds, no spawn-weighting or wave-system changes.
3. No change to the values already authored in per-enemy data resources.
4. No change to guard, stagger, health, or death handling.

## Acceptance Criteria

1. A charge-style attack looks and behaves identically — traversal, per-cell telegraph clearing, mid-charge visual feedback — regardless of which enemy kind performs it.
2. Existing gameplay behavior — damage numbers, timings, attack shapes — is unchanged for every currently authored enemy attack profile.
