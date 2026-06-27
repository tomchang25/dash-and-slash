# puff_enemy_staggered_state.gd
# PuffEnemy wrapper for the shared staggered state.
extends EnemyStaggeredState

func _init() -> void:
    state_id = PuffEnemyState.PuffEnemyStateId.STAGGERED
