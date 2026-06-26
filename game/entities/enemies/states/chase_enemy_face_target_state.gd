# chase_enemy_face_target_state.gd
# Face once state — faces the current player position, then returns to IDLE.
# The ChaseEnemy has no triggered attack to telegraph; damage comes from the
# always-on ContactHitbox.
extends ChaseEnemyState

func _init() -> void:
    state_id = ChaseEnemyStateId.FACE_ONCE


func _enter() -> void:
    enemy.velocity = Vector2.ZERO
    enemy.face_target_position()


func _physics_update(_delta: float) -> void:
    change_state(ChaseEnemyStateId.IDLE)
