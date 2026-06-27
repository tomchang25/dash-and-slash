# enemy_recovery_state.gd
# Shared recovery state that starts cooldown and returns to idle.
class_name EnemyRecoveryState
extends EnemyState

var _timer: Timer


func _enter() -> void:
    enemy.velocity = Vector2.ZERO
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_recovery_done)
    # node-src: timer
    add_child(_timer)
    _timer.start(enemy.RECOVERY_DURATION)


func _exit() -> void:
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _on_recovery_done() -> void:
    enemy.start_cooldown()
    change_state(enemy.get_idle_state_id())
