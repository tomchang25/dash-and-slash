# player.gd
# Player entity — free-movement ARPG character. Owns input, movement, normal
# attack, dash, and dash-attack. Position is world-space (never grid-locked).
# Uses the template's StateMachine with behaviour-delegation: states own logic,
# the entity provides a public query/command API.
class_name Player
extends Entity

const MOVE_SPEED := 220.0
const DASH_SPEED := 500.0
const DASH_DURATION := 0.2
const DASH_COOLDOWN := 2.0
const ATTACK_DURATION := 0.25
const NORMAL_ATTACK_DAMAGE := 10.0
const DASH_ATTACK_DAMAGE := 15.0

@onready var _attack_hitbox: Hitbox = $AttackHitbox
@onready var _dash_hitbox: Hitbox = $DashHitbox

var _move_dir := Vector2.ZERO
var _last_move_dir := Vector2.DOWN
var _attack_requested := false
var _dash_requested := false
var _dash_requested_dir := Vector2.ZERO
var _dash_cooldown_remaining := 0.0
var _grid: GridArena


func setup(grid: GridArena) -> void:
    _grid = grid


func get_dash_cooldown() -> float:
    return _dash_cooldown_remaining

# -- Public API (called BY states, not the other way around) --


func get_move_input() -> Vector2:
    return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func get_last_move_dir() -> Vector2:
    return _last_move_dir


func consume_attack_request() -> bool:
    var req := _attack_requested
    _attack_requested = false
    return req


func consume_dash_request() -> bool:
    if _dash_cooldown_remaining > 0.0:
        _dash_requested = false
        return false
    var req := _dash_requested
    _dash_requested = false
    if req:
        _dash_cooldown_remaining = DASH_COOLDOWN
    return req


func consume_dash_direction() -> Vector2:
    return _dash_requested_dir


func enable_attack_hitbox() -> void:
    _attack_hitbox.set_enabled(true)


func disable_attack_hitbox() -> void:
    _attack_hitbox.set_enabled(false)


func enable_dash_hitbox() -> void:
    _dash_hitbox.set_enabled(true)


func disable_dash_hitbox() -> void:
    _dash_hitbox.set_enabled(false)

# -- Lifecycle --


func _ready() -> void:
    super()

    _attack_hitbox.set_enabled(false)
    _dash_hitbox.set_enabled(false)


func _physics_process(delta: float) -> void:
    if _dash_cooldown_remaining > 0.0:
        _dash_cooldown_remaining = max(_dash_cooldown_remaining - delta, 0.0)

    _move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if _move_dir != Vector2.ZERO:
        _last_move_dir = _move_dir

    if _grid != null:
        _grid.set_player_cell(global_position)

    move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("attack"):
        _attack_requested = true
    elif event.is_action_pressed("dash"):
        _dash_requested = true
        var mv_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
        _dash_requested_dir = _last_move_dir if mv_dir == Vector2.ZERO else mv_dir
