# small_enemy_face_target_state.gd
# Face once state — applies committed cardinal facing, then starts telegraph.
extends SmallEnemyState

func _init() -> void:
    state_id = SmallEnemyStateId.FACE_ONCE


func _enter() -> void:
    enemy.velocity = Vector2.ZERO
    enemy.apply_planned_facing()


func _physics_update(_delta: float) -> void:
    change_state(SmallEnemyStateId.TELEGRAPH)
