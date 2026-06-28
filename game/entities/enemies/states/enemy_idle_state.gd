# enemy_idle_state.gd
# Shared idle state that waits for cooldown/stagger, then plans or attacks.
class_name EnemyIdleState
extends EnemyState

func _init() -> void:
    state_id = EnemyStateId.IDLE


func _enter() -> void:
    enemy.velocity = Vector2.ZERO


func _physics_update(_delta: float) -> void:
    if not enemy.has_target():
        return
    if enemy.cooldown_active() or enemy.is_staggered():
        enemy.velocity = Vector2.ZERO
        return

    var pre_plan_state_id := enemy.get_pre_plan_state_id()
    if pre_plan_state_id >= 0:
        change_state(pre_plan_state_id)
        return

    if not enemy.plan_next_action():
        enemy.velocity = Vector2.ZERO
        return

    if enemy.has_planned_path():
        change_state(enemy.get_reposition_state_id())
    else:
        change_state(enemy.get_face_state_id())
