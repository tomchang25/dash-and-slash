# enemy_face_once_state.gd
# Shared state that turns toward the target one capped step (the flank turn cap), then either commits an
# attack (if the new facing allows) or returns to idle. Repeated entries turn further, so aligning on a
# flanker costs player actions. Committing an attack parks the machine back in idle for post-recovery.
class_name EnemyFaceOnceState
extends EnemyState

func _init() -> void:
    state_id = EnemyStateId.FACE_TARGET


func _advance_tick() -> void:
    enemy.tick_face_toward_target()
    if enemy.should_commit_after_face():
        enemy.try_commit_attack()
    change_state(enemy.get_idle_state_id())
