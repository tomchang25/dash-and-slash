# enemy_attack_state.gd
# Shared attack state that starts the attack through the enemy's API, ticks for
# the attack duration, and updates attack motion each physics frame.
class_name EnemyAttackState
extends EnemyState

var _timer: Timer
var _return_to_idle := false


func _init() -> void:
    state_id = EnemyStateId.ATTACK


func _enter() -> void:
    _return_to_idle = false
    enemy.velocity = Vector2.ZERO
    enemy.begin_attack()

    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_attack_timeout)
    # node-src: timer
    add_child(_timer)
    _timer.start(enemy.get_attack_duration())


func _exit() -> void:
    _return_to_idle = false
    enemy.end_attack()
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _physics_update(delta: float) -> void:
    if _return_to_idle:
        change_state(enemy.get_recovery_state_id())
        return
    if enemy.update_attack_motion(delta):
        change_state(enemy.get_recovery_state_id())


func _on_attack_timeout() -> void:
    _return_to_idle = true
