# small_enemy_recovery_state.gd
# SmallEnemy wrapper for the shared recovery state.
extends EnemyRecoveryState

func _init() -> void:
    state_id = SmallEnemyState.SmallEnemyStateId.RECOVERY
