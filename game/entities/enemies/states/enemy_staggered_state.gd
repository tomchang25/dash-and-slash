# enemy_staggered_state.gd
# Shared stagger state that waits for Guard recovery before returning to idle.
class_name EnemyStaggeredState
extends EnemyState

func _init() -> void:
    state_id = EnemyStateId.STAGGERED


func _enter() -> void:
    var guard: Guard = enemy.get_guard()
    if guard != null and not guard.stagger_ended.is_connected(_on_stagger_ended):
        guard.stagger_ended.connect(_on_stagger_ended)


func _exit() -> void:
    var guard: Guard = enemy.get_guard()
    if guard != null and guard.stagger_ended.is_connected(_on_stagger_ended):
        guard.stagger_ended.disconnect(_on_stagger_ended)


func _on_stagger_ended() -> void:
    change_state(enemy.get_idle_state_id())
