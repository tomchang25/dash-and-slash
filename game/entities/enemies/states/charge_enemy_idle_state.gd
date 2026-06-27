# charge_enemy_idle_state.gd
# ChargeEnemy wrapper for the shared idle state.
extends EnemyIdleState

func _init() -> void:
    state_id = ChargeEnemyState.ChargeEnemyStateId.IDLE
