# boss_state.gd
# Intermediate State base class for Boss states with typed owner access.
class_name BossState
extends State

enum BossStateId {
    NULL = -1,
    IDLE = 0,
    FACE_TARGET = 1,
    TELEGRAPH = 2,
    ATTACK = 3,
    RECOVERY = 4,
    STAGGERED = 5,
    DEAD = 6,
}

var enemy: Boss


func _ready() -> void:
    await owner.ready
    enemy = owner as Boss
