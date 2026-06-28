# enemy_face_once_state.gd
# Shared state that faces the target once, then follows the enemy's hook transition.
class_name EnemyFaceOnceState
extends EnemyState

func _init() -> void:
    state_id = EnemyStateId.FACE_TARGET


func _enter() -> void:
    enemy.velocity = Vector2.ZERO
    enemy.face_target_position()


func _physics_update(_delta: float) -> void:
    change_state(enemy.get_after_face_state_id())
