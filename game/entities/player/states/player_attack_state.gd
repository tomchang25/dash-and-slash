# player_attack_state.gd
# Normal attack state — positions the capsule attack hitbox toward the mouse aim
# direction, plays attack SFX and VFX, allows slight drift movement, and
# transitions back to IDLE after the player's resolved attack duration.
extends PlayerState

var _timer: Timer


func _init() -> void:
    state_id = PlayerStateId.ATTACK


func _enter() -> void:
    var aim_dir := player.get_aim_direction()
    player.begin_normal_attack(aim_dir)
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_timer_timeout)

    add_child(_timer)

    _timer.start(player.get_normal_attack_duration())


func _physics_update(_delta: float) -> void:
    var dir := player.get_move_input()
    player.velocity = dir * (player.MOVE_SPEED * 0.3)


func _exit() -> void:
    player.end_normal_attack()
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _on_timer_timeout() -> void:
    change_state(PlayerStateId.IDLE)
