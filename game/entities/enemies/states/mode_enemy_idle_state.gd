# mode_enemy_idle_state.gd
# ModeEnemy wrapper for the shared idle state.
extends EnemyIdleState

func _init() -> void:
    state_id = ModeEnemyState.ModeEnemyStateId.IDLE
