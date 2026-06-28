# small_enemy_telegraph_state.gd
# Telegraph state — two-phase: WARNING (grid overlay, 0.6 s) then CHARGE
# (grid overlay + attack VFX spawn, 0.2 s) before transitioning to ATTACK.
extends SmallEnemyState

var _timer: Timer
var _return_to_idle := false


func _init() -> void:
    state_id = SmallEnemyStateId.TELEGRAPH


func _enter() -> void:
    _return_to_idle = false
    if not enemy.begin_attack_telegraph():
        _return_to_idle = true
        return

    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_warning_done)
    add_child(_timer)
    _timer.start(enemy.WARNING_DURATION)


func _exit() -> void:
    _return_to_idle = false
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _physics_update(_delta: float) -> void:
    if _return_to_idle:
        change_state(SmallEnemyStateId.IDLE)


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
    change_state(SmallEnemyStateId.ATTACK)
