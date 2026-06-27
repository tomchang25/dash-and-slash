# small_enemy_staggered_state.gd
# SmallEnemy wrapper for the shared staggered state.
extends EnemyStaggeredState

func _init() -> void:
    state_id = SmallEnemyState.SmallEnemyStateId.STAGGERED
