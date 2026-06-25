# small_enemy_recovery_state.gd
# Recovery state — waits RECOVERY_DURATION, then starts the cycle cooldown and
# transitions back to IDLE.
extends SmallEnemyState

var _timer: Timer


func _init() -> void:
    state_id = SmallEnemyStateId.RECOVERY


func _enter() -> void:
    enemy.velocity = Vector2.ZERO

    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_timer_timeout)
    add_child(_timer)
    _timer.start(enemy.RECOVERY_DURATION)


func _exit() -> void:
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _on_timer_timeout() -> void:
    enemy.start_cooldown()
    change_state(SmallEnemyStateId.IDLE)
