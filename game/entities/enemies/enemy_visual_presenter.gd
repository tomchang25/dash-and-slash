# enemy_visual_presenter.gd
# Base semantic presenter for enemy frame state, facing, shared feedback, and action-cue interruption.
class_name EnemyVisualPresenter
extends Node2D

# -- Constants --

const DAMAGE_FLASH_COLOR := Color(0.8, 0.2, 0.2, 1.0)
const STAGGER_TINT_COLOR := Color(0.3, 0.5, 1.0, 1.0)
const FLASH_IN_SEC := 0.03
const FLASH_HOLD_SEC := 0.06
const FLASH_OUT_SEC := 0.08
const STAGGER_TINT_SEC := 0.2
const STAGGER_CLEAR_SEC := 0.3

# -- State --

var _is_staggered := false
var _visual_state: DirectionalSpriteFrameView.VisualState = DirectionalSpriteFrameView.VisualState.IDLE
var _facing := Vector2.DOWN
## Scene-authored sprite tint captured at ready; feedback settles back to this instead of hard-coded white.
var _base_tint := Color.WHITE

# -- Timer / tween handles --

var _action_tween: Tween
var _flash_tween: Tween
var _tint_tween: Tween

# -- Node references --

@onready var _frame_view: DirectionalSpriteFrameView = %Sprite

# == Lifecycle ==


func _ready() -> void:
    if _frame_view != null:
        _base_tint = _frame_view.modulate
    if not has_valid_texture():
        ToastManager.show_dev_error("%s: EnemyVisualPresenter has no placeholder texture assigned to its Sprite." % name)

# == Signal handlers ==


func _on_flash_finished() -> void:
    if _is_staggered:
        _tint_tween = create_tween()
        _tint_tween.tween_property(_frame_view, "modulate", STAGGER_TINT_COLOR, STAGGER_TINT_SEC)
    else:
        _frame_view.modulate = _base_tint

# == Common API ==


## True once the frame view has a texture assigned; GridEnemy falls back to its legacy
## Polygon2D body when this is false rather than presenting a blank sprite.
func has_valid_texture() -> bool:
    return _frame_view != null and _frame_view.texture != null


## Updates the presented direction without becoming an authoritative facing source.
func set_facing(facing: Vector2) -> void:
    _facing = facing
    _frame_view.set_direction(_direction_from_facing(facing))


## Clears action feedback and returns the sprite to its neutral idle pose.
func show_idle() -> void:
    _clear_action_feedback()
    _set_visual_state(DirectionalSpriteFrameView.VisualState.IDLE)


## Shows movement intent and lets concrete presenters add their own movement cue.
func show_move() -> void:
    _begin_action_feedback(DirectionalSpriteFrameView.VisualState.MOVE)
    _play_move_feedback()


## Shows attack windup intent and lets concrete presenters add their own prepare cue.
func show_prepare_attack() -> void:
    _begin_action_feedback(DirectionalSpriteFrameView.VisualState.PREPARE_ATTACK)
    _play_prepare_attack_feedback()


## Shows the final pre-impact commit cue. This is presentation only; attack timing,
## damage, movement, recovery, and telegraph cleanup remain owned by enemy gameplay code.
func show_attack_commit() -> void:
    _begin_action_feedback(DirectionalSpriteFrameView.VisualState.COMMIT_CUE)
    _play_attack_commit_feedback()


## Non-authoritative damage feedback: flashes white/red, then settles back into stagger
## tint if still staggered, or base tint otherwise. Mirrors the legacy _body hurt flash.
func flash_damage() -> void:
    if _flash_tween != null and _flash_tween.is_valid():
        _flash_tween.kill()

    _flash_tween = create_tween()
    _flash_tween.tween_property(_frame_view, "modulate", Color.WHITE, FLASH_IN_SEC)
    _flash_tween.tween_property(_frame_view, "modulate", DAMAGE_FLASH_COLOR, FLASH_HOLD_SEC)
    _flash_tween.tween_property(_frame_view, "modulate", _base_tint, FLASH_OUT_SEC)
    _flash_tween.finished.connect(_on_flash_finished, CONNECT_ONE_SHOT)


## Tints toward stagger color when active, or clears back to base tint when it ends.
func set_staggered(active: bool) -> void:
    _is_staggered = active
    if active:
        _clear_action_feedback()
    if _tint_tween != null and is_instance_valid(_tint_tween):
        _tint_tween.kill()

    _tint_tween = create_tween()
    if active:
        _tint_tween.tween_property(_frame_view, "modulate", STAGGER_TINT_COLOR, STAGGER_TINT_SEC)
    else:
        _tint_tween.tween_property(_frame_view, "modulate", _base_tint, STAGGER_CLEAR_SEC)


## Resets visuals to a clean idle/base-tint state, e.g. on enemy pool reuse.
func reset_visuals() -> void:
    _is_staggered = false
    _clear_action_feedback()
    if _flash_tween != null and is_instance_valid(_flash_tween):
        _flash_tween.kill()
    if _tint_tween != null and is_instance_valid(_tint_tween):
        _tint_tween.kill()
    _frame_view.modulate = _base_tint
    _set_visual_state(DirectionalSpriteFrameView.VisualState.IDLE)

# == Feature: action feedback ==


func _begin_action_feedback(state: DirectionalSpriteFrameView.VisualState) -> void:
    _clear_action_feedback()
    _set_visual_state(state)


func _set_visual_state(state: DirectionalSpriteFrameView.VisualState) -> void:
    _visual_state = state
    _frame_view.set_visual_state(state)


func _clear_action_feedback() -> void:
    if _action_tween != null and is_instance_valid(_action_tween):
        _action_tween.kill()
    _action_tween = null
    _reset_action_transform()


func _create_action_tween() -> Tween:
    if _action_tween != null and is_instance_valid(_action_tween):
        _action_tween.kill()
    _action_tween = create_tween()
    return _action_tween


func _reset_action_transform() -> void:
    position = Vector2.ZERO
    rotation = 0.0
    scale = Vector2.ONE


func _play_move_feedback() -> void:
    pass


func _play_prepare_attack_feedback() -> void:
    pass


func _play_attack_commit_feedback() -> void:
    pass

# == Feature: facing ==


func _direction_from_facing(facing: Vector2) -> DirectionalSpriteFrameView.Direction:
    if facing == Vector2.UP:
        return DirectionalSpriteFrameView.Direction.UP
    if facing == Vector2.LEFT:
        return DirectionalSpriteFrameView.Direction.LEFT
    if facing == Vector2.RIGHT:
        return DirectionalSpriteFrameView.Direction.RIGHT
    return DirectionalSpriteFrameView.Direction.DOWN
