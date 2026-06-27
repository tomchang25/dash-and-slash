# boss_idle_state.gd
# Idle state waits for cooldown/stagger to clear before choosing the next boss mode.
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

    enemy.choose_next_mode()
    change_state(BossStateId.FACE_TARGET)
