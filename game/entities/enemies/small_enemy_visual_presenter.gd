# small_enemy_visual_presenter.gd
# SmallEnemy-specific action feedback for the shared enemy visual presenter contract.
class_name SmallEnemyVisualPresenter
extends EnemyVisualPresenter

# -- Constants --

const MOVE_LEAN_SEC := 0.08
const MOVE_SETTLE_SEC := 0.1
const MOVE_OFFSET := 7.0
const MOVE_SCALE := Vector2(1.05, 0.95)
const MOVE_ROTATION := 0.08
const PREPARE_SQUASH_SEC := 0.12
const PREPARE_SCALE := Vector2(1.12, 0.84)
const COMMIT_POP_SEC := 0.06
const COMMIT_SETTLE_SEC := 0.09
const COMMIT_SCALE := Vector2(1.2, 0.78)

# == Feature: action feedback ==


func _play_move_feedback() -> void:
    var forward := _display_forward()
    position = -forward * 2.0
    rotation = _side_rotation(MOVE_ROTATION)
    scale = MOVE_SCALE

    var tween := _create_action_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "position", forward * MOVE_OFFSET, MOVE_LEAN_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", Vector2.ONE, MOVE_SETTLE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "rotation", 0.0, MOVE_SETTLE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_prepare_attack_feedback() -> void:
    scale = Vector2.ONE
    var tween := _create_action_tween()
    tween.tween_property(self, "scale", PREPARE_SCALE, PREPARE_SQUASH_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_attack_commit_feedback() -> void:
    scale = PREPARE_SCALE
    var tween := _create_action_tween()
    tween.tween_property(self, "scale", COMMIT_SCALE, COMMIT_POP_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", Vector2.ONE, COMMIT_SETTLE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
