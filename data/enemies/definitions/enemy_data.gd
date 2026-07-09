# enemy_data.gd
# Designer-authored resource for common enemy tuning: identity, recovery, attack profiles, and mode colors.
class_name EnemyData
extends Resource

@export var enemy_id := ""
@export var display_name := ""
@export var default_recovery_duration := 3.0
@export var attacks: Array[EnemyAttackData] = []
@export var mode_colors: Array[Color] = []
