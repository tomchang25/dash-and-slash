# enemy_data.gd
# Designer-authored resource for common enemy tuning: identity, recovery, Level 1 HP/Defense, Guard
# role, and attack profiles. Health consumes these runtime bases while Guard derives its live values
# from the optional shared profile; EnemyLevelProgressionProfile projects final spawn values.
class_name EnemyData
extends Resource

@export var enemy_id := ""
@export var display_name := ""
@export var default_recovery_duration := 3.0
@export var max_health := 100.0
@export var guard_profile: GuardProfile
@export var defense := 0.0
@export var attacks: Array[EnemyAttackData] = []

# == Common API ==


## Reports malformed authored enemy data and returns whether the resource is safe to use.
func validate() -> bool:
    var valid := true
    if enemy_id == "":
        ToastManager.show_dev_error("EnemyData: enemy_id is empty")
        valid = false
    if max_health <= 0.0:
        ToastManager.show_dev_error("EnemyData: max_health must be positive for '%s', got %s" % [enemy_id, max_health])
        valid = false
    if guard_profile != null and not guard_profile.validate():
        valid = false
    if defense < 0.0:
        ToastManager.show_dev_error("EnemyData: defense must be non-negative for '%s', got %s" % [enemy_id, defense])
        valid = false
    return valid
