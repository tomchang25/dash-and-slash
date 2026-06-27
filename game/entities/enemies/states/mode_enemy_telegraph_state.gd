# mode_enemy_telegraph_state.gd
# ModeEnemy telegraph state shows warning and charge overlays for the selected mode.
extends EnemyState

var _timer: Timer
var _return_to_idle := false


func _init() -> void:
    state_id = ModeEnemyState.ModeEnemyStateId.TELEGRAPH


func _enter() -> void:
    _return_to_idle = false
    var mode_enemy := enemy as ModeEnemy
    if mode_enemy == null:
        _return_to_idle = true
        return
    mode_enemy.face_target_position()
    if not mode_enemy.prepare_attack():
        _return_to_idle = true
        return

    mode_enemy.show_attack_warning()
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_warning_done)
    # node-src: timer
    add_child(_timer)
    _timer.start(mode_enemy.TELEGRAPH_DURATION)


func _exit() -> void:
    _return_to_idle = false
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _physics_update(_delta: float) -> void:
    if _return_to_idle:
        change_state(ModeEnemyState.ModeEnemyStateId.IDLE)


func _on_warning_done() -> void:
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null

    var mode_enemy := enemy as ModeEnemy
    if mode_enemy != null:
        mode_enemy.show_attack_charge()

    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_charge_done)
    # node-src: timer
    add_child(_timer)
    _timer.start(mode_enemy.CHARGE_DURATION if mode_enemy != null else 0.2)


func _on_charge_done() -> void:
    change_state(ModeEnemyState.ModeEnemyStateId.ATTACK)
