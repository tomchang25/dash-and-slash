# enemy_attack_data.gd
# Resource model for a reusable enemy attack profile covering tile, charge, and area styles.
# The warning/charge/recovery duration fields are authored as tick counts (player actions),
# not seconds, since enemies are clocked by the tick engine.
class_name EnemyAttackData
extends Resource

enum AttackKind {
    TILE,
    CHARGE,
    AREA,
}

enum CellShape {
    LINE,
    WIDE,
    SQUARE,
    FULL_LINE,
    ADJACENT_RING,
    CUSTOM_OFFSETS,
    MANHATTAN,
}

@export var attack_id := ""
@export var attack_kind: AttackKind = AttackKind.TILE
@export var cell_shape: CellShape = CellShape.LINE
@export var damage := 10.0
@export var damage_interval := 0.0
## Player actions the telegraph is displayed before the attack detonates.
@export var warning_duration := 2
## Extra tick(s) the telegraph shows its escalated charge phase (folded into the warning countdown).
@export var charge_duration := 0
## Player actions the enemy recovers (cannot act) after the attack resolves.
@export var recovery_duration := 1
@export var line_length := 3
@export var width := 3
@export var depth := 2
@export var radius := 1
## Local footprint cells where x is forward and y is left relative to the enemy's facing.
@export var cell_offsets: Array[Vector2i] = []
@export var charge_speed := 480.0
