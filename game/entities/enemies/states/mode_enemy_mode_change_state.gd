# mode_enemy_mode_change_state.gd
# ModeEnemy state that previews colors for 3 seconds before choosing a random mode.
extends EnemyState

var _elapsed := 0.0


func _init() -> void:
    state_id = ModeEnemyState.ModeEnemyStateId.MODE_CHANGE


func _enter() -> void:
    _elapsed = 0.0
    enemy.begin_committed_action()


func _physics_update(delta: float) -> void:
    var mode_enemy := enemy as ModeEnemy
    if mode_enemy == null:
        change_state(ModeEnemyState.ModeEnemyStateId.IDLE)
        return

    _elapsed += delta
    var preview_index := int(floor(_elapsed / mode_enemy.get_mode_preview_interval())) % ModeEnemyAttackController.MODE_COUNT
    mode_enemy.set_preview_mode(preview_index)

    if _elapsed >= mode_enemy.MODE_CHANGE_DURATION:
        mode_enemy.choose_random_mode()
        change_state(ModeEnemyState.ModeEnemyStateId.IDLE)
