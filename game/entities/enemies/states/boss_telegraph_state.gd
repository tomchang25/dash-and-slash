# boss_telegraph_state.gd
# Telegraph state shows warning then charge overlays for the selected boss mode.
extends BossState

var _timer: Timer
var _return_to_idle := false


func _init() -> void:
    state_id = BossStateId.TELEGRAPH


func _enter() -> void:
    _return_to_idle = false
    if not enemy.prepare_attack():
        _return_to_idle = true
        return

    enemy.show_attack_warning()
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_warning_done)
    add_child(_timer)
    _timer.start(enemy.TELEGRAPH_DURATION)


func _exit() -> void:
    _return_to_idle = false
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _physics_update(_delta: float) -> void:
    if _return_to_idle:
        change_state(BossStateId.IDLE)


func _on_warning_done() -> void:
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null

    enemy.show_attack_charge()
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_charge_done)
    add_child(_timer)
    _timer.start(enemy.CHARGE_DURATION)


func _on_charge_done() -> void:
    change_state(BossStateId.ATTACK)
