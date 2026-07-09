# enemy_idle_state.gd
# Shared idle/decision state. On each world tick it makes one decision: enter a pre-decision state (the
# mode roll), commit an attack, or plan movement and hand off to reposition or face. Committing an attack
# leaves the machine parked here — the runtime freezes the enemy until detonation and recovery end, then
# this state decides again. Recovery and stagger gating happen in the engine's status pass, so idle only
# runs when the enemy is enabled this tick.
class_name EnemyIdleState
extends EnemyState

func _init() -> void:
    state_id = EnemyStateId.IDLE


func _advance_tick() -> void:
    if not enemy.has_target():
        return

    var pre_decision_state_id := enemy.get_pre_decision_state_id()
    if pre_decision_state_id >= 0:
        change_state(pre_decision_state_id)
        return

    if enemy.should_commit_before_plan():
        # A committed attack freezes the enemy via the runtime; the machine stays parked here.
        enemy.try_commit_attack()
        return

    if not enemy.plan_next_action():
        # Nothing reachable this tick; retry on the next player action.
        return

    if enemy.has_planned_path():
        change_state(enemy.get_reposition_state_id())
    else:
        change_state(enemy.get_face_state_id())
