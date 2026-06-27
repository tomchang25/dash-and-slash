# boss_staggered_state.gd
# Staggered state cancels attacks and waits for Guard recovery.
extends BossState

func _init() -> void:
    state_id = BossStateId.STAGGERED


func _enter() -> void:
    enemy.cancel_attack()
    enemy.velocity = Vector2.ZERO

    var guard := enemy.get_guard()
    if guard != null and not guard.stagger_ended.is_connected(_on_stagger_ended):
        guard.stagger_ended.connect(_on_stagger_ended)


func _exit() -> void:
    var guard := enemy.get_guard()
    if guard != null and guard.stagger_ended.is_connected(_on_stagger_ended):
        guard.stagger_ended.disconnect(_on_stagger_ended)


func _on_stagger_ended() -> void:
    change_state(BossStateId.IDLE)
