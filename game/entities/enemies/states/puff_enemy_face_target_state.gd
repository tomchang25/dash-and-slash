# puff_enemy_face_target_state.gd
# PuffEnemy wrapper for the shared face-once state.
extends EnemyFaceOnceState

func _init() -> void:
    state_id = PuffEnemyState.PuffEnemyStateId.FACE_ONCE
