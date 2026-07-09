# charge_enemy_visual_presenter.gd
# ChargeEnemy-specific action feedback for the shared enemy visual presenter contract.
class_name ChargeEnemyVisualPresenter
extends EnemyVisualPresenter

# -- Constants --

const MOVE_LEAN_SEC := 0.07
const MOVE_SETTLE_SEC := 0.12
const MOVE_OFFSET := 11.0
const MOVE_SCALE := Vector2(1.12, 0.88)
const MOVE_ROTATION := 0.12
const PREPARE_PULL_BACK := 9.0
const PREPARE_SQUASH_SEC := 0.14
const PREPARE_SCALE := Vector2(1.18, 0.72)
const COMMIT_LUNGE_SEC := 0.05
const COMMIT_SETTLE_SEC := 0.1
const COMMIT_FORWARD := 13.0
const COMMIT_SCALE := Vector2(1.28, 0.7)

# == Feature: action feedback ==


func _play_move_feedback() -> void:
    var forward := _display_forward()
    position = -forward * 4.0
    rotation = _side_rotation(MOVE_ROTATION)
    scale = MOVE_SCALE

    var tween := _create_action_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "position", forward * MOVE_OFFSET, MOVE_LEAN_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", Vector2.ONE, MOVE_SETTLE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "rotation", 0.0, MOVE_SETTLE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_prepare_attack_feedback() -> void:
    var forward := _display_forward()
    position = -forward * PREPARE_PULL_BACK
    scale = Vector2.ONE

    var tween := _create_action_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "position", -forward * (PREPARE_PULL_BACK * 1.4), PREPARE_SQUASH_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", PREPARE_SCALE, PREPARE_SQUASH_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_attack_commit_feedback() -> void:
    var forward := _display_forward()
    position = -forward * PREPARE_PULL_BACK
    scale = PREPARE_SCALE

    var tween := _create_action_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "position", forward * COMMIT_FORWARD, COMMIT_LUNGE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", COMMIT_SCALE, COMMIT_LUNGE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.chain().tween_property(self, "scale", Vector2.ONE, COMMIT_SETTLE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _display_forward() -> Vector2:
    if _facing == Vector2.ZERO:
        return Vector2.DOWN
    return _facing.normalized()


func _side_rotation(amount: float) -> float:
    if _facing == Vector2.LEFT:
        return -amount
    if _facing == Vector2.RIGHT:
        return amount
    return 0.0
