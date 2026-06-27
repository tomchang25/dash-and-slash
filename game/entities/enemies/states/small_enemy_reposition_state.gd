# small_enemy_reposition_state.gd
# SmallEnemy wrapper for the shared one-cell reposition state.
extends EnemyRepositionState

func _init() -> void:
    state_id = SmallEnemyState.SmallEnemyStateId.REPOSITION_STEP
