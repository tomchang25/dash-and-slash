# enemy_state.gd
# Shared State base for GridEnemy states with typed owner access.
class_name EnemyState
extends State

enum EnemyStateId {
    NULL = -1,
    IDLE = 0,
    REPOSITION = 1,
    FACE_TARGET = 2,
    STAGGERED = 6,
    DEAD = 7,
}

var enemy: GridEnemy


func _ready() -> void:
    await owner.ready
    enemy = owner as GridEnemy
