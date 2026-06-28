# enemy_attack_state.gd
# Shared attack state that starts the attack through the enemy's API, ticks for
# the attack duration, and updates attack motion each physics frame.
class_name EnemyAttackState
extends EnemyState

var _timer: Timer
var _return_to_idle := false
var _attack_started := false
var _attack_failed := false


func _init() -> void:
    state_id = EnemyStateId.ATTACK


func _enter() -> void:
    _return_to_idle = false
    _attack_started = false
    _attack_failed = false
    enemy.velocity = Vector2.ZERO
    if not enemy.begin_attack():
        _attack_failed = true
        return
    _attack_started = true

    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_attack_timeout)
    # node-src: timer
    add_child(_timer)
    _timer.start(enemy.get_attack_duration())


func _exit() -> void:
    _return_to_idle = false
    _attack_failed = false
    if _attack_started:
        enemy.end_attack()
    _attack_started = false
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _physics_update(delta: float) -> void:
    if _attack_failed:
        change_state(EnemyStateId.IDLE)
        return
    if _return_to_idle:
        change_state(enemy.get_recovery_state_id())
        return
    if enemy.update_attack_motion(delta):
        change_state(enemy.get_recovery_state_id())


func _on_attack_timeout() -> void:
    _return_to_idle = true
