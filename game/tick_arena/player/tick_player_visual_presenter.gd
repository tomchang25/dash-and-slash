# tick_player_visual_presenter.gd
# Presents the active class body, resolved cardinal aim, step movement poses, and one-shot normal-attack frames.
class_name TickPlayerVisualPresenter
extends Node2D

enum VisualCue {
    IDLE,
    MOVE,
    ATTACK,
}

# -- Constants --

const BODY_IDLE_ROW := 0
const BODY_MOVE_ROWS: Array[int] = [1, 2, 3, 2]
const BODY_ATTACK_ROWS: Array[int] = [5, 4]
const WEAPON_ATTACK_ROWS: Array[int] = [1, 2, 3]
const MOVE_FRAME_HOLD_SEC := 0.24
const ATTACK_FRAME_DURATIONS: Array[float] = [0.1, 0.12, 0.12]

# -- State --

var _character_class: CharacterClassData
var _aim_direction := Vector2i.RIGHT
var _attack_direction := Vector2i.RIGHT
var _visual_cue := VisualCue.IDLE
var _move_frame_index := 0

# -- Timer / tween handles --

var _visual_cue_tween: Tween

# -- Node references --

@onready var _body_sprite: Sprite2D = %PlayerBodySprite
@onready var _weapon_sprite: Sprite2D = %PlayerWeaponSprite

# == Lifecycle ==


func _ready() -> void:
    if _character_class != null:
        _apply_class()

# == Common API ==


## Stores and applies the active class presentation resource.
func setup(character_class: CharacterClassData) -> void:
    _character_class = character_class
    reset_transients()
    if is_node_ready():
        _apply_class()


## Returns whether an authored body texture is currently available.
func has_valid_body_texture() -> bool:
    return _body_sprite != null and _body_sprite.texture != null


## Updates the idle body facing from the same resolved cardinal direction preview uses.
func set_aim_direction(direction: Vector2i) -> void:
    if direction == Vector2i.ZERO:
        return
    _aim_direction = direction
    if not is_node_ready():
        return
    if _visual_cue == VisualCue.IDLE:
        _apply_body_frame(_aim_direction)
        _hide_weapon()


## Plays one movement pose long enough for a held-input follow-up step to replace it without flashing idle between steps.
func play_move(direction: Vector2i) -> void:
    if direction == Vector2i.ZERO or not is_node_ready() or _body_sprite.texture == null:
        return
    _begin_visual_cue(VisualCue.MOVE)
    _aim_direction = direction
    _apply_body_frame_row(BODY_MOVE_ROWS[_move_frame_index], direction)
    _move_frame_index = (_move_frame_index + 1) % BODY_MOVE_ROWS.size()
    _visual_cue_tween = create_tween()
    _visual_cue_tween.tween_interval(MOVE_FRAME_HOLD_SEC)
    _visual_cue_tween.tween_callback(_finish_visual_cue)


## Plays a presentation-only weapon sequence locked to the committed normal-attack direction.
func play_normal_attack(direction: Vector2i) -> void:
    if direction == Vector2i.ZERO or not is_node_ready() or _weapon_sprite.texture == null:
        return
    _begin_visual_cue(VisualCue.ATTACK)
    _aim_direction = direction
    _attack_direction = direction
    _weapon_sprite.visible = true
    _visual_cue_tween = create_tween()
    for frame_index in WEAPON_ATTACK_ROWS.size():
        _visual_cue_tween.tween_callback(_apply_attack_frame.bind(frame_index))
        _visual_cue_tween.tween_interval(ATTACK_FRAME_DURATIONS[frame_index])
    _visual_cue_tween.tween_callback(_finish_visual_cue)


## Cancels any one-shot weapon cue so a run reset cannot retain presentation from the prior state.
func reset_transients() -> void:
    if _visual_cue_tween != null and _visual_cue_tween.is_valid():
        _visual_cue_tween.kill()
    _visual_cue_tween = null
    _visual_cue = VisualCue.IDLE
    _move_frame_index = 0
    if not is_node_ready():
        return
    if _body_sprite.texture != null:
        _apply_body_frame(_aim_direction)
    if _weapon_sprite.texture != null:
        _hide_weapon()

# == View ==


func _apply_class() -> void:
    if _character_class == null:
        ToastManager.show_dev_error("TickPlayerVisualPresenter: missing CharacterClassData")
        _body_sprite.texture = null
        _weapon_sprite.texture = null
        return
    _body_sprite.texture = _character_class.body_texture
    _apply_body_frame(_aim_direction)
    _weapon_sprite.texture = _character_class.weapon_texture
    _hide_weapon()


func _apply_body_frame(direction: Vector2i) -> void:
    _apply_body_frame_row(BODY_IDLE_ROW, direction)


func _apply_body_frame_row(row: int, direction: Vector2i) -> void:
    _body_sprite.frame_coords = Vector2i(_direction_column(direction), row)


func _apply_weapon_frame(row: int, direction: Vector2i) -> void:
    _weapon_sprite.frame_coords = Vector2i(_direction_column(direction), row)


func _hide_weapon() -> void:
    _weapon_sprite.visible = false


func _begin_visual_cue(cue: VisualCue) -> void:
    if _visual_cue_tween != null and _visual_cue_tween.is_valid():
        _visual_cue_tween.kill()
    _visual_cue_tween = null
    _visual_cue = cue
    _hide_weapon()


## Applies one synchronized authored body-and-weapon attack frame.
func _apply_attack_frame(frame_index: int) -> void:
    var body_row := BODY_ATTACK_ROWS[mini(frame_index, BODY_ATTACK_ROWS.size() - 1)]
    _apply_body_frame_row(body_row, _attack_direction)
    _apply_weapon_frame(WEAPON_ATTACK_ROWS[frame_index], _attack_direction)


func _finish_visual_cue() -> void:
    _visual_cue_tween = null
    _visual_cue = VisualCue.IDLE
    _apply_body_frame(_aim_direction)
    _hide_weapon()


func _direction_column(direction: Vector2i) -> int:
    if direction == Vector2i.DOWN:
        return 0
    if direction == Vector2i.UP:
        return 1
    if direction == Vector2i.LEFT:
        return 2
    if direction == Vector2i.RIGHT:
        return 3
    ToastManager.show_dev_error("TickPlayerVisualPresenter: non-cardinal aim direction %s" % direction)
    return 3
