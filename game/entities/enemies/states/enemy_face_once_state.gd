# enemy_face_once_state.gd
# Shared state that turns toward the target one capped step (the flank turn cap), then either commits an
# attack (if the new facing allows) or returns to idle. Repeated entries turn further, so aligning on a
# flanker costs player actions. Committing an attack parks the machine back in idle for post-recovery.
# Also the funded destination for a hit-triggered facing response (GridEnemy._queue_hit_facing_response()):
# this state's funded advance_tick is what actually turns, so it consumes the pending response here,
# never on entry, which is why a Speed free action (no act_tick()) leaves it visibly still pending.
class_name EnemyFaceOnceState
extends EnemyState

func _init() -> void:
    state_id = EnemyStateId.FACE_TARGET


func _advance_tick() -> void:
    enemy.consume_pending_hit_facing_response()
    enemy.tick_face_toward_target()
    if enemy.should_commit_after_face():
        enemy.try_commit_attack()
    change_state(enemy.get_idle_state_id())
