# player_idle_state.gd
# Idle state — stops movement, waits for attack / dash / move input to transition.
extends PlayerState

func _init() -> void:
    state_id = PlayerStateId.IDLE


func _enter() -> void:
    player.velocity = Vector2.ZERO


func _physics_update(_delta: float) -> void:
    if player.consume_attack_request():
        change_state(PlayerStateId.ATTACK)
        return
    if player.consume_dash_request():
        change_state(PlayerStateId.DASH)
        return
    if player.get_move_input() != Vector2.ZERO:
        change_state(PlayerStateId.MOVE)
