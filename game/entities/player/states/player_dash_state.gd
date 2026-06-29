# player_dash_state.gd
# Dash state — enables the dash hitbox, moves at dash speed in the captured
# direction, and transitions back to IDLE after DASH_DURATION.
extends PlayerState

var _timer: Timer
var _dash_dir: Vector2
var _dash_hit_landed := false


func _init() -> void:
    state_id = PlayerStateId.DASH


func _enter() -> void:
    _dash_hit_landed = false
    if not player.dash_hit_landed.is_connected(_on_dash_hit_landed):
        player.dash_hit_landed.connect(_on_dash_hit_landed)
    player.begin_dash_invulnerability()
    player.enable_dash_hitbox()
    _dash_dir = player.consume_dash_direction()
    player.begin_dash_vfx(_dash_dir)
    player.velocity = _dash_dir * player.DASH_SPEED
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_timer_timeout)
    add_child(_timer)
    _timer.start(player.DASH_DURATION)


func _physics_update(delta: float) -> void:
    player.update_dash_vfx(delta)
    player.velocity = _dash_dir * player.DASH_SPEED


func _exit() -> void:
    player.end_dash_vfx()
    player.disable_dash_hitbox()
    if player.dash_hit_landed.is_connected(_on_dash_hit_landed):
        player.dash_hit_landed.disconnect(_on_dash_hit_landed)
    if not _dash_hit_landed:
        player.end_dash_invulnerability()
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _on_timer_timeout() -> void:
    change_state(PlayerStateId.IDLE)


func _on_dash_hit_landed() -> void:
    _dash_hit_landed = true
    player.extend_dash_invulnerability(player.DASH_INVULN_EXTEND)
