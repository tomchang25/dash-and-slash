# small_enemy_telegraph_state.gd
# Telegraph state prepares an attack snapshot, shows warning tiles, then attacks.
extends SmallEnemyState

var _timer: Timer
var _return_to_idle := false


func _init() -> void:
    state_id = SmallEnemyStateId.TELEGRAPH


func _enter() -> void:
    _return_to_idle = false
    var attack := enemy.get_attack_controller()
    if attack == null:
        _return_to_idle = true
        return

    if not attack.prepare(enemy.get_grid_pos(), enemy.get_facing()):
        _return_to_idle = true
        return

    attack.show_telegraph()

    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_timer_timeout)
    add_child(_timer)
    _timer.start(enemy.TELEGRAPH_DURATION)


func _exit() -> void:
    _return_to_idle = false
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _physics_update(_delta: float) -> void:
    if _return_to_idle:
        change_state(SmallEnemyStateId.IDLE)


func _on_timer_timeout() -> void:
    change_state(SmallEnemyStateId.ATTACK)
