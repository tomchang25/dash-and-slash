# enemy_idle_state.gd
# Shared idle state that waits for cooldown/stagger, then plans or attacks.
class_name EnemyIdleState
extends EnemyState

const PLAN_RETRY_DELAY := 0.5

var _plan_retry_remaining := 0.0


func _init() -> void:
    state_id = EnemyStateId.IDLE


func _enter() -> void:
    enemy.velocity = Vector2.ZERO


func _physics_update(delta: float) -> void:
    if not enemy.has_target():
        return
    if enemy.cooldown_active() or enemy.is_staggered():
        enemy.velocity = Vector2.ZERO
        return
    if _plan_retry_remaining > 0.0:
        _plan_retry_remaining = maxf(_plan_retry_remaining - delta, 0.0)
        enemy.velocity = Vector2.ZERO
        return

    var pre_plan_state_id := enemy.get_pre_plan_state_id()
    if pre_plan_state_id >= 0:
        _plan_retry_remaining = 0.0
        change_state(pre_plan_state_id)
        return

    if not enemy.plan_next_action():
        _plan_retry_remaining = PLAN_RETRY_DELAY
        enemy.velocity = Vector2.ZERO
        return

    _plan_retry_remaining = 0.0
    if enemy.has_planned_path():
        change_state(enemy.get_reposition_state_id())
    else:
        change_state(enemy.get_face_state_id())
