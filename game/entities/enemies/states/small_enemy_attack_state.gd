# small_enemy_attack_state.gd
# Attack state — positions the hitbox in front of the enemy, enables it for
# ATTACK_DURATION, then transitions to RECOVERY.
extends SmallEnemyState

var _timer: Timer
var _return_to_idle := false


func _init() -> void:
    state_id = SmallEnemyStateId.ATTACK


func _enter() -> void:
    _return_to_idle = false
    var attack := enemy.get_attack_controller()
    if attack == null:
        _return_to_idle = true
        return

    attack.begin_attack()

    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_timer_timeout)
    # node-src: timer
    add_child(_timer)
    _timer.start(enemy.ATTACK_DURATION)


func _exit() -> void:
    _return_to_idle = false
    var attack := enemy.get_attack_controller()
    if attack != null:
        attack.end_attack()
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _on_timer_timeout() -> void:
    change_state(SmallEnemyStateId.RECOVERY)


func _physics_update(_delta: float) -> void:
    if _return_to_idle:
        change_state(SmallEnemyStateId.IDLE)
