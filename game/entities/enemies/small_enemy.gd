# small_enemy.gd
# 1x1 grid actor enemy. Grid-based AI: reposition step -> face once -> telegraph ->
# attack -> recovery cycle. Attacks are simple 1-tile forward hitboxes.
# Guard 4 (1 shield), uses Hitbox/Hurtbox/Health components from template.
# Uses the template's StateMachine with behaviour-delegation: states own logic,
# the entity provides a public query/command API.
class_name SmallEnemy
extends Entity

const MOVE_SPEED := 120.0
const ATTACK_RANGE := 1.5
const WARNING_DURATION := 0.6
const CHARGE_DURATION := 0.2
const ATTACK_DURATION := 0.2
const RECOVERY_DURATION := 0.4
const CYCLE_COOLDOWN := 1.0
const CARDINAL_DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const NO_BLOCKED_CELL := Vector2i(-1, -1)
const GUARDED_DAMAGE_MULTIPLIER := 0.2
const STAGGER_VFX_COLOR := Color(0.3, 0.5, 1.0, 1.0)
const PATH_DEBUG_COLOR := Color(0.2, 0.8, 1.0, 0.8)
const PATH_DEBUG_WIDTH := 4.0

@export var death_sfx_event: SpatialAudioEvent
@export var damaged_sfx_event: SpatialAudioEvent
@export var blocked_sfx_event: SpatialAudioEvent

@onready var _hitbox: Hitbox = %AttackHitbox
@onready var _state_machine: StateMachine = %StateMachine
@onready var _guard: Guard = %Guard
@onready var _attack_controller: SmallEnemyAttackController = %AttackController
@onready var _status_bars: EnemyStatusBars = %StatusBars
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var _body: Polygon2D = %Body
@onready var _facing_arrow: Polygon2D = %FacingArrow
@onready var _telegraph: TileTelegraph = %TileTelegraph

var _grid: GridArena
var _target: Node2D
var _grid_pos: Vector2i
var _facing: Vector2 = Vector2.DOWN
var _cooldown_timer: Timer
var _staggered: bool = false
var _stagger_tween: Tween
var _hurt_tween: Tween
var _planned_path: Array[Vector2i] = []
var _active_path_cell: Vector2i
var _has_active_path_cell: bool = false


func setup(grid: GridArena, target: Node2D) -> void:
    _grid = grid
    _target = target
    if is_node_ready():
        _configure_attack_controller()

# -- Public API (called BY states, not the other way around) --


func has_target() -> bool:
    return is_instance_valid(_target)


func get_target() -> Node2D:
    return _target


func set_target(target: Node2D) -> void:
    _target = target


func can_attack() -> bool:
    if _grid == null or _attack_controller == null or not has_target():
        return false
    var target_cell := _grid.world_to_grid(_target.global_position)
    return target_cell in _attack_controller.get_attack_cells(_grid_pos, _facing)


func is_staggered() -> bool:
    return _staggered


func set_staggered(value: bool) -> void:
    _staggered = value


func cooldown_active() -> bool:
    return _cooldown_timer != null and _cooldown_timer.time_left > 0.0


func start_cooldown() -> void:
    if _cooldown_timer != null:
        _cooldown_timer.start(CYCLE_COOLDOWN)


func tile_size() -> float:
    return _grid.tile_size if _grid else 64.0


func get_grid() -> GridArena:
    return _grid


func get_grid_pos() -> Vector2i:
    return _grid_pos


func set_grid_pos(pos: Vector2i) -> void:
    _grid_pos = pos


func get_facing() -> Vector2:
    return _facing


func set_facing(v: Vector2) -> void:
    _facing = v


func plan_next_action() -> bool:
    clear_planned_action()

    if _grid == null or _attack_controller == null or not has_target():
        return false

    var start := _grid_pos
    var target_cell := _grid.world_to_grid(_target.global_position)
    var attack_origins: Array[Vector2i] = []
    var blocked_cell := target_cell
    var uses_target_collision := false

    if _attack_controller.get_attack_pattern() == SmallEnemyAttackController.AttackPattern.SURROUND_3X3:
        if not _grid.is_in_bounds(target_cell):
            return false
        uses_target_collision = true
        attack_origins.append(target_cell)
        blocked_cell = NO_BLOCKED_CELL
    else:
        for facing_cell: Vector2i in CARDINAL_DIRECTIONS:
            var facing := Vector2(facing_cell.x, facing_cell.y)
            for x in range(GridArena.GRID_SIZE.x):
                for y in range(GridArena.GRID_SIZE.y):
                    var origin_cell := Vector2i(x, y)
                    if origin_cell != start and _grid.is_blocked(origin_cell):
                        continue
                    if target_cell not in _attack_controller.get_attack_cells(origin_cell, facing):
                        continue
                    if origin_cell not in attack_origins:
                        attack_origins.append(origin_cell)

    if attack_origins.is_empty():
        return false

    if start in attack_origins:
        queue_redraw()
        return true

    var path := _find_path_to_attack_cell(start, blocked_cell, attack_origins)
    if path.is_empty() and uses_target_collision:
        attack_origins = _collect_adjacent_attack_origin_cells(target_cell, start)
        blocked_cell = target_cell
        if attack_origins.is_empty():
            return false
        if start in attack_origins:
            queue_redraw()
            return true
        path = _find_path_to_attack_cell(start, blocked_cell, attack_origins)

    if path.is_empty():
        return false

    _planned_path = path
    _refresh_planned_reservations()
    queue_redraw()
    return true


func clear_planned_action() -> void:
    if _grid != null:
        _grid.clear_reservation(self)
    _planned_path.clear()
    _has_active_path_cell = false
    queue_redraw()


func has_planned_action() -> bool:
    return not _planned_path.is_empty()


func has_planned_path() -> bool:
    return not _planned_path.is_empty()


func consume_next_planned_cell() -> Vector2i:
    var next := _planned_path[0]
    _planned_path.remove_at(0)
    _active_path_cell = next
    _has_active_path_cell = true
    _refresh_planned_reservations()
    queue_redraw()
    return next


func face_toward_cell(target_cell: Vector2i) -> void:
    var step := target_cell - _grid_pos
    if step == Vector2i.ZERO:
        return
    _facing = Vector2(signi(step.x), signi(step.y))
    face_arrow()


func face_target_position() -> void:
    if not has_target():
        return
    var direction := _target.global_position - global_position
    if direction == Vector2.ZERO:
        return
    _facing = cardinal_snap(direction)
    face_arrow()


func cardinal_snap(v: Vector2) -> Vector2:
    if abs(v.x) > abs(v.y):
        return Vector2(sign(v.x), 0.0)
    return Vector2(0.0, sign(v.y))


func face_arrow() -> void:
    if _facing_arrow != null:
        _facing_arrow.rotation = _facing.angle() - PI / 2.0


func register_grid_occupant() -> void:
    _grid.register_occupant(self, [_grid_pos])


func get_attack_controller() -> SmallEnemyAttackController:
    return _attack_controller


func get_guard() -> Guard:
    return _guard


func begin_death() -> void:
    velocity = Vector2.ZERO
    clear_planned_action()
    _cancel_attack()
    if _stagger_tween != null and is_instance_valid(_stagger_tween):
        _stagger_tween.kill()
    if health != null:
        health.set_enabled(false)
    if hurtbox != null:
        hurtbox.set_enabled(false)
    if _hitbox != null:
        _hitbox.set_enabled(false)


func play_death_sfx() -> void:
    if death_sfx_event != null:
        AudioManager.play_event(death_sfx_event, global_position)

# -- Lifecycle --


func _ready() -> void:
    super()
    _hitbox.set_enabled(false)
    _configure_attack_controller()
    if _attack_controller != null:
        _attack_controller.randomize_attack_pattern()
    if _grid != null:
        _grid_pos = _grid.world_to_grid(global_position)
        _grid.register_occupant(self, [_grid_pos])

    if hurtbox != null:
        hurtbox.hit_received.connect(_on_hit_received)

    if health != null:
        health.health_changed.connect(_on_health_changed)
        health.damaged.connect(_on_damaged)
        _on_health_changed(health.current(), health.max_health)

    _cooldown_timer = Timer.new()
    _cooldown_timer.one_shot = true
    add_child(_cooldown_timer)

    if _guard != null:
        _guard.guard_changed.connect(_on_guard_changed)
        _guard.guard_broken.connect(_on_guard_broken)
        _guard.stagger_started.connect(_on_stagger_started)
        _guard.stagger_ended.connect(_on_stagger_ended)
        _on_guard_changed(_guard.current(), _guard.max_guard)


func _physics_process(_delta: float) -> void:
    if not is_instance_valid(_target):
        velocity = Vector2.ZERO
        move_and_slide()
        return

    move_and_slide()
    queue_redraw()


func _draw() -> void:
    if _grid == null or (not _has_active_path_cell and _planned_path.is_empty()):
        return

    var previous := Vector2.ZERO
    if _has_active_path_cell:
        var active_point := to_local(_grid.cell_center(_active_path_cell))
        draw_line(previous, active_point, PATH_DEBUG_COLOR, PATH_DEBUG_WIDTH)
        draw_circle(active_point, PATH_DEBUG_WIDTH * 1.5, PATH_DEBUG_COLOR)
        previous = active_point
    else:
        previous = to_local(_grid.cell_center(_grid_pos))

    for cell in _planned_path:
        var point := to_local(_grid.cell_center(cell))
        draw_line(previous, point, PATH_DEBUG_COLOR, PATH_DEBUG_WIDTH)
        draw_circle(point, PATH_DEBUG_WIDTH * 1.5, PATH_DEBUG_COLOR)
        previous = point


func _update_grid_pos() -> void:
    var new_cell := _grid.world_to_grid(global_position)
    if new_cell != _grid_pos:
        _grid_pos = new_cell
        _grid.register_occupant(self, [_grid_pos])

# -- Signal handlers --


func _on_guard_broken() -> void:
    _staggered = true
    clear_planned_action()
    _cancel_attack()
    _state_machine.request_transition(SmallEnemyState.SmallEnemyStateId.STAGGERED, true)


func _on_guard_changed(current: int, maximum: int) -> void:
    if _status_bars != null:
        _status_bars.set_guard(current, maximum)


func _on_health_changed(current: float, maximum: float) -> void:
    if _status_bars != null:
        _status_bars.set_health(current, maximum)


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

    var will_break_guard := _guard != null and not _guard.is_staggered() and _guard.current() > 0 and gd >= _guard.current()

    var full_damage := _guard == null or _guard.is_staggered() or will_break_guard
    var hp := amount if full_damage else amount * GUARDED_DAMAGE_MULTIPLIER

    if full_damage:
        if damaged_sfx_event != null:
            AudioManager.play_event(damaged_sfx_event, global_position)
    else:
        var sfx_event := damaged_sfx_event if angle == DirectionResolver.HitAngle.BACK else blocked_sfx_event
        if sfx_event != null:
            AudioManager.play_event(sfx_event, global_position)

    if health != null:
        health.take_damage(hp, source)

    if health != null and not health.is_alive():
        _state_machine.request_transition(SmallEnemyState.SmallEnemyStateId.DEAD, true)
        return

    if _guard != null:
        _guard.take_guard_damage(gd)


func _on_stagger_started() -> void:
    _staggered = true
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
    if _body != null:
        if _stagger_tween != null and is_instance_valid(_stagger_tween):
            _stagger_tween.kill()
        _stagger_tween = create_tween()
        _stagger_tween.tween_property(_body, "modulate", Color.WHITE, 0.3)


func _cancel_attack() -> void:
    if _attack_controller != null:
        _attack_controller.cancel()


func _configure_attack_controller() -> void:
    if _attack_controller == null:
        return
    _attack_controller.setup(_grid, _telegraph, _hitbox, self)


func _find_path_to_attack_cell(start: Vector2i, blocked_cell: Vector2i, attack_cells: Array[Vector2i]) -> Array[Vector2i]:
    var queue: Array[Vector2i] = [start]
    var came_from: Dictionary = { }
    var queue_index := 0
    var goal := Vector2i(-1, -1)
    came_from[start] = start

    while queue_index < queue.size():
        var current := queue[queue_index]
        queue_index += 1

        if current in attack_cells:
            goal = current
            break

        for direction: Vector2i in CARDINAL_DIRECTIONS:
            var next := current + direction
            if came_from.has(next):
                continue
            if not _can_path_through(next, start, blocked_cell):
                continue
            came_from[next] = current
            queue.append(next)

    if goal == Vector2i(-1, -1):
        var empty_path: Array[Vector2i] = []
        return empty_path

    var path: Array[Vector2i] = []
    var path_cell := goal
    while came_from[path_cell] != path_cell:
        path.push_front(path_cell)
        path_cell = came_from[path_cell]
    return path


func _can_path_through(cell: Vector2i, start: Vector2i, blocked_cell: Vector2i) -> bool:
    if not _grid.is_in_bounds(cell):
        return false
    if cell == blocked_cell:
        return false
    if cell != start and _grid.is_blocked(cell):
        return false
    return true


func _collect_adjacent_attack_origin_cells(target_cell: Vector2i, start: Vector2i) -> Array[Vector2i]:
    var origin_cells: Array[Vector2i] = []
    for direction: Vector2i in CARDINAL_DIRECTIONS:
        var neighbor := target_cell + direction
        if not _grid.is_in_bounds(neighbor):
            continue
        if neighbor == start or not _grid.is_blocked(neighbor):
            origin_cells.append(neighbor)
    return origin_cells


func _refresh_planned_reservations() -> void:
    if _grid == null:
        return

    var reserved_cells: Array[Vector2i] = []
    if _has_active_path_cell:
        reserved_cells.append(_active_path_cell)
    if not _planned_path.is_empty():
        var final_cell := _planned_path[_planned_path.size() - 1]
        if final_cell not in reserved_cells:
            reserved_cells.append(final_cell)

    if reserved_cells.is_empty():
        _grid.clear_reservation(self)
    else:
        _grid.reserve_cells(self, reserved_cells)

# -- Pool lifecycle --


func reset() -> void:
    super()
    _staggered = false
    if _body != null:
        _body.modulate = Color.WHITE
    if _stagger_tween != null and is_instance_valid(_stagger_tween):
        _stagger_tween.kill()
    clear_planned_action()
    if _grid != null:
        _grid_pos = _grid.world_to_grid(global_position)
        _grid.register_occupant(self, [_grid_pos])
    if health != null:
        _on_health_changed(health.current(), health.max_health)
    if _guard != null:
        _on_guard_changed(_guard.current(), _guard.max_guard)
