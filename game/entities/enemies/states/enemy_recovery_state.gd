# enemy_recovery_state.gd
# Shared recovery state. The recovery window itself is a disabled status counted down in the engine's
# status pass (advance_status), so this state only advances once recovery has ended, returning to idle.
class_name EnemyRecoveryState
extends EnemyState

func _init() -> void:
    state_id = EnemyStateId.RECOVERY


func _advance_tick() -> void:
    change_state(enemy.get_idle_state_id())
