# puff_enemy_staggered_state.gd
# Staggered state waits for Guard to recover.
extends PuffEnemyState

func _init() -> void:
    state_id = PuffEnemyStateId.STAGGERED


func _enter() -> void:
    enemy.velocity = Vector2.ZERO
    var guard: Guard = enemy.get_guard()
    if guard != null and not guard.stagger_ended.is_connected(_on_stagger_ended):
        guard.stagger_ended.connect(_on_stagger_ended)


func _exit() -> void:
    var guard: Guard = enemy.get_guard()
    if guard != null and guard.stagger_ended.is_connected(_on_stagger_ended):
        guard.stagger_ended.disconnect(_on_stagger_ended)


func _on_stagger_ended() -> void:
    change_state(PuffEnemyStateId.IDLE)
