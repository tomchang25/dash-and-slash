# player.gd
# Player entity — free-movement ARPG character. Owns input, movement, normal
# attack, dash, and dash-attack. Position is world-space (never grid-locked).
# Uses the template's StateMachine with behaviour-delegation: states own logic,
# the entity provides a public query/command API.
class_name Player
extends Entity

signal died(entity: Player)
signal health_changed(current: float, maximum: float)
signal dash_hit_landed

const MOVE_SPEED := 440.0
const DASH_SPEED := 1000.0
const DASH_DURATION := 0.3
const DASH_COOLDOWN := 2.0
const ATTACK_DURATION := 0.25
const ATTACK_RANGE := 152.0
const ATTACK_CAPSULE_RADIUS := 64.0
const ATTACK_CAPSULE_HEIGHT := 208.0
const DASH_INVULN_EXTEND := 1.0
const DASH_GHOST_INTERVAL := 0.04
const DASH_GHOST_FADE_SEC := 0.32
const DASH_WIND_FADE_SEC := 0.2
const DASH_SPEED_LINE_FADE_SEC := 0.24
const DASH_BODY_PUNCH_SEC := 0.08
const DASH_BODY_RECOVER_SEC := 0.12
const DASH_FLASH_FADE_SEC := 0.16
const DASH_CAMERA_PUNCH_SEC := 0.12
const DASH_BODY_STRETCH_SCALE := Vector2(1.65, 0.72)
const DASH_CAMERA_PUNCH_DISTANCE := 7.0

# -- Exports --------------------------------------------------------------------
@export var health: Health
@export var attack_sfx_event: SpatialAudioEvent
@export var damaged_sfx_event: SpatialAudioEvent

@export var normal_attack_damage: float = 20.0
@export var dash_attack_damage: float = 80.0

# -- Node references ----------------------------------------------------------
@onready var _attack_hitbox: Hitbox = %AttackHitbox
@onready var _dash_hitbox: Hitbox = %DashHitbox
@onready var _attack_vfx: Polygon2D = %AttackVfx
@onready var _facing_arrow: Polygon2D = %FacingArrow
@onready var _hurtbox: Hurtbox = %Hurtbox
@onready var _body: Polygon2D = %Body
@onready var _camera: Camera2D = %Camera2D

var _move_dir := Vector2.ZERO
var _last_move_dir := Vector2.DOWN
var _attack_requested := false
var _dash_requested := false
var _dash_requested_dir := Vector2.ZERO
var _dash_cooldown_remaining := 0.0
var _grid: GridArena
var _hurt_tween: Tween
var _dash_invulnerable := false
var _dash_invuln_end_msec := 0
var _dash_invuln_blink_tween: Tween
var _dash_body_punch_tween: Tween
var _dash_camera_punch_tween: Tween
var _dash_vfx_elapsed := 0.0


func setup(grid: GridArena) -> void:
    _grid = grid


func emit_health_snapshot() -> void:
    if health != null:
        health_changed.emit(health.current(), health.max_health)


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


## Starts the dash trail and wind visuals for the captured dash direction.
func begin_dash_vfx(dash_direction: Vector2) -> void:
    _dash_vfx_elapsed = 0.0
    _play_dash_body_punch(dash_direction)
    _play_dash_camera_punch(dash_direction)
    _spawn_dash_flash()
    _spawn_dash_ghost()
    _spawn_dash_wind_burst(dash_direction)
    _spawn_dash_speed_lines(dash_direction)


## Updates timed dash visuals while the dash state is active.
func update_dash_vfx(delta: float) -> void:
    _dash_vfx_elapsed += delta
    while _dash_vfx_elapsed >= DASH_GHOST_INTERVAL:
        _dash_vfx_elapsed -= DASH_GHOST_INTERVAL
        _spawn_dash_ghost()


## Clears dash visual timing state when the dash ends.
func end_dash_vfx() -> void:
    _dash_vfx_elapsed = 0.0
    if _dash_body_punch_tween != null and _dash_body_punch_tween.is_valid():
        _dash_body_punch_tween.kill()
        _dash_body_punch_tween = null
    if _body != null:
        _body.scale = Vector2.ONE
        _body.rotation = 0.0


func begin_dash_invulnerability() -> void:
    _dash_invulnerable = true
    _dash_invuln_end_msec = Time.get_ticks_msec() + int(DASH_DURATION * 1000.0)
    _start_dash_invuln_blink()


func extend_dash_invulnerability(extra_sec: float) -> void:
    var new_end := Time.get_ticks_msec() + int(extra_sec * 1000.0)
    if new_end > _dash_invuln_end_msec:
        _dash_invuln_end_msec = new_end


func end_dash_invulnerability() -> void:
    _dash_invulnerable = false
    _dash_invuln_end_msec = 0
    _stop_dash_invuln_blink()

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

# == Dash VFX ==


func _spawn_dash_ghost() -> void:
    if _body == null:
        return

    var ghost := Polygon2D.new()
    ghost.polygon = _body.polygon
    ghost.color = Color(0.75, 0.96, 1.0, 0.68)
    ghost.z_index = _body.z_index - 1

    var effects_parent := _get_dash_effects_parent()
    # node-src: ephemeral - dash trail snapshot fades out immediately
    effects_parent.add_child(ghost)
    ghost.global_transform = _body.global_transform
    ghost.scale *= 1.08

    var tween := create_tween()
    tween.tween_property(ghost, "modulate:a", 0.0, DASH_GHOST_FADE_SEC)
    tween.tween_callback(ghost.queue_free)


func _spawn_dash_flash() -> void:
    if _body == null:
        return

    var flash := Polygon2D.new()
    flash.polygon = _body.polygon
    flash.color = Color(1.0, 1.0, 1.0, 0.8)
    flash.z_index = _body.z_index + 1

    var effects_parent := _get_dash_effects_parent()
    # node-src: ephemeral - dash startup flash fades out immediately
    effects_parent.add_child(flash)
    flash.global_transform = _body.global_transform
    flash.scale *= 1.45

    var tween := create_tween()
    tween.tween_property(flash, "scale", flash.scale * 1.35, DASH_FLASH_FADE_SEC)
    tween.parallel().tween_property(flash, "modulate:a", 0.0, DASH_FLASH_FADE_SEC)
    tween.tween_callback(flash.queue_free)


func _spawn_dash_wind_burst(dash_dir: Vector2) -> void:
    if dash_dir == Vector2.ZERO:
        return

    var burst := Polygon2D.new()
    burst.polygon = PackedVector2Array(
        [
            Vector2(90.0, 0.0),
            Vector2(-30.0, -34.0),
            Vector2(-4.0, 0.0),
            Vector2(-30.0, 34.0),
        ],
    )
    burst.color = Color(1.0, 1.0, 1.0, 0.72)
    burst.z_index = _body.z_index - 2

    var effects_parent := _get_dash_effects_parent()
    # node-src: ephemeral - dash wind burst fades out immediately
    effects_parent.add_child(burst)
    burst.global_position = global_position + dash_dir * 54.0
    burst.global_rotation = dash_dir.angle()
    burst.scale = Vector2(0.8, 1.0)

    var tween := create_tween()
    tween.tween_property(burst, "scale", Vector2(1.7, 1.25), 0.08)
    tween.parallel().tween_property(
        burst,
        "global_position",
        global_position + dash_dir * 126.0,
        DASH_WIND_FADE_SEC,
    )
    tween.parallel().tween_property(burst, "modulate:a", 0.0, DASH_WIND_FADE_SEC)
    tween.tween_callback(burst.queue_free)


func _spawn_dash_speed_lines(dash_dir: Vector2) -> void:
    if dash_dir == Vector2.ZERO:
        return

    var side_dir := dash_dir.orthogonal()
    var offsets := [-42.0, -14.0, 14.0, 42.0]
    for offset in offsets:
        var line := Line2D.new()
        line.width = 10.0
        line.default_color = Color(1.0, 1.0, 1.0, 0.82)
        line.z_index = _body.z_index - 3
        line.points = PackedVector2Array(
            [
                global_position - dash_dir * 26.0 + side_dir * offset,
                global_position - dash_dir * 170.0 + side_dir * offset * 1.45,
            ],
        )

        var effects_parent := _get_dash_effects_parent()
        # node-src: ephemeral - dash speed line fades out immediately
        effects_parent.add_child(line)

        var tween := create_tween()
        tween.tween_property(line, "modulate:a", 0.0, DASH_SPEED_LINE_FADE_SEC)
        tween.parallel().tween_property(line, "position", -dash_dir * 54.0, DASH_SPEED_LINE_FADE_SEC)
        tween.tween_callback(line.queue_free)


func _play_dash_body_punch(dash_dir: Vector2) -> void:
    if _body == null or dash_dir == Vector2.ZERO:
        return
    if _dash_body_punch_tween != null and _dash_body_punch_tween.is_valid():
        _dash_body_punch_tween.kill()

    _body.rotation = dash_dir.angle()
    _body.scale = DASH_BODY_STRETCH_SCALE
    _dash_body_punch_tween = create_tween()
    _dash_body_punch_tween.tween_property(_body, "scale", DASH_BODY_STRETCH_SCALE, DASH_BODY_PUNCH_SEC)
    _dash_body_punch_tween.tween_property(_body, "scale", Vector2.ONE, DASH_BODY_RECOVER_SEC)
    _dash_body_punch_tween.parallel().tween_property(_body, "rotation", 0.0, DASH_BODY_RECOVER_SEC)


func _play_dash_camera_punch(dash_dir: Vector2) -> void:
    if _camera == null or dash_dir == Vector2.ZERO:
        return
    if _dash_camera_punch_tween != null and _dash_camera_punch_tween.is_valid():
        _dash_camera_punch_tween.kill()

    var base_offset := _camera.offset
    _camera.offset = base_offset - dash_dir * DASH_CAMERA_PUNCH_DISTANCE
    _dash_camera_punch_tween = create_tween()
    _dash_camera_punch_tween.tween_property(_camera, "offset", base_offset, DASH_CAMERA_PUNCH_SEC)


func _get_dash_effects_parent() -> Node2D:
    var parent_node := get_parent()
    if parent_node is Node2D:
        return parent_node
    return self

# == Dash invulnerability ==


func _start_dash_invuln_blink() -> void:
    _stop_dash_invuln_blink()
    _dash_invuln_blink_tween = create_tween()
    _dash_invuln_blink_tween.set_loops()
    var colors := [
        Color(1, 0, 0),
        Color(1, 1, 0),
        Color(0, 1, 0),
        Color(0, 1, 1),
        Color(0, 0, 1),
        Color(1, 0, 1),
    ]
    for c in colors:
        _dash_invuln_blink_tween.tween_property(_body, "modulate", c, 0.15)


func _stop_dash_invuln_blink() -> void:
    if _dash_invuln_blink_tween != null and _dash_invuln_blink_tween.is_valid():
        _dash_invuln_blink_tween.kill()
        _dash_invuln_blink_tween = null
    if _body != null:
        _body.modulate = Color.WHITE


func _update_dash_invulnerability() -> void:
    if _dash_invulnerable and Time.get_ticks_msec() >= _dash_invuln_end_msec:
        end_dash_invulnerability()

# -- Lifecycle --


func _ready() -> void:
    super()

    if health != null:
        health.died.connect(_on_health_died)
        health.health_changed.connect(_on_health_changed)
        health.damaged.connect(_on_player_damaged)
        emit_health_snapshot()

    _attack_hitbox.set_enabled(false)
    _dash_hitbox.set_enabled(false)

    if _hurtbox != null:
        _hurtbox.hit_received.connect(_on_hit_received)
    _dash_hitbox.hit_landed.connect(_on_dash_hitbox_hit_landed)

    if _camera != null:
        _camera.make_current()


func _physics_process(delta: float) -> void:
    if _dash_cooldown_remaining > 0.0:
        _dash_cooldown_remaining = max(_dash_cooldown_remaining - delta, 0.0)

    _move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if _move_dir != Vector2.ZERO:
        _last_move_dir = _move_dir

    if _grid != null:
        _grid.set_player_cell(global_position)

    update_aim_visual()
    _update_dash_invulnerability()
    move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("attack"):
        _attack_requested = true
    elif event.is_action_pressed("dash"):
        _dash_requested = true
        _dash_requested_dir = get_aim_direction()


func _on_hit_received(amount: float, source: Node, _guard_damage_profile: int) -> void:
    if _dash_invulnerable and Time.get_ticks_msec() < _dash_invuln_end_msec:
        return
    if health != null:
        health.take_damage(amount, source)


func _on_health_died() -> void:
    died.emit(self)


func _on_health_changed(current: float, maximum: float) -> void:
    health_changed.emit(current, maximum)


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


func _on_dash_hitbox_hit_landed(_target: Hurtbox) -> void:
    dash_hit_landed.emit()
