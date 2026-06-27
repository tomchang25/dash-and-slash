# charge_enemy_recovery_state.gd
# ChargeEnemy wrapper for the shared recovery state.
extends EnemyRecoveryState

func _init() -> void:
    state_id = ChargeEnemyState.ChargeEnemyStateId.RECOVERY
