# charge_enemy_face_target_state.gd
# ChargeEnemy wrapper for the shared face-once state.
extends EnemyFaceOnceState

func _init() -> void:
    state_id = ChargeEnemyState.ChargeEnemyStateId.FACE_ONCE
