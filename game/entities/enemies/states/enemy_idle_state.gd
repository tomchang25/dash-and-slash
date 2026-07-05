# enemy_idle_state.gd
# Shared idle state. On each world tick it plans the next action and hands off to attack, reposition,
# or face. Recovery and stagger gating happen in the engine's status pass, so idle only runs when the
# enemy is enabled this tick.
class_name EnemyIdleState
extends EnemyState

func _init() -> void:
    state_id = EnemyStateId.IDLE


func _advance_tick() -> void:
    if not enemy.has_target():
        return

    var pre_plan_state_id := enemy.get_pre_plan_state_id()
    if pre_plan_state_id >= 0:
        change_state(pre_plan_state_id)
        return

    if not enemy.plan_next_action():
        # Nothing reachable this tick; retry on the next player action.
        return

    if enemy.has_planned_path():
        change_state(enemy.get_reposition_state_id())
    else:
        change_state(enemy.get_face_state_id())
