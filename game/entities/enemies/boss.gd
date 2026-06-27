# boss.gd
# 2x2 grid actor boss. 4 shields (16 guard), 3 attack patterns:
# ForwardCleave, LineCharge, CrossStomp. Uses the Enemy base plus Health,
# Hitbox, Hurtbox, Guard, and TileTelegraph components.
class_name Boss
extends Enemy

signal guard_changed(current: int, maximum: int)
signal guard_stagger_started
signal guard_stagger_ended

enum StateId { IDLE = 0, FACE_TARGET = 1, TELEGRAPH = 2, ATTACK = 3, RECOVERY = 4, STAGGERED = 5 }

enum AttackPattern { FORWARD_CLEAVE = 0, LINE_CHARGE = 1, CROSS_STOMP = 2 }

const TELEGRAPH_DURATION := 0.9
const ATTACK_DURATION := 0.5
const RECOVERY_DURATION := 0.8
const CYCLE_COOLDOWN := 1.5
const BOSS_HP := 200.0
const BOSS_GUARD := 16
const GUARDED_DAMAGE_MULTIPLIER := 0.25
const STAGGER_VFX_COLOR := Color(0.4, 0.6, 1.0, 1.0)

@onready var _state_machine: StateMachine = %StateMachine
@onready var _guard: Guard = %Guard
@onready var _telegraph: TileTelegraph = %TileTelegraph
@onready var _body: Polygon2D = %Body
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var _facing_arrow: Polygon2D = %FacingArrow

var _grid: GridArena
var _target: Node2D
var _grid_pos: Vector2i ## top-left cell of 2x2 footprint
var _facing: Vector2 = Vector2.DOWN
var _current_pattern: int = AttackPattern.FORWARD_CLEAVE
var _pattern_index: int = 0
var _telegraph_timer: Timer
var _attack_timer: Timer
var _recovery_timer: Timer
var _cooldown_timer: Timer
var _staggered: bool = false
var _hurt_tween: Tween
var _stagger_tween: Tween
var _active_hitboxes: Array[Area2D] = []


func setup(grid: GridArena, target: Node2D) -> void:
    _grid = grid
    _target = target
    if is_node_ready() and _telegraph != null:
        _telegraph.setup(grid)


func emit_guard_snapshot() -> void:
    if _guard != null:
        guard_changed.emit(_guard.current(), _guard.max_guard)


func _ready() -> void:
    super()

    _grid_pos = _grid.world_to_grid(global_position)
    _refresh_occupied()

    _telegraph_timer = Timer.new()
    _telegraph_timer.one_shot = true
    _telegraph_timer.timeout.connect(_on_telegraph_done)
    # node-src: timer
    add_child(_telegraph_timer)

    _attack_timer = Timer.new()
    _attack_timer.one_shot = true
    _attack_timer.timeout.connect(_on_attack_done)
    # node-src: timer
    add_child(_attack_timer)

    _recovery_timer = Timer.new()
    _recovery_timer.one_shot = true
    _recovery_timer.timeout.connect(
        func() -> void:
            _state_machine.request_transition(StateId.IDLE)
            _cooldown_timer.start(CYCLE_COOLDOWN)
    )
    # node-src: timer
    add_child(_recovery_timer)

    _cooldown_timer = Timer.new()
    _cooldown_timer.one_shot = true
    # node-src: timer
    add_child(_cooldown_timer)

    if _guard != null:
        _guard.guard_changed.connect(_on_guard_changed)
        _guard.guard_broken.connect(_on_guard_broken)
        _guard.stagger_started.connect(_on_stagger_started)
        _guard.stagger_ended.connect(_on_stagger_ended)
        emit_guard_snapshot()

    if _telegraph != null:
        _telegraph.setup(_grid)

    if hurtbox != null:
        hurtbox.hit_received.connect(_on_hit_received)

    if health != null:
        health.damaged.connect(_on_damaged)


func _refresh_occupied() -> void:
    _grid.register_occupant(self, _occupied_tiles())


func _occupied_tiles() -> Array[Vector2i]:
    return [
        _grid_pos,
        _grid_pos + Vector2i(1, 0),
        _grid_pos + Vector2i(0, 1),
        _grid_pos + Vector2i(1, 1),
    ]


func set_target(target: Node2D) -> void:
    _target = target


func _physics_process(_delta: float) -> void:
    if not is_instance_valid(_target):
        return

    var sm := _state_machine
    if sm.current_state == null:
        return

    match sm.current_state.state_id:
        StateId.IDLE:
            _physics_idle()
        StateId.STAGGERED:
            velocity = Vector2.ZERO

    move_and_slide()


func _physics_idle() -> void:
    velocity = Vector2.ZERO
    if _cooldown_timer.time_left > 0.0 or _staggered:
        return
    _state_machine.request_transition(StateId.FACE_TARGET)
    _facing = _cardinal_snap((_target.global_position - global_position).normalized())
    _face_arrow()
    _choose_pattern()
    _state_machine.request_transition(StateId.TELEGRAPH)
    _start_telegraph()


func _cardinal_snap(v: Vector2) -> Vector2:
    if abs(v.x) > abs(v.y):
        return Vector2(sign(v.x), 0.0)
    return Vector2(0.0, sign(v.y))


func _face_arrow() -> void:
    if _facing_arrow != null:
        _facing_arrow.rotation = _facing.angle() - PI / 2.0


func _choose_pattern() -> void:
    var patterns := [AttackPattern.FORWARD_CLEAVE, AttackPattern.LINE_CHARGE, AttackPattern.CROSS_STOMP]
    _current_pattern = patterns[_pattern_index % patterns.size()]
    _pattern_index += 1


func _tile_size() -> float:
    return _grid.tile_size if _grid else 64.0


func _boss_center() -> Vector2:
    return _grid.cell_center(_grid_pos) + Vector2(_tile_size() * 0.5, _tile_size() * 0.5)


func _get_telegraph_tiles() -> Array[Vector2i]:
    var tiles: Array[Vector2i] = []
    var fwd := Vector2i(int(_facing.x), int(_facing.y))
    var right := Vector2i(int(_facing.y), -int(_facing.x)) # perpendicular

    match _current_pattern:
        AttackPattern.FORWARD_CLEAVE:
            for d in range(3):
                for w in range(2):
                    var t := _grid_pos + fwd * (1 + d) + right * w
                    if _grid.is_in_bounds(t):
                        tiles.append(t)
        AttackPattern.LINE_CHARGE:
            for d in range(3):
                var t := _grid_pos + Vector2i(1, 1) + fwd * (1 + d)
                if _grid.is_in_bounds(t):
                    tiles.append(t)
        AttackPattern.CROSS_STOMP:
            var c := _grid_pos + Vector2i(1, 1)
            for d in [-1, 1]:
                var h := c + Vector2i(d, 0)
                var v := c + Vector2i(0, d)
                if _grid.is_in_bounds(h):
                    tiles.append(h)
                if _grid.is_in_bounds(v):
                    tiles.append(v)
    return tiles


func _start_telegraph() -> void:
    var tiles := _get_telegraph_tiles()
    if tiles.is_empty():
        _state_machine.request_transition(StateId.IDLE)
        return
    _telegraph.show_warning(tiles)
    _telegraph_timer.start(TELEGRAPH_DURATION)


func _on_telegraph_done() -> void:
    var tiles := _get_telegraph_tiles()
    _telegraph.show_charge(tiles)
    _state_machine.request_transition(StateId.ATTACK)
    _spawn_hit_volumes(tiles)
    _attack_timer.start(ATTACK_DURATION)


func _spawn_hit_volumes(tiles: Array[Vector2i]) -> void:
    _clear_hitboxes()
    for t in tiles:
        var hitbox := Hitbox.new()
        hitbox.collision_layer = 4
        hitbox.collision_mask = 1
        hitbox.damage = 12.0
        hitbox.damage_interval = 0.0
        hitbox.monitoring = true
        var shape := CollisionShape2D.new()
        shape.shape = RectangleShape2D.new()
        shape.shape.size = Vector2(_tile_size() * 0.9, _tile_size() * 0.9)
        # node-src: ephemeral
        hitbox.add_child(shape)
        hitbox.global_position = _grid.cell_center(t)
        # node-src: ephemeral
        add_child(hitbox)
        _active_hitboxes.append(hitbox)


func _clear_hitboxes() -> void:
    for hb in _active_hitboxes:
        if is_instance_valid(hb):
            hb.queue_free()
    _active_hitboxes.clear()


func _on_attack_done() -> void:
    _telegraph.clear()
    _clear_hitboxes()
    _state_machine.request_transition(StateId.RECOVERY)
    _recovery_timer.start(RECOVERY_DURATION)


func _on_guard_broken() -> void:
    _staggered = true
    _clear_hitboxes()
    _telegraph.clear()
    _state_machine.request_transition(StateId.STAGGERED, true)


func _on_guard_changed(current: int, maximum: int) -> void:
    guard_changed.emit(current, maximum)


func _on_stagger_started() -> void:
    _staggered = true
    guard_stagger_started.emit()
    if _hurt_tween != null and _hurt_tween.is_valid():
        return
    _start_stagger_vfx()


func _start_stagger_vfx() -> void:
    if _body != null:
        if _stagger_tween != null and is_instance_valid(_stagger_tween):
            _stagger_tween.kill()
        _stagger_tween = create_tween()
        _stagger_tween.tween_property(_body, "modulate", STAGGER_VFX_COLOR, 0.2)


func _on_stagger_ended() -> void:
    _staggered = false
    guard_stagger_ended.emit()
    if _stagger_tween != null and is_instance_valid(_stagger_tween):
        _stagger_tween.kill()
    if _body != null:
        _body.modulate = Color.WHITE
    _state_machine.request_transition(StateId.IDLE, true)


func _on_hit_received(amount: float, source: Node, guard_damage_profile: int) -> void:
    if not (source is Node2D):
        return

    var src_pos := (source as Node2D).global_position
    var angle := DirectionResolver.resolve(src_pos, global_position, _facing)
    var gd: int
    if guard_damage_profile == Hitbox.GuardDamageProfile.DASH:
        gd = DirectionResolver.dash_guard_damage(angle)
    else:
        gd = DirectionResolver.normal_guard_damage(angle)

    var will_break_guard := _guard != null \
    and not _guard.is_staggered() \
    and _guard.current() > 0 \
    and gd >= _guard.current()
    var full_damage := _guard == null or _guard.is_staggered() or will_break_guard
    var hp := amount if full_damage else amount * GUARDED_DAMAGE_MULTIPLIER

    if health != null:
        health.take_damage(hp, source)

    if health != null and not health.is_alive():
        return

    if _guard != null:
        _guard.take_guard_damage(gd)


func _on_damaged(_amount: float, _source: Node) -> void:
    if _hurt_tween != null and _hurt_tween.is_valid():
        _hurt_tween.kill()
    _hurt_tween = create_tween()
    _hurt_tween.tween_property(_body, "modulate", Color.WHITE, 0.03)
    _hurt_tween.tween_property(_body, "modulate", Color(0.8, 0.2, 0.2, 1.0), 0.06)
    _hurt_tween.tween_property(_body, "modulate", Color.WHITE, 0.08)
    _hurt_tween.finished.connect(
        func():
            if _body != null:
                if _staggered:
                    _start_stagger_vfx()
                else:
                    _body.modulate = Color.WHITE,
        CONNECT_ONE_SHOT,
    )


func reset() -> void:
    super()
    _staggered = false
    if _stagger_tween != null and is_instance_valid(_stagger_tween):
        _stagger_tween.kill()
    _clear_hitboxes()
