# small_enemy_face_target_state.gd
# Face once state — faces the current player position, then starts telegraph
# if the player is still in attack range. Falls back to IDLE to re-plan.
extends SmallEnemyState

func _init() -> void:
    state_id = SmallEnemyStateId.FACE_ONCE


func _enter() -> void:
    enemy.velocity = Vector2.ZERO
    enemy.face_target_position()


func _physics_update(_delta: float) -> void:
    if enemy.can_attack():
        change_state(SmallEnemyStateId.TELEGRAPH)
    else:
        change_state(SmallEnemyStateId.IDLE)
