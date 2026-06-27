# small_enemy_idle_state.gd
# SmallEnemy wrapper for the shared idle state.
extends EnemyIdleState

func _init() -> void:
    state_id = SmallEnemyState.SmallEnemyStateId.IDLE
