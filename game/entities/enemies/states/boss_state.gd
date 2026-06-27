# boss_state.gd
# Intermediate State base class for Boss states with typed owner access.
class_name BossState
extends State

enum BossStateId {
    NULL = -1,
    IDLE = 0,
    REPOSITION = 1,
    FACE_TARGET = 2,
    TELEGRAPH = 3,
    ATTACK = 4,
    RECOVERY = 5,
    STAGGERED = 6,
    DEAD = 7,
}

var enemy: Boss


func _ready() -> void:
    await owner.ready
    enemy = owner as Boss
