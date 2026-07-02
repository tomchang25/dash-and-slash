# Enemy Kind Unification — Shared Default Attack-Profile Fallback Source

## Goal

Replace the hardcoded fallback attack-profile builders scattered across enemy kinds with one shared default-profile source that reproduces today's exact values, so a future tuning change to the safety-net numbers doesn't require hunting through every enemy script. Depends on the attack-executors spec landing first, since it deletes the `ModeEnemyAttackController` call site that currently builds one of these fallbacks.

## Requirements

1. One shared source produces a default `EnemyAttackData` per (owning enemy kind, attack kind) pair, reproducing the exact values each kind hardcodes today — no numeric changes. The source holds distinct value sets per owning kind rather than one canonical value per `AttackKind`, because ChargeEnemy's own CHARGE fallback (damage 8.0) and ModeEnemy's CHARGE fallback (damage 10.0) are already different numbers today and must stay different after consolidation — "one shared source" means one shared location, not deduplicated values.
2. Every enemy kind's own fallback-builder method is deleted and replaced with a call into the shared source. The geometry-only partial profile used for tile-mode origin-candidate planning (previously `ModeEnemyAttackController._create_origin_candidate_attack_data`, relocated by the executors spec) also draws from this same source instead of maintaining a separate copy.
3. This is a safety net only — every current enemy scene ships authored `EnemyAttackData` via `EnemyData.attacks`, so this path is not exercised in normal play; behavior is unchanged either way.

## Design

The shared source is keyed by which kind is asking (SmallEnemy, ChargeEnemy, PuffEnemy, ModeEnemy) and, for ModeEnemy, further by which mode. It is a safety net, not a data-driven system — a static factory returning a fully-populated `EnemyAttackData` is enough; no `.tres` resource or designer-facing surface is needed since these values are never meant to be tuned in normal play.

## Sketch (non-normative)

Proposed home: a static helper class, e.g. `EnemyAttackDefaults` (or static methods added directly to `EnemyAttackData`), with one factory function per current call site. Values to preserve verbatim, gathered from what's hardcoded today:

- SmallEnemy fallback (today inline in `_select_attack_data`): TILE, LINE or WIDE (50/50 random) shape, damage 10.0, line_length 3, width 3, depth 2. Durations fall back to `EnemyAttackData`'s own field defaults, since SmallEnemy's fallback never sets them explicitly.
- ChargeEnemy fallback (`_create_fallback_attack_data`): CHARGE, FULL_LINE, damage 8.0, damage_interval 0.6, warning_duration 1.0, charge_duration 0.0, recovery_duration 3.0, charge_speed 480.0.
- PuffEnemy fallback (`_create_fallback_attack_data`): PUFF, SQUARE, damage 12.0, damage_interval 0.35, warning_duration 0.6, active_duration 3.0, recheck_interval 1.0, radius 2.
- ModeEnemy fallback (`_create_fallback_attack_data(mode)`), all three modes sharing warning_duration 0.8, charge_duration 0.2, recovery_duration 0.8:
  - CHARGE: damage 10.0, damage_interval 0.45, active_duration 1.2, charge_speed 480.0, FULL_LINE.
  - PUFF: damage 14.0, active_duration 1.0, radius 1, SQUARE.
  - TILE: damage 12.0, active_duration 0.25, shape randomly WIDE (width 3, depth 2), SQUARE (radius 1), or LINE (line_length 4).
- ModeEnemy origin-candidate partial (today `ModeEnemyAttackController._create_origin_candidate_attack_data`): geometry fields only (cell_shape, and width/depth or radius or line_length as applicable), no damage/duration fields — used purely for footprint planning, not runtime hitbox configuration.

Each caller keeps calling a small wrapper (e.g. `_create_fallback_attack_data()` can stay as a one-line delegator on each kind if that reads more naturally at the call site) but the actual values live in exactly one place.

## Acceptance Criteria

1. Exactly one file/class produces every compatibility fallback `EnemyAttackData` (and the geometry-only origin-candidate variant) used across all four enemy kinds.
2. No enemy kind hardcodes its own fallback attack values inline anymore.
3. Every fallback value produced after this change is identical to what that kind produced before, including where ChargeEnemy's and ModeEnemy's CHARGE fallbacks intentionally differ from each other.
