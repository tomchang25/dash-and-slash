# small_enemy_dead_state.gd
# SmallEnemy wrapper for the shared death state.
extends EnemyDeadState

func _init() -> void:
    state_id = SmallEnemyState.SmallEnemyStateId.DEAD
