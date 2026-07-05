# enemy_face_once_state.gd
# Shared state that turns toward the target one capped step (the flank turn cap), then follows the
# enemy's after-face hook. Repeated entries turn further, so aligning on a flanker costs player actions.
class_name EnemyFaceOnceState
extends EnemyState

func _init() -> void:
    state_id = EnemyStateId.FACE_TARGET


func _advance_tick() -> void:
    enemy.tick_face_toward_target()
    change_state(enemy.get_after_face_state_id())
