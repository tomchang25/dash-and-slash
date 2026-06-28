# mode_enemy_recovery_state.gd
# ModeEnemy wrapper for the shared recovery state.
extends EnemyRecoveryState

func _init() -> void:
    state_id = ModeEnemyState.ModeEnemyStateId.RECOVERY
