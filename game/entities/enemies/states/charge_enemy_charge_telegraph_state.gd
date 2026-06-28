# charge_enemy_charge_telegraph_state.gd
# Telegraph phase of the charge attack. Shows WARNING overlay on all cells
# from the enemy's current position to the grid edge in the facing direction,
# then transitions to CHARGE overlay and moves to the attack state.
extends ChargeEnemyState

var _timer: Timer
var _return_to_idle := false


func _init() -> void:
    state_id = ChargeEnemyStateId.CHARGE_TELEGRAPH


func _enter() -> void:
    _return_to_idle = false
    if not enemy.begin_attack_telegraph():
        _return_to_idle = true
        return

    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_warning_done)
    add_child(_timer)
    _timer.start(enemy.get_warning_duration())


func _exit() -> void:
    _return_to_idle = false
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _physics_update(_delta: float) -> void:
    if _return_to_idle:
        change_state(ChargeEnemyStateId.IDLE)


func _on_warning_done() -> void:
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null

    var telegraph := enemy.get_telegraph()
    if telegraph != null:
        telegraph.show_charge(enemy.get_stored_charge_cells())

    change_state(ChargeEnemyStateId.CHARGE_ATTACK)
