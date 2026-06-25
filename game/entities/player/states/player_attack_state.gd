# player_attack_state.gd
# Normal attack state — enables the attack hitbox, allows slight drift movement,
# and transitions back to IDLE after ATTACK_DURATION.
extends PlayerState

var _timer: Timer


func _init() -> void:
    state_id = PlayerStateId.ATTACK


func _enter() -> void:
    player.enable_attack_hitbox()
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_timer_timeout)
    add_child(_timer)
    _timer.start(player.ATTACK_DURATION)


func _physics_update(_delta: float) -> void:
    var dir := player.get_move_input()
    player.velocity = dir * (player.MOVE_SPEED * 0.3)


func _exit() -> void:
    player.disable_attack_hitbox()
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _on_timer_timeout() -> void:
    change_state(PlayerStateId.IDLE)
