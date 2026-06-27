# charge_enemy_dead_state.gd
# ChargeEnemy wrapper for the shared death state.
extends EnemyDeadState

func _init() -> void:
    state_id = ChargeEnemyState.ChargeEnemyStateId.DEAD
