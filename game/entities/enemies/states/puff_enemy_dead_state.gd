# puff_enemy_dead_state.gd
# PuffEnemy wrapper for the shared death state.
extends EnemyDeadState

func _init() -> void:
    state_id = PuffEnemyState.PuffEnemyStateId.DEAD
