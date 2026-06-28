# enemy_attack_data.gd
# Resource model for a reusable enemy attack profile covering tile, charge, and puff styles.
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
