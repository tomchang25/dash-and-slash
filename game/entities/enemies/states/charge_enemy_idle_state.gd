# charge_enemy_idle_state.gd
# Idle state — waits for cooldown/stagger to clear, then commits the next action.
extends ChargeEnemyState

func _init() -> void:
    state_id = ChargeEnemyStateId.IDLE


func _enter() -> void:
    enemy.velocity = Vector2.ZERO


func _physics_update(_delta: float) -> void:
    if not enemy.has_target():
        return
    if enemy.cooldown_active() or enemy.is_staggered():
        enemy.velocity = Vector2.ZERO
        return

    if enemy.is_player_in_same_line():
        change_state(ChargeEnemyStateId.CHARGE_TELEGRAPH)
        return

    if not enemy.plan_next_action():
        enemy.velocity = Vector2.ZERO
        return

    if enemy.has_planned_path():
        change_state(ChargeEnemyStateId.REPOSITION_STEP)
    else:
        change_state(ChargeEnemyStateId.FACE_ONCE)
