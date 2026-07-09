# enemy_reposition_state.gd
# Shared one-cell grid reposition state for 1x1 enemies. Each world tick snaps the enemy one reserved
# cell along its planned path, then re-decides: commit an attack on arrival, keep stepping, face, or idle.
# Committing an attack parks the machine back in idle, where it resumes after detonation and recovery.
class_name EnemyRepositionState
extends EnemyState

func _init() -> void:
    state_id = EnemyStateId.REPOSITION


func _advance_tick() -> void:
    if not enemy.tick_step_along_path():
        # Path exhausted or reservation lost before stepping; re-decide from idle.
        change_state(enemy.get_idle_state_id())
        return

    if enemy.should_commit_on_arrival():
        # On a successful commit the runtime freezes the enemy; park in idle so it re-decides post-recovery.
        # A failed commit cleared the path, so the next tick's step falls through to idle on its own.
        if enemy.try_commit_attack():
            change_state(enemy.get_idle_state_id())
        return

    if not enemy.plan_next_action():
        change_state(enemy.get_idle_state_id())
        return

    if enemy.has_planned_path():
        # More path to travel; step again on the next tick.
        return

    change_state(enemy.get_face_state_id())
