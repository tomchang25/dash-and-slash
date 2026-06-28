# mode_enemy_dead_state.gd
# ModeEnemy wrapper for the shared death state.
extends EnemyDeadState

func _init() -> void:
    state_id = ModeEnemyState.ModeEnemyStateId.DEAD
