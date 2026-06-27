# puff_enemy_reposition_state.gd
# PuffEnemy wrapper for the shared one-cell reposition state.
extends EnemyRepositionState

func _init() -> void:
    state_id = PuffEnemyState.PuffEnemyStateId.REPOSITION_STEP
