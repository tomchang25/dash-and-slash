# tick_player_visual_presenter.gd
# Presents the active class body, resolved cardinal weapon aim, and one-shot normal-attack frames.
class_name TickPlayerVisualPresenter
extends Node2D

# -- Constants --

const ATTACK_FRAME_SEC := 0.045
const BODY_ROW := 0
const WEAPON_IDLE_ROW := 0
const WEAPON_ATTACK_ROWS: Array[int] = [1, 2, 3]

# -- State --

var _character_class: CharacterClassData
var _aim_direction := Vector2i.RIGHT
var _attack_direction := Vector2i.RIGHT
var _attack_active := false

# -- Timer / tween handles --

var _attack_tween: Tween

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


## Updates the body facing and persistent weapon marker from the same resolved cardinal direction preview uses.
func set_aim_direction(direction: Vector2i) -> void:
    if direction == Vector2i.ZERO:
        return
    _aim_direction = direction
    if not is_node_ready():
        return
    _apply_body_frame(_aim_direction)
    if not _attack_active:
        _apply_weapon_frame(WEAPON_IDLE_ROW, _aim_direction)


## Plays a presentation-only weapon sequence locked to the committed normal-attack direction.
func play_normal_attack(direction: Vector2i) -> void:
    if direction == Vector2i.ZERO or not is_node_ready() or _weapon_sprite.texture == null:
        return
    if _attack_tween != null and _attack_tween.is_valid():
        _attack_tween.kill()
    _attack_active = true
    _attack_direction = direction
    _attack_tween = create_tween()
    for row in WEAPON_ATTACK_ROWS:
        _attack_tween.tween_callback(_apply_weapon_frame.bind(row, _attack_direction))
        _attack_tween.tween_interval(ATTACK_FRAME_SEC)
    _attack_tween.tween_callback(_finish_attack)


## Cancels any one-shot weapon cue so a run reset cannot retain presentation from the prior state.
func reset_transients() -> void:
    if _attack_tween != null and _attack_tween.is_valid():
        _attack_tween.kill()
    _attack_tween = null
    _attack_active = false
    if not is_node_ready():
        return
    if _body_sprite.texture != null:
        _apply_body_frame(_aim_direction)
    if _weapon_sprite.texture != null:
        _apply_weapon_frame(WEAPON_IDLE_ROW, _aim_direction)

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
    _apply_weapon_frame(WEAPON_IDLE_ROW, _aim_direction)


func _apply_body_frame(direction: Vector2i) -> void:
    _body_sprite.frame_coords = Vector2i(_direction_column(direction), BODY_ROW)


func _apply_weapon_frame(row: int, direction: Vector2i) -> void:
    _weapon_sprite.frame_coords = Vector2i(_direction_column(direction), row)


func _finish_attack() -> void:
    _attack_active = false
    _apply_weapon_frame(WEAPON_IDLE_ROW, _aim_direction)


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
