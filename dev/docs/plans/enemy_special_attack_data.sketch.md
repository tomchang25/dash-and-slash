# Enemy Special Attack Data Integration

## Goal

Extend the data-backed attack model to mode, charge, and puff enemies without removing their custom behavior. This reduces hardcoded tuning while keeping bespoke movement, VFX, and mode-selection logic where it belongs.

## Requirements

1. Mode-based enemies select attack profiles from data while preserving their mode preview and random selection behavior.
2. Charge enemies read charge timing, speed, damage, and footprint values from attack data while preserving their movement implementation.
3. Puff enemies read range, damage, and timing values from attack data while preserving their expand and shrink VFX.
4. Custom behavior remains override-friendly for future bosses, because not every boss should fit the shared attack lifecycle.

## Design

Special attacks use the same attack data shape but do not all use the same execution ownership. Mode behavior chooses a profile and delegates common telegraph and hitbox work. Charge behavior delegates footprint and hitbox setup but keeps movement in the enemy or its attack state. Puff behavior uses data for tuning while keeping its zone-denial lifecycle distinct.

## Sketch (non-normative)

Proposed enemy responsibilities:

```text
ModeEnemy
  keeps mode preview and random selection behavior
  selects one EnemyAttackData profile per mode
  calls EnemyAttackController for the selected profile

ChargeEnemy
  selects its charge attack profile
  decides cardinal alignment
  calls EnemyAttackController for telegraph/contact-hitbox setup
  keeps charge movement in its own state or update hook

PuffEnemy
  selects its puff attack profile
  keeps puff VFX, expand/shrink timing, and range recheck behavior
  reads damage/range/timing values from EnemyAttackData where practical
```

Proposed attack profile examples:

```text
mode_tile_wide
  kind: TILE
  shape: WIDE
  depth: 2
  width: 3

mode_charge
  kind: CHARGE
  shape: FULL_LINE
  charge_speed: 480.0

puff_area
  kind: PUFF
  shape: SQUARE
  radius: 1
```

Proposed shared enemy API additions:

```gdscript
func get_current_attack_data() -> EnemyAttackData:
    return null

func get_warning_duration() -> float:
    var attack := get_current_attack_data()
    return attack.warning_duration if attack != null else 0.6

func get_charge_duration() -> float:
    var attack := get_current_attack_data()
    return attack.charge_duration if attack != null else 0.2

func get_attack_duration() -> float:
    var attack := get_current_attack_data()
    return attack.active_duration if attack != null else 0.2
```

Suggested migration steps:

1. Move mode tile shapes into attack data profiles.
2. Replace the mode-specific attack controller with the shared attack controller where the lifecycle is identical.
3. Move charge speed, charge warning, contact damage, and recovery values into a charge profile while keeping charge movement owned by the charge enemy.
4. Move puff range, damage, minimum duration, and recheck timing into a puff profile where practical.
5. Keep local overrides where data would obscure behavior or create a worse abstraction.

## Non-Goals

1. Do not remove custom mode selection or preview behavior.
2. Do not move charge movement into the shared attack controller.
3. Do not force puff VFX into generic attack execution.
4. Do not require future boss enemies to use every field in the shared data model.

## Acceptance Criteria

1. Mode attacks can be selected from enemy attack data profiles.
2. Charge tuning values can be changed through attack data without changing charge movement ownership.
3. Puff tuning values can be changed through attack data without changing puff VFX ownership.
4. Special-case enemies can still override behavior directly when the shared data model is not a good fit.
