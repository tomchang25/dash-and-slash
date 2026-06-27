# charge_enemy_state.gd
# Intermediate State base class for ChargeEnemy states. Provides a typed `enemy`
# reference and the ChargeEnemyStateId enum.
class_name ChargeEnemyState
extends State

enum ChargeEnemyStateId {
    NULL = -1,
    IDLE = 0,
    REPOSITION_STEP = 1,
    FACE_ONCE = 2,
    STAGGERED = 3,
    DEAD = 4,
    CHARGE_TELEGRAPH = 5,
    CHARGE_ATTACK = 6,
    RECOVERY = 7,
}

var enemy: ChargeEnemy


func _ready() -> void:
    await owner.ready
    enemy = owner as ChargeEnemy
