# grid_enemy.gd
# Shared base for 1x1 grid enemies with target chasing, guard, stagger, and death handling.
class_name GridEnemy
extends Enemy

const MOVE_SPEED := 120.0
const CYCLE_COOLDOWN := 1.0
const CARDINAL_DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const EIGHT_DIRECTIONS := [
    Vector2i.RIGHT,
    Vector2i.LEFT,
    Vector2i.DOWN,
    Vector2i.UP,
    Vector2i(1, 1),
    Vector2i(1, -1),
    Vector2i(-1, 1),
    Vector2i(-1, -1),
]
const NO_BLOCKED_CELL := Vector2i(-1, -1)
const GUARDED_DAMAGE_MULTIPLIER := 0.2
const STAGGER_VFX_COLOR := Color(0.3, 0.5, 1.0, 1.0)
const PATH_DEBUG_COLOR := Color(0.2, 0.8, 1.0, 0.8)
const PATH_DEBUG_WIDTH := 4.0

# -- Movement -----------------------------------------------------------------
var _allow_diagonal_movement: bool = false


func _get_movement_directions() -> Array:
    return EIGHT_DIRECTIONS if _allow_diagonal_movement else CARDINAL_DIRECTIONS

# -- Exports ------------------------------------------------------------------
@export var death_sfx_event: SpatialAudioEvent
@export var damaged_sfx_event: SpatialAudioEvent
@export var blocked_sfx_event: SpatialAudioEvent
@export var enemy_data: EnemyData

# -- State --------------------------------------------------------------------
var _grid: GridArena
var _target: Node2D
var _grid_pos: Vector2i
var _facing: Vector2 = Vector2.DOWN
var _staggered: bool = false
var _planned_path: Array[Vector2i] = []
var _active_path_cell: Vector2i
var _has_active_path_cell: bool = false
var _reservation_is_attack: bool = false
var _attack_windup_vfx: Node2D

# -- Timer / tween handles ----------------------------------------------------
var _cooldown_timer: Timer
var _stagger_tween: Tween
var _hurt_tween: Tween

# -- Node references ----------------------------------------------------------
@onready var _state_machine: StateMachine = _find_state_machine()
@onready var _guard: Guard = _find_guard()
@onready var _status_bars: EnemyStatusBars = _find_status_bars()
@onready var hurtbox: Hurtbox = _find_hurtbox()
@onready var _body: Polygon2D = _find_body()
@onready var _facing_arrow: Polygon2D = _find_facing_arrow()

# == Lifecycle ================================================================


func _ready() -> void:
    super()
    if _grid != null:
        _grid_pos = _grid.world_to_grid(global_position)
        register_grid_occupant()
        _grid.register_enemy_entity(self)
        if not _grid.reservation_lost.is_connected(_on_reservation_lost):
            _grid.reservation_lost.connect(_on_reservation_lost)

    if hurtbox != null:
        hurtbox.hit_received.connect(_on_hit_received)

    if health != null:
        health.damaged.connect(_on_damaged)
        _on_health_changed(health.current(), health.max_health)

    _cooldown_timer = Timer.new()
    _cooldown_timer.one_shot = true
    # node-src: timer
    add_child(_cooldown_timer)

    if _guard != null:
        _guard.guard_changed.connect(_on_guard_changed)
        _guard.guard_broken.connect(_on_guard_broken)
        _guard.stagger_started.connect(_on_stagger_started)
        _guard.stagger_ended.connect(_on_stagger_ended)
        _on_guard_changed(_guard.current(), _guard.max_guard)

    face_arrow()
    _init_debug_fsm_state()


func _physics_process(_delta: float) -> void:
    if not is_instance_valid(_target):
        velocity = Vector2.ZERO
        move_and_slide()
        return

    if _grid == null:
        velocity = global_position.direction_to(_target.global_position) * get_move_speed()

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

# == Overridden Custom Methods ================================================


func reset() -> void:
    super()
    _staggered = false
    stop_attack_windup_vfx()
    if _body != null:
        _body.modulate = Color.WHITE
    if _stagger_tween != null and is_instance_valid(_stagger_tween):
        _stagger_tween.kill()
    clear_planned_path()
    if _grid != null:
        _grid_pos = _grid.world_to_grid(global_position)
        register_grid_occupant()
    if health != null:
        _on_health_changed(health.current(), health.max_health)
    if _guard != null:
        _on_guard_changed(_guard.current(), _guard.max_guard)
    _reset_extra()

# == Signal handlers ==========================================================


## Clears planned movement when a higher-priority claim takes our reservation.
func _on_reservation_lost(_entity: Object) -> void:
    if _entity != self:
        return
    # if Debug.enabled:
    #     print(name, " lost reservation at ", _grid_pos, " — higher-priority claim won")
    clear_planned_path()


func _on_guard_broken() -> void:
    _staggered = true
    stop_attack_windup_vfx()
    clear_planned_path()
    _on_guard_broken_extra()
    var staggered_state_id := get_staggered_state_id()
    if _state_machine != null and staggered_state_id >= 0:
        _state_machine.request_transition(staggered_state_id, true)


func _on_guard_changed(current: int, maximum: int) -> void:
    if _status_bars != null:
        _status_bars.set_guard(current, maximum)


func _on_health_changed(current: float, maximum: float) -> void:
    super(current, maximum)
    if _status_bars != null:
        _status_bars.set_health(current, maximum)


func _on_damaged(_amount: float, _source: Node) -> void:
    if _body == null:
        return
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
    var guard_damage := _resolve_guard_damage(angle, guard_damage_profile)
    var will_break_guard := _guard != null and not _guard.is_staggered() and _guard.current() > 0 and guard_damage >= _guard.current()
    var full_damage := _guard == null or _guard.is_staggered() or will_break_guard
    var hp_damage := amount if full_damage else amount * GUARDED_DAMAGE_MULTIPLIER

    var sfx_event: SpatialAudioEvent = null
    if full_damage:
        sfx_event = damaged_sfx_event
    else:
        sfx_event = _get_blocked_hit_sfx(angle)
    if sfx_event != null:
        AudioManager.play_event(sfx_event, global_position)

    if will_break_guard:
        CombatFeedbackVFX.play_guard_break(global_position, self)
    elif full_damage:
        CombatFeedbackVFX.play_full_damage(global_position, self)
    else:
        CombatFeedbackVFX.play_shielded_hit(global_position, src_pos.angle_to_point(global_position), self)

    if health != null:
        health.take_damage(hp_damage, source)

    if health != null and not health.is_alive():
        var dead_state_id := get_dead_state_id()
        if _state_machine != null and dead_state_id >= 0:
            _state_machine.request_transition(dead_state_id, true)
        return

    if _guard != null:
        _guard.take_guard_damage(guard_damage)


func _on_stagger_started() -> void:
    _staggered = true
    if _hurt_tween != null and _hurt_tween.is_valid():
        return
    _start_stagger_vfx()


func _on_stagger_ended() -> void:
    _staggered = false
    if _body != null:
        if _stagger_tween != null and is_instance_valid(_stagger_tween):
            _stagger_tween.kill()
        _stagger_tween = create_tween()
        _stagger_tween.tween_property(_body, "modulate", Color.WHITE, 0.3)

# == Common API ================================================================


func setup(grid: GridArena, target: Node2D) -> void:
    _grid = grid
    _target = target
    if is_node_ready() and _grid != null:
        _grid_pos = _grid.world_to_grid(global_position)
        register_grid_occupant()
        _grid.register_enemy_entity(self)
        if not _grid.reservation_lost.is_connected(_on_reservation_lost):
            _grid.reservation_lost.connect(_on_reservation_lost)
        _after_setup_ready()


func has_target() -> bool:
    return is_instance_valid(_target)


func get_target() -> Node2D:
    return _target


## Returns the target's current grid cell, or NO_BLOCKED_CELL when unavailable.
func get_target_cell() -> Vector2i:
    if _grid == null or not has_target():
        return NO_BLOCKED_CELL
    return _grid.world_to_grid(_target.global_position)


func set_target(target: Node2D) -> void:
    _target = target


func is_staggered() -> bool:
    return _staggered


func set_staggered(value: bool) -> void:
    _staggered = value


func cooldown_active() -> bool:
    return _cooldown_timer != null and _cooldown_timer.time_left > 0.0


func get_cycle_cooldown() -> float:
    return enemy_data.cycle_cooldown if enemy_data != null else CYCLE_COOLDOWN


func start_cooldown() -> void:
    if _cooldown_timer != null:
        _cooldown_timer.start(get_cycle_cooldown())


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
    clear_planned_path()
    _reservation_is_attack = false

    if _grid == null or not has_target():
        return false

    var start := _grid_pos
    var target_cell := get_target_cell()

    if not _grid.is_in_bounds(target_cell):
        return false

    if start == target_cell:
        queue_redraw()
        return true

    var path: Array[Vector2i] = []
    if _can_plan_goal_cell(target_cell, false):
        path = _find_path_to_cell(start, NO_BLOCKED_CELL, [target_cell], false)

    if path.is_empty():
        var fallback_goals := _collect_adjacent_goal_cells(target_cell, start)
        if fallback_goals.is_empty():
            return false
        if start in fallback_goals:
            queue_redraw()
            return true
        path = _find_path_to_cell(start, target_cell, fallback_goals, false)

    if path.is_empty():
        return false

    _planned_path = path
    if not _refresh_planned_reservations():
        clear_planned_path()
        return false
    queue_redraw()
    return true


## Plans ordinary movement to a reachable cell adjacent to the target.
func plan_approach_action() -> bool:
    clear_planned_path()
    _reservation_is_attack = false

    if _grid == null or not has_target():
        return false

    var start := _grid_pos
    var target_cell := get_target_cell()

    if not _grid.is_in_bounds(target_cell):
        return false

    if start == target_cell:
        queue_redraw()
        return true

    var fallback_goals := _collect_adjacent_goal_cells(target_cell, start)
    if fallback_goals.is_empty():
        return false
    if start in fallback_goals:
        queue_redraw()
        return true

    var path := _find_path_to_cell(start, target_cell, fallback_goals, false)
    if path.is_empty():
        return false

    _planned_path = path
    if not _refresh_planned_reservations():
        clear_planned_path()
        return false
    queue_redraw()
    return true


## Clears pending grid movement, active path debug state, and path reservations.
func clear_planned_path() -> void:
    if _grid != null:
        _grid.clear_reservation(self)
    _planned_path.clear()
    _has_active_path_cell = false
    queue_redraw()


func has_planned_action() -> bool:
    return not _planned_path.is_empty()


func has_planned_path() -> bool:
    return not _planned_path.is_empty()


## Returns the first cell of the planned path without consuming it, or NO_BLOCKED_CELL.
func get_planned_path_first() -> Vector2i:
    return _planned_path[0] if not _planned_path.is_empty() else NO_BLOCKED_CELL


func consume_next_planned_cell() -> Vector2i:
    var next := _planned_path[0]
    _planned_path.remove_at(0)
    _active_path_cell = next
    _has_active_path_cell = true
    if not _refresh_planned_reservations():
        _planned_path.clear()
        _grid.clear_reservation(self)
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
    if _body != null:
        _body.rotation = _facing.angle() + PI / 2.0
    if hurtbox != null:
        hurtbox.rotation = _facing.angle() + PI / 2.0


func register_grid_occupant() -> void:
    if _grid != null:
        _grid.register_occupant(self, [_grid_pos])


## Returns true when the target shares this enemy's row or column.
func is_target_cardinally_aligned() -> bool:
    if _grid == null or not has_target():
        return false
    var target_cell := get_target_cell()
    return _grid_pos.x == target_cell.x or _grid_pos.y == target_cell.y


## Returns true when the target is within Chebyshev grid range.
func is_target_within_grid_range(cell_range: int) -> bool:
    if _grid == null or not has_target():
        return false
    var target_cell := get_target_cell()
    var diff := target_cell - _grid_pos
    return absi(diff.x) <= cell_range and absi(diff.y) <= cell_range


func get_guard() -> Guard:
    return _guard


func begin_death() -> void:
    velocity = Vector2.ZERO
    stop_attack_windup_vfx()
    clear_planned_path()
    _on_begin_death_extra()
    if _stagger_tween != null and is_instance_valid(_stagger_tween):
        _stagger_tween.kill()
    if health != null:
        health.set_enabled(false)
    if hurtbox != null:
        hurtbox.set_enabled(false)


## Force-death entry point for boss wave resolution. Routes through the existing
## death cleanup flow and emits the died signal so owning systems can react.
func force_death() -> void:
    if health != null and not health.is_alive():
        return
    begin_death()
    var dead_state_id := get_dead_state_id()
    if _state_machine != null and dead_state_id >= 0:
        _state_machine.request_transition(dead_state_id, true)
    died.emit(self)


func play_death_sfx() -> void:
    if death_sfx_event != null:
        AudioManager.play_event(death_sfx_event, global_position)


func get_idle_state_id() -> int:
    return EnemyState.EnemyStateId.IDLE


func get_reposition_state_id() -> int:
    return EnemyState.EnemyStateId.REPOSITION


func get_face_state_id() -> int:
    return EnemyState.EnemyStateId.FACE_TARGET


func get_recovery_state_id() -> int:
    return EnemyState.EnemyStateId.RECOVERY


func get_staggered_state_id() -> int:
    return EnemyState.EnemyStateId.STAGGERED


func get_dead_state_id() -> int:
    return EnemyState.EnemyStateId.DEAD


func get_after_face_state_id() -> int:
    return get_idle_state_id()


func get_pre_plan_state_id() -> int:
    return -1


func get_arrival_override_state_id() -> int:
    return -1


func get_current_attack_data() -> EnemyAttackData:
    return null


func get_warning_duration() -> float:
    var attack := get_current_attack_data()
    return attack.warning_duration if attack != null else 0.6


func get_charge_duration() -> float:
    var attack := get_current_attack_data()
    return attack.charge_duration if attack != null else 0.2


func get_attack_duration() -> float:
    var attack := get_current_attack_data()
    return attack.active_duration if attack != null else 0.2


## Performs shared setup when an enemy commits to a non-reposition action.
func begin_committed_action() -> bool:
    velocity = Vector2.ZERO
    clear_planned_path()
    return true


## Default attack telegraph entry; enemies with telegraphs extend this setup.
func begin_attack_telegraph() -> bool:
    return begin_committed_action()


func get_attack_state_id() -> int:
    return EnemyState.EnemyStateId.ATTACK


## Shows the charge telegraph phase. Enemies with telegraphs extend this.
func show_attack_charge() -> void:
    pass


## Starts the active attack phase. Returns false if attack cannot begin.
func begin_attack() -> bool:
    return false


## Ends the active attack phase and disables hitboxes.
func end_attack() -> void:
    pass


## Starts a reusable attack windup loop for telegraphed actions.
func start_attack_windup_vfx(style: int = CombatFeedbackVFX.WindupStyle.TILE) -> void:
    stop_attack_windup_vfx()
    _attack_windup_vfx = CombatFeedbackVFX.start_attack_windup_loop(global_position, _facing, self, style)


## Stops the active attack windup loop, if one exists.
func stop_attack_windup_vfx() -> void:
    CombatFeedbackVFX.stop_loop(_attack_windup_vfx)
    _attack_windup_vfx = null


## Updates per-frame attack motion. Returns true when motion is complete.
func update_attack_motion(_delta: float) -> bool:
    return false


## Plans a charge approach that prefers lining up with the target row or column.
func plan_charge_line_action() -> bool:
    clear_planned_path()
    _reservation_is_attack = false

    if _grid == null or not has_target():
        return false

    var start := _grid_pos
    var target_cell := get_target_cell()
    if not _grid.is_in_bounds(target_cell):
        return false
    if start == target_cell:
        queue_redraw()
        return true

    var path: Array[Vector2i] = []
    var line_goals := _collect_line_goal_cells(target_cell, start)
    if not line_goals.is_empty():
        if start in line_goals:
            queue_redraw()
            return true
        path = _find_path_to_cell(start, NO_BLOCKED_CELL, line_goals, false)

    if path.is_empty() and _can_plan_goal_cell(target_cell, false):
        path = _find_path_to_cell(start, NO_BLOCKED_CELL, [target_cell], false)

    if path.is_empty():
        var fallback_goals := _collect_adjacent_goal_cells(target_cell, start)
        if fallback_goals.is_empty():
            return false
        if start in fallback_goals:
            queue_redraw()
            return true
        path = _find_path_to_cell(start, target_cell, fallback_goals, false)

    if path.is_empty():
        return false

    _planned_path = path
    if not _refresh_planned_reservations():
        clear_planned_path()
        return false
    queue_redraw()
    return true


func get_move_speed() -> float:
    return enemy_data.move_speed if enemy_data != null else MOVE_SPEED


func get_recovery_duration() -> float:
    return enemy_data.default_recovery_duration if enemy_data != null else 3.0


## Shared cell-origin planning for tile attacks. Computes target-derived origin
## candidates, verifies the committed facing can hit the target, and paths to one.
func plan_cell_attack_action(get_cells_for_origin: Callable, get_origins_for_target: Callable = Callable()) -> bool:
    clear_planned_path()
    _reservation_is_attack = true

    if _grid == null or not has_target():
        return false

    var start := _grid_pos
    var target_cell := get_target_cell()
    if not _grid.is_in_bounds(target_cell):
        return false

    var candidate_origins := _collect_attack_origin_candidates(target_cell, get_origins_for_target)
    var attack_origins: Array[Vector2i] = []
    for origin_cell: Vector2i in candidate_origins:
        if origin_cell == target_cell:
            continue
        if origin_cell != start and not _can_plan_goal_cell(origin_cell, true):
            continue
        var facing := cardinal_snap(Vector2(target_cell - origin_cell))
        var cells: Array[Vector2i] = get_cells_for_origin.call(origin_cell, facing)
        if target_cell not in cells:
            continue
        if origin_cell not in attack_origins:
            attack_origins.append(origin_cell)

    if attack_origins.is_empty():
        return false

    if start in attack_origins:
        queue_redraw()
        return true

    var path := _find_path_to_cell(start, target_cell, attack_origins, true)
    if path.is_empty():
        return false

    _planned_path = path
    if not _refresh_planned_reservations():
        clear_planned_path()
        return false
    queue_redraw()
    return true

# == Grid helpers ==============================================================


func _collect_attack_origin_candidates(target_cell: Vector2i, get_origins_for_target: Callable) -> Array[Vector2i]:
    if get_origins_for_target.is_valid():
        var origins: Array[Vector2i] = get_origins_for_target.call(target_cell)
        return origins
    return _collect_all_grid_origin_cells()


func _collect_all_grid_origin_cells() -> Array[Vector2i]:
    var origins: Array[Vector2i] = []
    for x in range(_grid.grid_size.x):
        for y in range(_grid.grid_size.y):
            origins.append(Vector2i(x, y))
    return origins


func _update_grid_pos() -> void:
    var new_cell := _grid.world_to_grid(global_position)
    if new_cell != _grid_pos:
        _grid_pos = new_cell
        register_grid_occupant()


func _find_path_to_cell(start: Vector2i, blocked_cell: Vector2i, goal_cells: Array[Vector2i], is_attack: bool) -> Array[Vector2i]:
    var queue: Array[Vector2i] = [start]
    var came_from: Dictionary = { }
    var queue_index := 0
    var goal := Vector2i(-1, -1)
    came_from[start] = start

    while queue_index < queue.size():
        var current := queue[queue_index]
        queue_index += 1

        if current in goal_cells:
            goal = current
            break

        for direction: Vector2i in _get_movement_directions():
            var next := current + direction
            if came_from.has(next):
                continue
            if not _can_path_through(current, next, start, blocked_cell, goal_cells, is_attack):
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


func _can_path_through(
        current: Vector2i,
        next: Vector2i,
        start: Vector2i,
        blocked_cell: Vector2i,
        goal_cells: Array[Vector2i],
        is_attack: bool,
) -> bool:
    if not _grid.can_move_between(current, next):
        return false
    if next == blocked_cell:
        return false
    if _needs_committed_path_cell(current, next, start, goal_cells):
        return _can_claim_committed_path_cell(next, is_attack)
    return true


func _needs_committed_path_cell(
        current: Vector2i,
        next: Vector2i,
        start: Vector2i,
        goal_cells: Array[Vector2i],
) -> bool:
    return current == start or next in goal_cells


func _can_claim_committed_path_cell(cell: Vector2i, is_attack: bool) -> bool:
    if _grid.is_occupied(cell):
        return false
    if not _grid.is_reserved(cell):
        return true
    return _grid.can_reserve_cell(self, cell, is_attack)


func _can_plan_goal_cell(cell: Vector2i, is_attack: bool) -> bool:
    if not _grid.is_walkable(cell):
        return false
    return _can_claim_committed_path_cell(cell, is_attack)


func _collect_adjacent_goal_cells(target_cell: Vector2i, start: Vector2i) -> Array[Vector2i]:
    var goal_cells: Array[Vector2i] = []
    for direction: Vector2i in _get_movement_directions():
        var neighbor := target_cell + direction
        if not _grid.is_in_bounds(neighbor):
            continue
        if neighbor == start or _can_plan_goal_cell(neighbor, false):
            goal_cells.append(neighbor)
    return goal_cells


func _collect_line_goal_cells(target_cell: Vector2i, start: Vector2i) -> Array[Vector2i]:
    var goals: Array[Vector2i] = []
    for x in range(_grid.grid_size.x):
        var cell := Vector2i(x, target_cell.y)
        if cell == target_cell:
            continue
        if cell == start or _can_plan_goal_cell(cell, false):
            goals.append(cell)
    for y in range(_grid.grid_size.y):
        var cell := Vector2i(target_cell.x, y)
        if cell == target_cell:
            continue
        if cell in goals:
            continue
        if cell == start or _can_plan_goal_cell(cell, false):
            goals.append(cell)
    return goals


func _refresh_planned_reservations() -> bool:
    if _grid == null:
        return true

    var reserved_cells: Array[Vector2i] = []
    var active_cells: Array[Vector2i] = []
    if _has_active_path_cell:
        reserved_cells.append(_active_path_cell)
        active_cells.append(_active_path_cell)
    if not _planned_path.is_empty():
        var final_cell := _planned_path[_planned_path.size() - 1]
        if final_cell not in reserved_cells:
            reserved_cells.append(final_cell)
        if not _has_active_path_cell:
            var first_cell := _planned_path[0]
            if first_cell not in reserved_cells:
                reserved_cells.append(first_cell)

    if reserved_cells.is_empty():
        _grid.clear_reservation(self)
        return true

    return _grid.reserve_cells_with_active_steps(self, reserved_cells, _reservation_is_attack, active_cells)

# == Setup helpers =============================================================

var _fsm_debug_label: Label


func _init_debug_fsm_state() -> void:
    if _state_machine == null:
        return
    if not _state_machine.state_changed.is_connected(_on_fsm_state_changed):
        _state_machine.state_changed.connect(_on_fsm_state_changed)
    if not Debug.toggled.is_connected(_on_debug_mode_toggled):
        Debug.toggled.connect(_on_debug_mode_toggled)
    if Debug.enabled:
        _ensure_fsm_label()
        _sync_fsm_label.call_deferred()


func _on_debug_mode_toggled(enabled: bool) -> void:
    if enabled:
        _ensure_fsm_label()
        _sync_fsm_label.call_deferred()
    elif _fsm_debug_label != null:
        _fsm_debug_label.visible = false


func _ensure_fsm_label() -> void:
    if _fsm_debug_label != null:
        _fsm_debug_label.visible = true
        return
    _fsm_debug_label = Label.new()
    _fsm_debug_label.name = "FsmStateDebugLabel"
    _fsm_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _fsm_debug_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8))
    _fsm_debug_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
    _fsm_debug_label.add_theme_constant_override("shadow_outline_size", 1)
    _fsm_debug_label.position = Vector2(0.0, 0.0)
    # node-src: debug
    add_child(_fsm_debug_label)


func _sync_fsm_label() -> void:
    if _fsm_debug_label == null or _state_machine == null:
        return
    if _state_machine.current_state != null:
        _fsm_debug_label.text = _state_machine.current_state.name


func _on_fsm_state_changed(_from: State, to: State) -> void:
    if _fsm_debug_label != null:
        _fsm_debug_label.text = to.name


func _find_state_machine() -> StateMachine:
    return _find_child_node("StateMachine") as StateMachine


func _find_guard() -> Guard:
    return _find_child_node("Guard") as Guard


func _find_status_bars() -> EnemyStatusBars:
    return _find_child_node("StatusBars") as EnemyStatusBars


func _find_hurtbox() -> Hurtbox:
    return _find_child_node("Hurtbox") as Hurtbox


func _find_body() -> Polygon2D:
    return _find_child_node("Body") as Polygon2D


func _find_facing_arrow() -> Polygon2D:
    return _find_child_node("FacingArrow") as Polygon2D


func _find_child_node(node_name: StringName) -> Node:
    # node-ref: allow - centralized fallback for shared enemy scenes with optional nodes
    var direct := get_node_or_null(NodePath(node_name))
    if direct != null:
        return direct
    # node-ref: allow - centralized fallback for shared enemy scenes with optional nodes
    return find_child(str(node_name), false, false)


func _resolve_guard_damage(angle: int, guard_damage_profile: int) -> int:
    if guard_damage_profile == Hitbox.GuardDamageProfile.DASH:
        return DirectionResolver.dash_guard_damage(angle)
    return DirectionResolver.normal_guard_damage(angle)


func _get_blocked_hit_sfx(angle: int) -> SpatialAudioEvent:
    return damaged_sfx_event if angle == DirectionResolver.HitAngle.BACK else blocked_sfx_event


func _start_stagger_vfx() -> void:
    if _body != null:
        if _stagger_tween != null and is_instance_valid(_stagger_tween):
            _stagger_tween.kill()
        _stagger_tween = create_tween()
        _stagger_tween.tween_property(_body, "modulate", STAGGER_VFX_COLOR, 0.2)


func _after_setup_ready() -> void:
    pass


func _on_guard_broken_extra() -> void:
    pass


func _on_begin_death_extra() -> void:
    pass


func _reset_extra() -> void:
    pass
