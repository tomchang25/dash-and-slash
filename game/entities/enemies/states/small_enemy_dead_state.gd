# small_enemy_dead_state.gd
# Dead state plays enemy death feedback, then frees the enemy node.
extends SmallEnemyState

const DEATH_DURATION := 0.5
const DEATH_ROTATION_RADIANS := TAU

var _death_tween: Tween


func _init() -> void:
    state_id = SmallEnemyStateId.DEAD


func _enter() -> void:
    enemy.begin_death()
    enemy.play_death_sfx()

    _death_tween = create_tween()
    _death_tween.set_parallel()
    _death_tween.tween_property(enemy, "scale", Vector2.ZERO, DEATH_DURATION)
    _death_tween.tween_property(enemy, "rotation", enemy.rotation + DEATH_ROTATION_RADIANS, DEATH_DURATION)
    _death_tween.tween_property(enemy, "modulate:a", 0.0, DEATH_DURATION)
    _death_tween.chain()
    _death_tween.tween_callback(_on_death_tween_finished)


func _exit() -> void:
    if _death_tween != null and is_instance_valid(_death_tween):
        _death_tween.kill()


func _on_death_tween_finished() -> void:
    enemy.queue_free()
