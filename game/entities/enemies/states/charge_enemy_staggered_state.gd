# charge_enemy_staggered_state.gd
# ChargeEnemy wrapper for the shared staggered state.
extends EnemyStaggeredState

func _init() -> void:
    state_id = ChargeEnemyState.ChargeEnemyStateId.STAGGERED
