# chase_enemy_state.gd
# Intermediate State base class for ChaseEnemy states. Provides a typed `enemy`
# reference and the ChaseEnemyStateId enum.
class_name ChaseEnemyState
extends State

enum ChaseEnemyStateId {
    NULL = -1,
    IDLE = 0,
    REPOSITION_STEP = 1,
    FACE_ONCE = 2,
    STAGGERED = 3,
    DEAD = 4,
    PUFF = 5,
}

var enemy: ChaseEnemy


func _ready() -> void:
    await owner.ready
    enemy = owner as ChaseEnemy
