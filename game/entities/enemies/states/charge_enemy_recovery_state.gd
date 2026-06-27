# charge_enemy_recovery_state.gd
# Recovery state after a charge attack. Stops movement, waits for
# RECOVERY_DURATION (3s), then starts the cycle cooldown and returns to IDLE.
extends ChargeEnemyState

var _timer: Timer


func _init() -> void:
    state_id = ChargeEnemyStateId.RECOVERY


func _enter() -> void:
    enemy.velocity = Vector2.ZERO
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_recovery_done)
    add_child(_timer)
    _timer.start(enemy.RECOVERY_DURATION)


func _exit() -> void:
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _on_recovery_done() -> void:
    enemy.start_cooldown()
    change_state(ChargeEnemyStateId.IDLE)
