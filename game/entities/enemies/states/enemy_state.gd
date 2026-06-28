# enemy_state.gd
# Shared State base for GridEnemy states with typed owner access.
class_name EnemyState
extends State

enum EnemyStateId {
    NULL = -1,
    IDLE = 0,
    REPOSITION = 1,
    FACE_TARGET = 2,
    TELEGRAPH = 3,
    ATTACK = 4,
    RECOVERY = 5,
    STAGGERED = 6,
    DEAD = 7,
    MODE_CHANGE = 8,
    PUFF = 9,
    CHARGE_ATTACK = 10,
}

var enemy: GridEnemy


func _ready() -> void:
    await owner.ready
    enemy = owner as GridEnemy
