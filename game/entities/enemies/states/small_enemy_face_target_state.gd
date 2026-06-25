# small_enemy_face_target_state.gd
# Face target state — snaps facing to the nearest cardinal direction toward the
# target, updates the facing arrow, then immediately transitions to TELEGRAPH.
extends SmallEnemyState

func _init() -> void:
    state_id = SmallEnemyStateId.FACE_TARGET


func _enter() -> void:
    enemy.velocity = Vector2.ZERO

    var to_target := (enemy.get_target().global_position - enemy.global_position).normalized()
    var facing := enemy.cardinal_snap(to_target)
    enemy.set_facing(facing)
    enemy.face_arrow()

    change_state(SmallEnemyStateId.TELEGRAPH)
