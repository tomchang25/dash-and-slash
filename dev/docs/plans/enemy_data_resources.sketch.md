# Enemy Data Resources

## Goal

Introduce a lightweight enemy resource model so common enemy stats and attack profiles can be tuned without editing enemy scripts. This creates the foundation for later attack-controller and state-consolidation work while preserving existing enemy behavior.

## Requirements

1. Enemy resources are manually authored with the enemy feature, because the enemy count is small and generated data is unnecessary.
2. Existing enemy classes keep their current behavior while reading common tuning from data where safe.
3. Data fields cover only shared tuning values, because custom enemy logic and boss behavior should remain in code.
4. Missing or incomplete data preserves current behavior during migration.

## Design

The data model starts with two concepts: one enemy-level resource and one attack-level resource. The enemy-level resource owns identity and common tuning. The attack-level resource owns reusable attack numbers and shape choices. The first phase wires only low-risk values such as movement speed, cooldown, recovery duration, and profile selection.

## Sketch (non-normative)

Proposed resource placement:

```text
game/entities/enemies/data/
  small_enemy.tres
  charge_enemy.tres
  puff_enemy.tres
  mode_enemy.tres
```

Proposed data scripts:

```text
game/entities/enemies/enemy_data.gd
game/entities/enemies/enemy_attack_data.gd
```

Proposed `EnemyData` shape:

```gdscript
class_name EnemyData
extends Resource

@export var enemy_id := ""
@export var display_name := ""
@export var move_speed := 120.0
@export var cycle_cooldown := 1.0
@export var default_recovery_duration := 3.0
@export var attacks: Array[EnemyAttackData] = []
@export var mode_colors: Array[Color] = []
```

Proposed `EnemyAttackData` shape:

```gdscript
class_name EnemyAttackData
extends Resource

enum AttackKind {
    TILE,
    CHARGE,
    PUFF,
}

enum CellShape {
    LINE,
    WIDE,
    SQUARE,
    FULL_LINE,
}

@export var attack_id := ""
@export var attack_kind: AttackKind = AttackKind.TILE
@export var cell_shape: CellShape = CellShape.LINE
@export var damage := 10.0
@export var damage_interval := 0.0
@export var warning_duration := 0.6
@export var charge_duration := 0.2
@export var active_duration := 0.2
@export var recovery_duration := 0.4
@export var line_length := 3
@export var width := 3
@export var depth := 2
@export var radius := 1
@export var charge_speed := 480.0
```

Proposed shared data access:

```gdscript
@export var enemy_data: EnemyData

func get_move_speed() -> float:
    return enemy_data.move_speed if enemy_data != null else MOVE_SPEED

func get_cycle_cooldown() -> float:
    return enemy_data.cycle_cooldown if enemy_data != null else CYCLE_COOLDOWN

func get_recovery_duration() -> float:
    return enemy_data.default_recovery_duration if enemy_data != null else 3.0
```

Suggested migration steps:

1. Add the data resource classes.
2. Add manually-authored resources for the existing enemy types.
3. Export an enemy data field on the shared grid enemy base.
4. Wire existing enemy scenes to their resources.
5. Make shared getters read data first and fall back to current constants.

## Non-Goals

1. Do not replace attack controllers in this phase.
2. Do not remove existing enemy constants until later phases prove their data replacements.
3. Do not add an enemy registry or generated data pipeline.
4. Do not change wave spawning.

## Acceptance Criteria

1. Existing enemies can be assigned manually-authored enemy resources.
2. Movement, cooldown, and default recovery values can be read from enemy data.
3. Missing enemy data keeps current behavior instead of breaking enemies.
4. No enemy attack lifecycle or state wiring changes are required for this phase.
