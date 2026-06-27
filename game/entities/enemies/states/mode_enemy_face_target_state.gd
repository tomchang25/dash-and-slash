# mode_enemy_face_target_state.gd
# ModeEnemy wrapper for the shared face-once state.
extends EnemyFaceOnceState

func _init() -> void:
    state_id = ModeEnemyState.ModeEnemyStateId.FACE_TARGET
