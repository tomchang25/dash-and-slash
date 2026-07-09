# enemy_visual_presenter.gd
# Maps enemy visual-state and facing intent onto a DirectionalSpriteFrameView, plus cheap
# non-authoritative feedback (damage flash, stagger tint). Never decides when an enemy acts,
# attacks, recovers, or dies; it only displays what GridEnemy and its kinds already report.
class_name EnemyVisualPresenter
extends Node2D

# -- Constants ------------------------------------------------------------------
const DAMAGE_FLASH_COLOR := Color(0.8, 0.2, 0.2, 1.0)
const STAGGER_TINT_COLOR := Color(0.3, 0.5, 1.0, 1.0)
const FLASH_IN_SEC := 0.03
const FLASH_HOLD_SEC := 0.06
const FLASH_OUT_SEC := 0.08
const STAGGER_TINT_SEC := 0.2
const STAGGER_CLEAR_SEC := 0.3

# -- State --------------------------------------------------------------------
var _is_staggered := false

# -- Timer / tween handles ------------------------------------------------------
var _flash_tween: Tween
var _tint_tween: Tween

# -- Node references ------------------------------------------------------------
@onready var _frame_view: DirectionalSpriteFrameView = %Sprite

# == Lifecycle ================================================================


func _ready() -> void:
    if not has_valid_texture():
        ToastManager.show_dev_error("%s: EnemyVisualPresenter has no placeholder texture assigned to its Sprite." % name)

# == Signal handlers ==========================================================


func _on_flash_finished() -> void:
    if _is_staggered:
        _tint_tween = create_tween()
        _tint_tween.tween_property(_frame_view, "modulate", STAGGER_TINT_COLOR, STAGGER_TINT_SEC)
    else:
        _frame_view.modulate = Color.WHITE

# == Common API ================================================================


## True once the frame view has a texture assigned; GridEnemy falls back to its legacy
## Polygon2D body when this is false rather than presenting a blank sprite.
func has_valid_texture() -> bool:
    return _frame_view != null and _frame_view.texture != null


func set_facing(facing: Vector2) -> void:
    _frame_view.set_direction(_direction_from_facing(facing))


func show_idle() -> void:
    _frame_view.set_visual_state(DirectionalSpriteFrameView.VisualState.IDLE)


func show_move() -> void:
    _frame_view.set_visual_state(DirectionalSpriteFrameView.VisualState.MOVE)


func show_prepare_attack() -> void:
    _frame_view.set_visual_state(DirectionalSpriteFrameView.VisualState.PREPARE_ATTACK)


func show_attack() -> void:
    _frame_view.set_visual_state(DirectionalSpriteFrameView.VisualState.ATTACK)


## Non-authoritative damage feedback: flashes white/red, then settles back into stagger
## tint if still staggered, or full white otherwise. Mirrors the legacy _body hurt flash.
func flash_damage() -> void:
    if _flash_tween != null and _flash_tween.is_valid():
        _flash_tween.kill()

    _flash_tween = create_tween()
    _flash_tween.tween_property(_frame_view, "modulate", Color.WHITE, FLASH_IN_SEC)
    _flash_tween.tween_property(_frame_view, "modulate", DAMAGE_FLASH_COLOR, FLASH_HOLD_SEC)
    _flash_tween.tween_property(_frame_view, "modulate", Color.WHITE, FLASH_OUT_SEC)
    _flash_tween.finished.connect(_on_flash_finished, CONNECT_ONE_SHOT)


## Tints toward stagger color when active, or clears back to white when it ends.
func set_staggered(active: bool) -> void:
    _is_staggered = active
    if _tint_tween != null and is_instance_valid(_tint_tween):
        _tint_tween.kill()

    _tint_tween = create_tween()
    if active:
        _tint_tween.tween_property(_frame_view, "modulate", STAGGER_TINT_COLOR, STAGGER_TINT_SEC)
    else:
        _tint_tween.tween_property(_frame_view, "modulate", Color.WHITE, STAGGER_CLEAR_SEC)


## Resets visuals to a clean idle/white state, e.g. on enemy pool reuse.
func reset_visuals() -> void:
    _is_staggered = false
    if _flash_tween != null and is_instance_valid(_flash_tween):
        _flash_tween.kill()
    if _tint_tween != null and is_instance_valid(_tint_tween):
        _tint_tween.kill()
    _frame_view.modulate = Color.WHITE
    show_idle()

# == Feature: facing ============================================================


func _direction_from_facing(facing: Vector2) -> DirectionalSpriteFrameView.Direction:
    if facing == Vector2.UP:
        return DirectionalSpriteFrameView.Direction.UP
    if facing == Vector2.LEFT:
        return DirectionalSpriteFrameView.Direction.LEFT
    if facing == Vector2.RIGHT:
        return DirectionalSpriteFrameView.Direction.RIGHT
    return DirectionalSpriteFrameView.Direction.DOWN
