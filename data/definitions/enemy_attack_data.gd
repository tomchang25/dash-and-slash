# enemy_attack_data.gd
# Resource model for a reusable enemy attack profile covering tile, charge, and puff styles.
# The warning/charge/active/recovery duration fields are authored as tick counts (player actions),
# not seconds, since enemies are clocked by the tick engine.
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
## Player actions the telegraph is displayed before the attack detonates.
@export var warning_duration := 2
## Extra tick(s) the telegraph shows its escalated charge phase (folded into the warning countdown).
@export var charge_duration := 0
## Player actions the attack stays active (puff zone lifetime, mode active window); tile attacks resolve at once.
@export var active_duration := 1
## Player actions the enemy recovers (cannot act) after the attack resolves.
@export var recovery_duration := 1
## Player actions between puff in-range re-checks while the zone is active.
@export var recheck_interval := 1
@export var line_length := 3
@export var width := 3
@export var depth := 2
@export var radius := 1
@export var charge_speed := 480.0
