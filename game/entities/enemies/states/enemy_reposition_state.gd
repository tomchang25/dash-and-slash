# enemy_reposition_state.gd
# Shared one-cell grid reposition state for 1x1 enemies. Each world tick snaps the enemy one reserved
# cell along its planned path, then re-decides: keep stepping, attack on arrival, face, or idle.
class_name EnemyRepositionState
extends EnemyState

func _init() -> void:
    state_id = EnemyStateId.REPOSITION


func _advance_tick() -> void:
    if not enemy.tick_step_along_path():
        # Path exhausted or reservation lost before stepping; re-decide from idle.
        change_state(enemy.get_idle_state_id())
        return

    var arrival_override_state_id := enemy.get_arrival_override_state_id()
    if arrival_override_state_id >= 0:
        change_state(arrival_override_state_id)
        return

    if not enemy.plan_next_action():
        change_state(enemy.get_idle_state_id())
        return

    if enemy.has_planned_path():
        # More path to travel; step again on the next tick.
        return

    change_state(enemy.get_face_state_id())
