# small_enemy_idle_state.gd
# Idle state — waits for cooldown/stagger to clear, then decides next action:
# attack if in range, reposition if not.
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
    if enemy.can_attack():
        change_state(SmallEnemyStateId.FACE_TARGET)
    else:
        change_state(SmallEnemyStateId.REPOSITION)
