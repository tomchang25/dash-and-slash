# directional_sprite_frame_view.gd
# Small reusable frame selector for a four-direction, named-visual-state Sprite2D sheet.
# Pure Sprite2D.frame_coords selection; no AnimationPlayer, AnimationTree, AnimatedSprite2D,
# SpriteFrames, Timer, or tween-driven frame playback.
class_name DirectionalSpriteFrameView
extends Sprite2D

enum Direction {
    DOWN,
    LEFT,
    RIGHT,
    UP,
}

enum VisualState {
    IDLE,
    MOVE,
    PREPARE_ATTACK,
    COMMIT_CUE,
}

# -- Constants --

## Placeholder row-per-state mapping for the scaffold sheet; the current Kappa sheet uses
## top-to-bottom frames as movement/pose frames.
const FRAME_ROW_BY_STATE := {
    VisualState.IDLE: 0,
    VisualState.MOVE: 1,
    VisualState.PREPARE_ATTACK: 2,
    VisualState.COMMIT_CUE: 3,
}
## Column-per-direction mapping for the current Kappa scaffold sheet.
const FRAME_COLUMN_BY_DIRECTION := {
    Direction.DOWN: 0,
    Direction.UP: 1,
    Direction.LEFT: 2,
    Direction.RIGHT: 3,
}

# -- State --

var _state: VisualState = VisualState.IDLE
var _direction: Direction = Direction.DOWN

# == Lifecycle ==


func _ready() -> void:
    _apply_frame_coords()

# == Common API ==


func set_visual_state(state: VisualState) -> void:
    _state = state
    _apply_frame_coords()


func set_direction(direction: Direction) -> void:
    _direction = direction
    _apply_frame_coords()

# == Frame selection ==


func _apply_frame_coords() -> void:
    frame_coords = Vector2i(FRAME_COLUMN_BY_DIRECTION[_direction], FRAME_ROW_BY_STATE[_state])
