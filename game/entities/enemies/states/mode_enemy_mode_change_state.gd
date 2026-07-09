# mode_enemy_mode_change_state.gd
# ModeEnemy state that previews the mode colors over a few ticks before locking in a random mode.
extends EnemyState

const MODE_CHANGE_TICKS := 3

var _ticks_elapsed := 0


func _init() -> void:
    state_id = EnemyStateId.MODE_CHANGE


func _enter() -> void:
    _ticks_elapsed = 0
    var mode_enemy := enemy as ModeEnemy
    if mode_enemy != null:
        mode_enemy.begin_mode_change()


func _advance_tick() -> void:
    var mode_enemy := enemy as ModeEnemy
    if mode_enemy == null:
        change_state(EnemyStateId.IDLE)
        return

    mode_enemy.set_preview_mode(_ticks_elapsed % ModeEnemy.MODE_COUNT)
    _ticks_elapsed += 1
    if _ticks_elapsed >= MODE_CHANGE_TICKS:
        mode_enemy.choose_random_mode()
        change_state(EnemyStateId.IDLE)
