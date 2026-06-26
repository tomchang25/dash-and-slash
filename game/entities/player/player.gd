# player.gd
# Player entity — free-movement ARPG character. Owns input, movement, normal
# attack, dash, and dash-attack. Position is world-space (never grid-locked).
# Uses the template's StateMachine with behaviour-delegation: states own logic,
# the entity provides a public query/command API.
class_name Player
extends Entity

const MOVE_SPEED := 440.0
const DASH_SPEED := 1000.0
const DASH_DURATION := 0.2
const DASH_COOLDOWN := 2.0
const ATTACK_DURATION := 0.25
const ATTACK_RANGE := 152.0
const ATTACK_CAPSULE_RADIUS := 64.0
const ATTACK_CAPSULE_HEIGHT := 208.0

# -- Exports --------------------------------------------------------------------
@export var attack_sfx_event: SpatialAudioEvent
@export var damaged_sfx_event: SpatialAudioEvent

@export var normal_attack_damage: float = 20.0
@export var dash_attack_damage: float = 80.0

# -- Node references ----------------------------------------------------------
@onready var _attack_hitbox: Hitbox = $AttackHitbox
@onready var _dash_hitbox: Hitbox = $DashHitbox
@onready var _attack_vfx: Polygon2D = $AttackVfx
@onready var _facing_arrow: Polygon2D = $FacingArrow
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _body: Polygon2D = $Body

var _move_dir := Vector2.ZERO
var _last_move_dir := Vector2.DOWN
var _attack_requested := false
var _dash_requested := false
var _dash_requested_dir := Vector2.ZERO
var _dash_cooldown_remaining := 0.0
var _grid: GridArena
var _hurt_tween: Tween


func setup(grid: GridArena) -> void:
    _grid = grid


func get_dash_cooldown() -> float:
    return _dash_cooldown_remaining

# -- Public API (called BY states, not the other way around) --


func get_move_input() -> Vector2:
    return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func get_last_move_dir() -> Vector2:
    return _last_move_dir


func get_aim_direction() -> Vector2:
    var dir := get_global_mouse_position() - global_position
    if dir.length_squared() <= 0.001:
        return _last_move_dir
    return dir.normalized()


func update_aim_visual() -> void:
    var aim_dir := get_aim_direction()
    _facing_arrow.rotation = aim_dir.angle() - PI / 2.0


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
    _dash_hitbox.damage = dash_attack_damage
    _dash_hitbox.set_enabled(true)


func disable_dash_hitbox() -> void:
    _dash_hitbox.set_enabled(false)


func begin_normal_attack(aim_dir: Vector2) -> void:
    _position_attack_shape(aim_dir)
    _attack_hitbox.damage = normal_attack_damage
    _attack_hitbox.set_enabled(true)
    if attack_sfx_event != null:
        AudioManager.play_event(attack_sfx_event, global_position)
    _play_attack_vfx(aim_dir)


func end_normal_attack() -> void:
    _attack_hitbox.set_enabled(false)
    _reset_attack_vfx()

# == Combat helpers =============================================================


func _position_attack_shape(aim_dir: Vector2) -> void:
    _attack_hitbox.position = aim_dir * ATTACK_RANGE
    _attack_hitbox.rotation = aim_dir.angle() + PI / 2.0


func _play_attack_vfx(aim_dir: Vector2) -> void:
    _attack_vfx.position = aim_dir * ATTACK_RANGE
    _attack_vfx.rotation = aim_dir.angle() + PI / 2.0
    _attack_vfx.visible = true
    _attack_vfx.modulate = Color(1.0, 1.0, 1.0, 0.85)
    _attack_vfx.scale = Vector2(0.75, 0.75)

    var tween := create_tween()
    tween.tween_property(_attack_vfx, "scale", Vector2.ONE, 0.06)
    tween.parallel().tween_property(_attack_vfx, "modulate:a", 0.0, ATTACK_DURATION)


func _reset_attack_vfx() -> void:
    _attack_vfx.visible = false
    _attack_vfx.modulate = Color(1.0, 1.0, 1.0, 0.85)
    _attack_vfx.scale = Vector2.ONE

# -- Lifecycle --


func _ready() -> void:
    super()

    _attack_hitbox.set_enabled(false)
    _dash_hitbox.set_enabled(false)

    if _hurtbox != null:
        _hurtbox.hit_received.connect(_on_hit_received)

    if health != null:
        health.damaged.connect(_on_player_damaged)


func _physics_process(delta: float) -> void:
    if _dash_cooldown_remaining > 0.0:
        _dash_cooldown_remaining = max(_dash_cooldown_remaining - delta, 0.0)

    _move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if _move_dir != Vector2.ZERO:
        _last_move_dir = _move_dir

    if _grid != null:
        _grid.set_player_cell(global_position)

    update_aim_visual()
    move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("attack"):
        _attack_requested = true
    elif event.is_action_pressed("dash"):
        _dash_requested = true
        var mv_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
        _dash_requested_dir = get_aim_direction() if mv_dir == Vector2.ZERO else mv_dir


func _on_hit_received(amount: float, source: Node, _guard_damage_profile: int) -> void:
    if health != null:
        health.take_damage(amount, source)


func _on_player_damaged(_amount: float, _source: Node) -> void:
    if _hurt_tween != null and _hurt_tween.is_valid():
        _hurt_tween.kill()

    if damaged_sfx_event != null:
        AudioManager.play_event(damaged_sfx_event, global_position)

    _hurt_tween = create_tween()
    _hurt_tween.tween_property(_body, "modulate", Color.RED, 0.03)
    _hurt_tween.tween_property(_body, "modulate", Color.WHITE, 0.08)
    _hurt_tween.tween_callback(_start_invuln_blink)


func _start_invuln_blink() -> void:
    var blink_tween := create_tween()
    blink_tween.tween_property(_body, "modulate:a", 0.6, 0.15)
    blink_tween.tween_property(_body, "modulate:a", 1.0, 0.15)
    blink_tween.set_loops(int(health.invuln_seconds * 3.0))
    blink_tween.finished.connect(
        func():
            if _body != null:
                _body.modulate = Color.WHITE,
        CONNECT_ONE_SHOT,
    )
