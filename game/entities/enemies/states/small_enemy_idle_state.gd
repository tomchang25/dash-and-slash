# small_enemy_idle_state.gd
# Idle state — waits for cooldown/stagger to clear, then commits the next action.
extends SmallEnemyState

func _init() -> void:
    state_id = SmallEnemyStateId.IDLE


func _enter() -> void:
    enemy.velocity = Vector2.ZERO


func _physics_update(_delta: float) -> void:
    if not enemy.has_target():
        return
    if enemy.cooldown_active() or enemy.is_staggered():
        enemy.velocity = Vector2.ZERO
        return
    if not enemy.plan_next_action():
        enemy.velocity = Vector2.ZERO
        return

    if enemy.has_planned_path():
        change_state(SmallEnemyStateId.REPOSITION_STEP)
    else:
        change_state(SmallEnemyStateId.FACE_ONCE)
