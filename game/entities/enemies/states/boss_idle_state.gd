# boss_idle_state.gd
# Idle state waits for cooldown/stagger to clear, then decides: attack if already
# aligned with the player, reposition to get into line, or face the player.
extends BossState

func _init() -> void:
    state_id = BossStateId.IDLE


func _enter() -> void:
    enemy.velocity = Vector2.ZERO


func _physics_update(_delta: float) -> void:
    if not enemy.has_target():
        return
    if enemy.cooldown_active() or enemy.is_staggered():
        enemy.velocity = Vector2.ZERO
        return

    if enemy.is_player_in_same_line():
        enemy.choose_next_mode()
        change_state(BossStateId.FACE_TARGET)
        return

    if not enemy.plan_next_action():
        return

    if enemy.has_planned_path():
        change_state(BossStateId.REPOSITION)
    else:
        enemy.choose_next_mode()
        change_state(BossStateId.FACE_TARGET)
