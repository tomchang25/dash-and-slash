# chase_enemy_idle_state.gd
# Idle state — waits for cooldown/stagger to clear, then commits the next action.
extends ChaseEnemyState

func _init() -> void:
    state_id = ChaseEnemyStateId.IDLE


func _enter() -> void:
    enemy.velocity = Vector2.ZERO


func _physics_update(_delta: float) -> void:
    if not enemy.has_target():
        return
    if enemy.cooldown_active() or enemy.is_staggered():
        enemy.velocity = Vector2.ZERO
        return

    if enemy.is_target_in_puff_range():
        change_state(ChaseEnemyStateId.PUFF)
        return

    if not enemy.plan_next_action():
        enemy.velocity = Vector2.ZERO
        return

    if enemy.has_planned_path():
        change_state(ChaseEnemyStateId.REPOSITION_STEP)
    else:
        change_state(ChaseEnemyStateId.FACE_ONCE)
