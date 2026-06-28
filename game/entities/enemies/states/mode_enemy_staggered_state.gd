# mode_enemy_staggered_state.gd
# ModeEnemy wrapper for the shared staggered state.
extends EnemyStaggeredState

func _init() -> void:
    state_id = ModeEnemyState.ModeEnemyStateId.STAGGERED
