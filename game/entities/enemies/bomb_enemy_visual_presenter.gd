# bomb_enemy_visual_presenter.gd
# BombEnemy-specific action feedback: a slow fuse blink during windup that speeds up on the final
# tick. Blinking pulses the sprite's own self_modulate alpha, a separate channel from the base
# presenter's modulate-driven damage flash, so the two never race for the same property.
class_name BombEnemyVisualPresenter
extends EnemyVisualPresenter

const SLOW_BLINK_INTERVAL := 0.22
const FAST_BLINK_INTERVAL := 0.09
const BLINK_HIDDEN_ALPHA := 0.35

# == Common API ==


## Returns to a clean idle pose and clears any in-progress fuse blink alpha.
func show_idle() -> void:
    super()
    _reset_fuse_alpha()


## Resets visuals to a clean idle/base-tint state and clears any in-progress fuse blink alpha.
func reset_visuals() -> void:
    super()
    _reset_fuse_alpha()

# == Feature: action feedback ==


func _play_prepare_attack_feedback() -> void:
    _start_fuse_blink(SLOW_BLINK_INTERVAL)


func _play_attack_commit_feedback() -> void:
    _start_fuse_blink(FAST_BLINK_INTERVAL)


func _start_fuse_blink(interval: float) -> void:
    _frame_view.self_modulate.a = 1.0
    var tween := _create_action_tween()
    tween.set_loops()
    tween.tween_property(_frame_view, "self_modulate:a", BLINK_HIDDEN_ALPHA, interval).set_trans(Tween.TRANS_SINE)
    tween.tween_property(_frame_view, "self_modulate:a", 1.0, interval).set_trans(Tween.TRANS_SINE)


func _reset_fuse_alpha() -> void:
    _frame_view.self_modulate.a = 1.0
