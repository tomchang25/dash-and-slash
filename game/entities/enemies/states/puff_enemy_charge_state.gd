# puff_enemy_charge_state.gd
# Puff windup state. On enter it commits the tick-clocked puff (locks the zone footprint and starts the
# telegraph countdown). The engine then counts the windup down and runs the active zone; this state holds
# the enemy frozen until the zone ends and only steps to bail back to idle when the commit failed.
extends EnemyState

var _return_to_idle := false


func _init() -> void:
    state_id = EnemyStateId.PUFF_CHARGE


func _enter() -> void:
    _return_to_idle = not (enemy as PuffEnemy).begin_puff_tick()


func _exit() -> void:
    _return_to_idle = false


func _advance_tick() -> void:
    if _return_to_idle:
        change_state(EnemyStateId.IDLE)
