# puff_enemy_idle_state.gd
# PuffEnemy wrapper for the shared idle state.
extends EnemyIdleState

func _init() -> void:
    state_id = PuffEnemyState.PuffEnemyStateId.IDLE
