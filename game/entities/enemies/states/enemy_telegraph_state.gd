# enemy_telegraph_state.gd
# Shared telegraph state. On enter it commits the tick-clocked attack (locks the footprint tiles and
# starts the player-action countdown); the engine then counts the telegraph down and detonates it,
# freezing the enemy until impact. This state only steps when the commit failed, to bail back to idle.
class_name EnemyTelegraphState
extends EnemyState

var _return_to_idle := false


func _init() -> void:
    state_id = EnemyStateId.TELEGRAPH


func _enter() -> void:
    _return_to_idle = not enemy.begin_tick_telegraph()


func _exit() -> void:
    _return_to_idle = false


func _advance_tick() -> void:
    # Reached only when the commit failed; a committed telegraph freezes act_tick until it detonates.
    if _return_to_idle:
        change_state(EnemyStateId.IDLE)
