# player_dash_state.gd
# Dash state — enables the dash hitbox, moves at dash speed in the captured
# direction, and transitions back to IDLE after DASH_DURATION.
extends PlayerState

var _timer: Timer
var _dash_dir: Vector2


func _init() -> void:
    state_id = PlayerStateId.DASH


func _enter() -> void:
    player.enable_dash_hitbox()
    _dash_dir = player.consume_dash_direction()
    player.velocity = _dash_dir * player.DASH_SPEED
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_timer_timeout)
    add_child(_timer)
    _timer.start(player.DASH_DURATION)


func _physics_update(_delta: float) -> void:
    player.velocity = _dash_dir * player.DASH_SPEED


func _exit() -> void:
    player.disable_dash_hitbox()
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _on_timer_timeout() -> void:
    change_state(PlayerStateId.IDLE)
