# puff_enemy_state.gd
# Intermediate State base class for PuffEnemy states. Provides a typed `enemy`
# reference and the PuffEnemyStateId enum.
class_name PuffEnemyState
extends State

enum PuffEnemyStateId {
    NULL = -1,
    IDLE = 0,
    REPOSITION_STEP = 1,
    FACE_ONCE = 2,
    STAGGERED = 3,
    DEAD = 4,
    PUFF = 5,
}

var enemy: PuffEnemy


func _ready() -> void:
    await owner.ready
    enemy = owner as PuffEnemy
