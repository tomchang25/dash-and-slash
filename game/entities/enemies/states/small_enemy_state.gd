# small_enemy_state.gd
# Intermediate State base class for SmallEnemy states. Provides a typed `enemy`
# reference and the SmallEnemyStateId enum so state scripts don't need repeated casts.
class_name SmallEnemyState
extends State

enum SmallEnemyStateId {
    NULL = -1,
    IDLE = 0,
    REPOSITION_STEP = 1,
    FACE_ONCE = 2,
    TELEGRAPH = 3,
    ATTACK = 4,
    RECOVERY = 5,
    STAGGERED = 6,
}

var enemy: SmallEnemy


func _ready() -> void:
    await owner.ready
    enemy = owner as SmallEnemy
