# mode_enemy_attack_state.gd
# ModeEnemy attack state activates the selected mode until duration or charge motion ends.
extends EnemyState

var _timer: Timer
var _attack_done := false


func _init() -> void:
    state_id = ModeEnemyState.ModeEnemyStateId.ATTACK


func _enter() -> void:
    _attack_done = false
    var mode_enemy := enemy as ModeEnemy
    if mode_enemy == null:
        _attack_done = true
        return

    mode_enemy.begin_attack()
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_attack_timeout)
    # node-src: timer
    add_child(_timer)
    _timer.start(mode_enemy.get_attack_duration())


func _exit() -> void:
    var mode_enemy := enemy as ModeEnemy
    if mode_enemy != null:
        mode_enemy.end_attack()
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _physics_update(delta: float) -> void:
    if _attack_done:
        change_state(ModeEnemyState.ModeEnemyStateId.RECOVERY)
        return
    var mode_enemy := enemy as ModeEnemy
    if mode_enemy != null and mode_enemy.update_attack_motion(delta):
        change_state(ModeEnemyState.ModeEnemyStateId.RECOVERY)


func _on_attack_timeout() -> void:
    _attack_done = true
