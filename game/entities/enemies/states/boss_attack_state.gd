# boss_attack_state.gd
# Attack state activates the selected boss mode until its duration or motion ends.
extends BossState

var _timer: Timer
var _attack_done := false


func _init() -> void:
    state_id = BossStateId.ATTACK


func _enter() -> void:
    _attack_done = false
    enemy.begin_attack()
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_attack_timeout)
    add_child(_timer)
    _timer.start(enemy.ATTACK_DURATION)


func _exit() -> void:
    enemy.end_attack()
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _physics_update(delta: float) -> void:
    if _attack_done:
        change_state(BossStateId.RECOVERY)
        return
    if enemy.update_attack_motion(delta):
        change_state(BossStateId.RECOVERY)


func _on_attack_timeout() -> void:
    _attack_done = true
