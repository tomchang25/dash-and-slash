# mode_enemy.gd
# 1x1 special enemy that randomly changes between tile, puff, and charge modes.
class_name ModeEnemy
extends GridEnemy

signal guard_changed(current: int, maximum: int)
signal guard_stagger_started
signal guard_stagger_ended

const MODE_CHANGE_DURATION := 3.0
const MODE_PREVIEW_INTERVAL := 0.25
const TELEGRAPH_DURATION := 0.8
const CHARGE_DURATION := 0.2
const TILE_ATTACK_DURATION := 0.25
const PUFF_ATTACK_DURATION := 1.0
const CHARGE_ATTACK_TIMEOUT := 1.2
const RECOVERY_DURATION := 0.8
const CHARGING_SPEED := 480.0
const TILE_MODE_COLOR := Color(0.9, 0.35, 0.25, 1.0)
const PUFF_MODE_COLOR := Color(0.95, 0.8, 0.2, 1.0)
const CHARGE_MODE_COLOR := Color(0.35, 0.6, 1.0, 1.0)

# -- Exports ------------------------------------------------------------------
@export var attack_sfx_event: SpatialAudioEvent

# -- State --------------------------------------------------------------------
var _mode: int = ModeEnemyAttackController.Mode.TILE
var _mode_ready := false
var _charge_cells: Array[Vector2i] = []
var _charge_index := 0

# -- Node references ----------------------------------------------------------
@onready var _attack_controller: ModeEnemyAttackController = %AttackController
@onready var _telegraph: TileTelegraph = %TileTelegraph
@onready var _tile_hitbox: Hitbox = %TileAttackHitbox
@onready var _contact_hitbox: Hitbox = %ContactHitbox
@onready var _puff_hitbox: Hitbox = %PuffHitbox

# == Lifecycle ================================================================


func _ready() -> void:
    super()
    _allow_diagonal_movement = true
    _configure_attack_controller()
    _disable_mode_hitboxes()
    _apply_current_mode_color()

# == Overridden Custom Methods ================================================


func start_cooldown() -> void:
    super()
    _mode_ready = false

# == Signal handlers ==========================================================


func _on_guard_changed(current: int, maximum: int) -> void:
    super(current, maximum)
    guard_changed.emit(current, maximum)


func _on_stagger_started() -> void:
    super()
    guard_stagger_started.emit()


func _on_stagger_ended() -> void:
    super()
    guard_stagger_ended.emit()

# == Common API ================================================================


func emit_guard_snapshot() -> void:
    if _guard != null:
        guard_changed.emit(_guard.current(), _guard.max_guard)


func get_idle_state_id() -> int:
    return ModeEnemyState.ModeEnemyStateId.IDLE


func get_reposition_state_id() -> int:
    return ModeEnemyState.ModeEnemyStateId.REPOSITION


func get_face_state_id() -> int:
    return ModeEnemyState.ModeEnemyStateId.FACE_TARGET


func get_recovery_state_id() -> int:
    return ModeEnemyState.ModeEnemyStateId.RECOVERY


func get_staggered_state_id() -> int:
    return ModeEnemyState.ModeEnemyStateId.STAGGERED


func get_dead_state_id() -> int:
    return ModeEnemyState.ModeEnemyStateId.DEAD


func get_pre_plan_state_id() -> int:
    if not _mode_ready:
        return ModeEnemyState.ModeEnemyStateId.MODE_CHANGE
    if can_attack_current_mode():
        return ModeEnemyState.ModeEnemyStateId.TELEGRAPH
    return -1


func get_arrival_override_state_id() -> int:
    if can_attack_current_mode():
        return ModeEnemyState.ModeEnemyStateId.TELEGRAPH
    return -1


func get_after_face_state_id() -> int:
    if can_attack_current_mode():
        return ModeEnemyState.ModeEnemyStateId.TELEGRAPH
    return ModeEnemyState.ModeEnemyStateId.IDLE


func get_recovery_duration() -> float:
    return RECOVERY_DURATION


func get_attack_duration() -> float:
    match _mode:
        ModeEnemyAttackController.Mode.PUFF:
            return PUFF_ATTACK_DURATION
        ModeEnemyAttackController.Mode.CHARGE:
            return CHARGE_ATTACK_TIMEOUT
    return TILE_ATTACK_DURATION


func get_mode_preview_interval() -> float:
    return MODE_PREVIEW_INTERVAL


func get_current_mode() -> int:
    return _mode


func choose_random_mode() -> void:
    _mode = randi() % ModeEnemyAttackController.MODE_COUNT
    _mode_ready = true
    if _attack_controller != null:
        _attack_controller.set_mode(_mode)
        if _mode == ModeEnemyAttackController.Mode.TILE:
            _attack_controller.randomize_tile_shape()
    _apply_current_mode_color()


func set_preview_mode(mode: int) -> void:
    if _body != null:
        _body.color = get_mode_color(mode)


func apply_current_mode_color() -> void:
    _apply_current_mode_color()


func get_mode_color(mode: int) -> Color:
    match mode:
        ModeEnemyAttackController.Mode.PUFF:
            return PUFF_MODE_COLOR
        ModeEnemyAttackController.Mode.CHARGE:
            return CHARGE_MODE_COLOR
    return TILE_MODE_COLOR


func can_attack_current_mode() -> bool:
    if _grid == null or _attack_controller == null or not has_target() or not _mode_ready:
        return false
    match _mode:
        ModeEnemyAttackController.Mode.CHARGE:
            return is_player_in_same_line()
        ModeEnemyAttackController.Mode.PUFF:
            return is_target_in_puff_range()
        ModeEnemyAttackController.Mode.TILE:
            var target_cell := _grid.world_to_grid(_target.global_position)
            var dir_to_target := Vector2(target_cell - _grid_pos)
            if dir_to_target == Vector2.ZERO:
                return false
            return target_cell in _attack_controller.get_attack_cells(_grid_pos, cardinal_snap(dir_to_target))
    return false


func is_player_in_same_line() -> bool:
    if _grid == null or not has_target():
        return false
    var player_cell := _grid.world_to_grid(_target.global_position)
    return _grid_pos.x == player_cell.x or _grid_pos.y == player_cell.y


func is_target_in_puff_range() -> bool:
    if _grid == null or not has_target():
        return false
    var player_cell := _grid.world_to_grid(_target.global_position)
    var diff := player_cell - _grid_pos
    return absi(diff.x) <= 1 and absi(diff.y) <= 1


func plan_next_action() -> bool:
    match _mode:
        ModeEnemyAttackController.Mode.CHARGE:
            return _plan_charge_action()
        ModeEnemyAttackController.Mode.TILE:
            return _plan_tile_action()
    return super()


func prepare_attack() -> bool:
    if _attack_controller == null:
        return false
    return _attack_controller.prepare(_grid_pos, _facing)


func show_attack_warning() -> void:
    if _attack_controller != null:
        _attack_controller.show_warning()


func show_attack_charge() -> void:
    if _attack_controller != null:
        _attack_controller.show_charge()


func begin_attack() -> void:
    velocity = Vector2.ZERO
    _charge_cells.clear()
    _charge_index = 0
    if _attack_controller == null:
        return
    if attack_sfx_event != null:
        AudioManager.play_event(attack_sfx_event, global_position)

    _attack_controller.begin_attack()
    if _mode == ModeEnemyAttackController.Mode.CHARGE:
        _charge_cells = _attack_controller.get_cells()
        if not _charge_cells.is_empty():
            _move_to_charge_cell(_charge_cells[0])


func update_attack_motion(_delta: float) -> bool:
    if _mode != ModeEnemyAttackController.Mode.CHARGE:
        return false
    if _charge_index >= _charge_cells.size():
        return true

    var target_cell := _charge_cells[_charge_index]
    var target_world := _grid.cell_center(target_cell)
    var arrival_threshold := tile_size() * 0.1
    if global_position.distance_squared_to(target_world) >= arrival_threshold * arrival_threshold:
        return false

    _grid_pos = target_cell
    global_position = target_world
    register_grid_occupant()
    if _attack_controller != null:
        _attack_controller.clear_cell(target_cell)

    _charge_index += 1
    if _charge_index >= _charge_cells.size():
        velocity = Vector2.ZERO
        return true

    _move_to_charge_cell(_charge_cells[_charge_index])
    return false


func end_attack() -> void:
    velocity = Vector2.ZERO
    _charge_cells.clear()
    _charge_index = 0
    if _attack_controller != null:
        _attack_controller.end_attack()


func cancel_attack() -> void:
    velocity = Vector2.ZERO
    _charge_cells.clear()
    _charge_index = 0
    if _attack_controller != null:
        _attack_controller.cancel()

# == Setup helpers =============================================================


func _after_setup_ready() -> void:
    _configure_attack_controller()


func _on_guard_broken_extra() -> void:
    cancel_attack()


func _on_begin_death_extra() -> void:
    cancel_attack()
    _disable_mode_hitboxes()


func _reset_extra() -> void:
    _mode_ready = false
    _charge_cells.clear()
    _charge_index = 0
    cancel_attack()
    _apply_current_mode_color()


func _configure_attack_controller() -> void:
    if _attack_controller == null:
        return
    _attack_controller.setup(_grid, _telegraph, _tile_hitbox, _contact_hitbox, _puff_hitbox)


func _disable_mode_hitboxes() -> void:
    if _tile_hitbox != null:
        _tile_hitbox.set_enabled(false)
    if _contact_hitbox != null:
        _contact_hitbox.set_enabled(false)
    if _puff_hitbox != null:
        _puff_hitbox.set_enabled(false)


func _apply_current_mode_color() -> void:
    if _body != null:
        _body.color = get_mode_color(_mode)


func _plan_tile_action() -> bool:
    clear_planned_action()
    if _grid == null or _attack_controller == null or not has_target():
        return false

    var start := _grid_pos
    var target_cell := _grid.world_to_grid(_target.global_position)
    var attack_origins: Array[Vector2i] = []
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

    var path := _find_path_to_cell(start, target_cell, attack_origins)
    if path.is_empty():
        return false

    _planned_path = path
    _refresh_planned_reservations()
    queue_redraw()
    return true


func _plan_charge_action() -> bool:
    clear_planned_action()
    if _grid == null or not has_target():
        return false

    var start := _grid_pos
    var target_cell := _grid.world_to_grid(_target.global_position)
    if not _grid.is_in_bounds(target_cell):
        return false
    if start == target_cell:
        queue_redraw()
        return true

    var path: Array[Vector2i] = []
    var line_goals := _collect_charge_line_goal_cells(target_cell, start)
    if not line_goals.is_empty():
        if start in line_goals:
            queue_redraw()
            return true
        path = _find_path_to_cell(start, NO_BLOCKED_CELL, line_goals)

    if path.is_empty() and not _grid.is_blocked(target_cell):
        path = _find_path_to_cell(start, NO_BLOCKED_CELL, [target_cell])

    if path.is_empty():
        var fallback_goals := _collect_adjacent_goal_cells(target_cell, start)
        if fallback_goals.is_empty():
            return false
        if start in fallback_goals:
            queue_redraw()
            return true
        path = _find_path_to_cell(start, target_cell, fallback_goals)

    if path.is_empty():
        return false

    _planned_path = path
    _refresh_planned_reservations()
    queue_redraw()
    return true


func _collect_charge_line_goal_cells(target_cell: Vector2i, start: Vector2i) -> Array[Vector2i]:
    var goals: Array[Vector2i] = []
    for x in range(_grid.GRID_SIZE.x):
        var cell := Vector2i(x, target_cell.y)
        if cell == target_cell:
            continue
        if cell == start or not _grid.is_blocked(cell):
            goals.append(cell)
    for y in range(_grid.GRID_SIZE.y):
        var cell := Vector2i(target_cell.x, y)
        if cell == target_cell:
            continue
        if cell in goals:
            continue
        if cell == start or not _grid.is_blocked(cell):
            goals.append(cell)
    return goals


func _move_to_charge_cell(cell: Vector2i) -> void:
    if _grid == null:
        velocity = Vector2.ZERO
        return
    var target_world := _grid.cell_center(cell)
    var direction := (target_world - global_position).normalized()
    velocity = direction * CHARGING_SPEED
