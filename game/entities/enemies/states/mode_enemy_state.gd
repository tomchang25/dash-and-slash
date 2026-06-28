# mode_enemy_state.gd
# State ID namespace for ModeEnemy states.
class_name ModeEnemyState
extends EnemyState

enum ModeEnemyStateId {
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
}
