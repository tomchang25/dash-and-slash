# player_state.gd
# Intermediate State base class for Player states. Provides a typed `player`
# reference and the PlayerStateId enum so state scripts don't need repeated casts.
class_name PlayerState
extends State

enum PlayerStateId {
    NULL = -1,
    IDLE = 0,
    MOVE = 1,
    ATTACK = 2,
    DASH = 3,
}

var player: Player


func _ready() -> void:
    await owner.ready
    player = owner as Player
