# mode_enemy_visual_presenter.gd
# ModeEnemy-specific action feedback that adapts the shared presenter contract to its selected attack kind.
class_name ModeEnemyVisualPresenter
extends EnemyVisualPresenter

const MOVE_LEAN_SEC := 0.09
const MOVE_SETTLE_SEC := 0.12
const MOVE_OFFSET := 8.0
const MOVE_SCALE := Vector2(1.08, 0.92)
const MOVE_ROTATION := 0.1
const PREPARE_SQUASH_SEC := 0.12
const PREPARE_SCALE := Vector2(1.14, 0.82)
const CHARGE_PREPARE_PULL_BACK := 9.0
const CHARGE_PREPARE_SCALE := Vector2(1.2, 0.7)
const COMMIT_POP_SEC := 0.06
const COMMIT_SETTLE_SEC := 0.1
const COMMIT_SCALE := Vector2(1.22, 0.78)
const CHARGE_COMMIT_FORWARD := 13.0
const CHARGE_COMMIT_SCALE := Vector2(1.3, 0.68)
const RETALIATION_AURA_FRAME_COUNT := 5
const RETALIATION_AURA_FRAME_SEC := 0.08

# -- State --

var _attack_kind := EnemyAttackData.AttackKind.TILE

# -- Timer / tween handles --

var _retaliation_aura_tween: Tween

# -- Node references --

@onready var _retaliation_aura: Sprite2D = %RetaliationAura

# == Common API ==


## Updates the presentation-only context that selects tile/area or charge action feedback.
func set_attack_kind(attack_kind: int) -> void:
    _attack_kind = attack_kind as EnemyAttackData.AttackKind


## Shows or hides the looping elite-retaliation Aura cue. Independent of action-feedback transforms
## and sprite tint (a separate node, a separate tween) so the cue stays visible through pathing
## delays and empowered windups instead of being cleared by show_idle()/show_move()/etc.
func set_retaliation_active(active: bool) -> void:
    if active:
        _start_retaliation_aura_loop()
    else:
        _stop_retaliation_aura_loop()


## Resets visuals to a clean idle/base-tint state and force-stops any in-progress retaliation Aura
## loop, so a pooled enemy never re-enters play with a stale Aura cue.
func reset_visuals() -> void:
    super()
    _stop_retaliation_aura_loop()

# == Feature: elite retaliation ==


func _start_retaliation_aura_loop() -> void:
    if _retaliation_aura == null:
        return
    _retaliation_aura.visible = true
    if _retaliation_aura_tween != null and is_instance_valid(_retaliation_aura_tween):
        return
    _retaliation_aura_tween = create_tween()
    _retaliation_aura_tween.set_loops()
    for frame_index in range(RETALIATION_AURA_FRAME_COUNT):
        _retaliation_aura_tween.tween_callback(_retaliation_aura.set.bind("frame", frame_index))
        _retaliation_aura_tween.tween_interval(RETALIATION_AURA_FRAME_SEC)


func _stop_retaliation_aura_loop() -> void:
    if _retaliation_aura_tween != null and is_instance_valid(_retaliation_aura_tween):
        _retaliation_aura_tween.kill()
    _retaliation_aura_tween = null
    if _retaliation_aura != null:
        _retaliation_aura.visible = false

# == Feature: action feedback ==


func _play_move_feedback() -> void:
    var forward := _display_forward()
    position = -forward * 3.0
    rotation = _side_rotation(MOVE_ROTATION)
    scale = MOVE_SCALE

    var tween := _create_action_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "position", forward * MOVE_OFFSET, MOVE_LEAN_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", Vector2.ONE, MOVE_SETTLE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "rotation", 0.0, MOVE_SETTLE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_prepare_attack_feedback() -> void:
    if _attack_kind == EnemyAttackData.AttackKind.CHARGE:
        _play_charge_prepare_feedback()
        return

    scale = Vector2.ONE
    var tween := _create_action_tween()
    tween.tween_property(self, "scale", PREPARE_SCALE, PREPARE_SQUASH_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_attack_commit_feedback() -> void:
    if _attack_kind == EnemyAttackData.AttackKind.CHARGE:
        _play_charge_commit_feedback()
        return

    scale = PREPARE_SCALE
    var tween := _create_action_tween()
    tween.tween_property(self, "scale", COMMIT_SCALE, COMMIT_POP_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", Vector2.ONE, COMMIT_SETTLE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_charge_prepare_feedback() -> void:
    var forward := _display_forward()
    position = -forward * CHARGE_PREPARE_PULL_BACK
    scale = Vector2.ONE

    var tween := _create_action_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "position", -forward * (CHARGE_PREPARE_PULL_BACK * 1.4), PREPARE_SQUASH_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", CHARGE_PREPARE_SCALE, PREPARE_SQUASH_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_charge_commit_feedback() -> void:
    var forward := _display_forward()
    position = -forward * CHARGE_PREPARE_PULL_BACK
    scale = CHARGE_PREPARE_SCALE

    var tween := _create_action_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "position", forward * CHARGE_COMMIT_FORWARD, COMMIT_POP_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", CHARGE_COMMIT_SCALE, COMMIT_POP_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.chain().tween_property(self, "scale", Vector2.ONE, COMMIT_SETTLE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
