# enemy_telegraph_state.gd
# Shared telegraph state that drives warning and charge phases via the enemy's
# attack lifecycle API, then transitions to the attack state.
class_name EnemyTelegraphState
extends EnemyState

var _timer: Timer
var _return_to_idle := false


func _init() -> void:
    state_id = EnemyStateId.TELEGRAPH


func _enter() -> void:
    _return_to_idle = false
    if not enemy.begin_attack_telegraph():
        _return_to_idle = true
        return

    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_warning_done)
    # node-src: timer
    add_child(_timer)
    _timer.start(enemy.get_warning_duration())


func _exit() -> void:
    _return_to_idle = false
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _physics_update(_delta: float) -> void:
    if _return_to_idle:
        change_state(EnemyStateId.IDLE)


func _on_warning_done() -> void:
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null

    enemy.show_attack_charge()

    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_charge_done)
    # node-src: timer
    add_child(_timer)
    _timer.start(enemy.get_charge_duration())


func _on_charge_done() -> void:
    change_state(enemy.get_attack_state_id())
