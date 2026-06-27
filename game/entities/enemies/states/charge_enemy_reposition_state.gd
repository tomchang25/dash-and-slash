# charge_enemy_reposition_state.gd
# ChargeEnemy wrapper for the shared one-cell reposition state.
extends EnemyRepositionState

func _init() -> void:
    state_id = ChargeEnemyState.ChargeEnemyStateId.REPOSITION_STEP
