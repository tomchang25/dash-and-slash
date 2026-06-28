# mode_enemy_reposition_state.gd
# ModeEnemy wrapper for the shared one-cell reposition state.
extends EnemyRepositionState

func _init() -> void:
    state_id = ModeEnemyState.ModeEnemyStateId.REPOSITION
