# player_move_state.gd
# Move state — reads live input and sets velocity every physics frame.
# Transitions: attack / dash override, idle when input released.
extends PlayerState

func _init() -> void:
    state_id = PlayerStateId.MOVE


func _physics_update(_delta: float) -> void:
    if player.consume_attack_request():
        change_state(PlayerStateId.ATTACK)
        return
    if player.consume_dash_request():
        change_state(PlayerStateId.DASH)
        return

    var dir := player.get_move_input()
    if dir == Vector2.ZERO:
        change_state(PlayerStateId.IDLE)
        return

    var spd := player.MOVE_SPEED
    if Input.is_action_pressed("sprint"):
        spd *= 1.5
    player.velocity = dir * spd
