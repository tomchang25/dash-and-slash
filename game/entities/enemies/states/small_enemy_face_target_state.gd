# small_enemy_face_target_state.gd
# SmallEnemy wrapper for the shared face-once state.
extends EnemyFaceOnceState

func _init() -> void:
    state_id = SmallEnemyState.SmallEnemyStateId.FACE_ONCE
