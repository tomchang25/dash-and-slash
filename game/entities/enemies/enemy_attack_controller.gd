# enemy_attack_controller.gd
# Shared cell-based attack controller that owns cell snapshots, telegraph phases, and cleanup for tile attacks.
class_name EnemyAttackController
extends Node

const CARDINAL_DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var _grid: GridArena
var _telegraph: TileTelegraph
var _attack_cells: Array[Vector2i] = []
var _prepared := false


func setup(grid: GridArena, telegraph: TileTelegraph) -> void:
    _grid = grid
    _telegraph = telegraph
    if _telegraph != null:
        _telegraph.setup(grid)
    cancel()


## Computes attack cells for the given origin, facing, and attack data without side effects.
static func get_attack_cells(origin_cell: Vector2i, facing: Vector2, attack_data: EnemyAttackData, grid: GridArena = null) -> Array[Vector2i]:
    var facing_cell := Vector2i(int(facing.x), int(facing.y))
    if facing_cell == Vector2i.ZERO:
        return []

    match attack_data.cell_shape:
        EnemyAttackData.CellShape.LINE:
            return AttackCellShapes.line(origin_cell, facing_cell, attack_data.line_length, grid, true)
        EnemyAttackData.CellShape.WIDE:
            return AttackCellShapes.wide(origin_cell, facing_cell, attack_data.depth, attack_data.width, grid, true)
        EnemyAttackData.CellShape.SQUARE:
            return AttackCellShapes.square(origin_cell, attack_data.radius, grid, true)
        EnemyAttackData.CellShape.FULL_LINE:
            return _full_line_cells(origin_cell, facing_cell, grid)
    return []


## Computes the origin cells that could include target_cell in the attack footprint.
static func get_attack_origin_cells(target_cell: Vector2i, attack_data: EnemyAttackData, grid: GridArena = null) -> Array[Vector2i]:
    var origins: Array[Vector2i] = []
    if attack_data == null:
        return origins

    match attack_data.cell_shape:
        EnemyAttackData.CellShape.LINE:
            _append_line_origin_cells(origins, target_cell, attack_data.line_length, grid)
        EnemyAttackData.CellShape.WIDE:
            _append_wide_origin_cells(origins, target_cell, attack_data.depth, attack_data.width, grid)
        EnemyAttackData.CellShape.SQUARE:
            _append_square_origin_cells(origins, target_cell, attack_data.radius, grid)
        EnemyAttackData.CellShape.FULL_LINE:
            _append_line_origin_cells(origins, target_cell, _max_grid_axis_length(grid), grid)
    return origins


## Prepares the controller for an attack by computing and storing the committed tile footprint.
func prepare(origin_cell: Vector2i, facing: Vector2, attack_data: EnemyAttackData) -> bool:
    cancel()
    if _grid == null:
        return false

    _attack_cells = get_attack_cells(origin_cell, facing, attack_data, _grid)
    if _attack_cells.is_empty():
        return false

    _prepared = true
    return true


## Prepares the controller from a caller-computed footprint, used by attacks that trim their line before committing.
func prepare_cells(cells: Array[Vector2i]) -> bool:
    cancel()
    _attack_cells = cells.duplicate()
    _prepared = not _attack_cells.is_empty()
    return _prepared


func show_warning() -> void:
    if _prepared and _telegraph != null:
        _telegraph.show_warning(_attack_cells)


func show_charge() -> void:
    if _prepared and _telegraph != null:
        _telegraph.show_charge(_attack_cells)


func show_active() -> void:
    if _prepared and _telegraph != null:
        _telegraph.show_active(_attack_cells)


func begin_attack() -> void:
    if not _prepared:
        return
    if _telegraph != null:
        _telegraph.show_active(_attack_cells)


func end_attack() -> void:
    if _telegraph != null:
        _telegraph.clear()
    _attack_cells.clear()
    _prepared = false


func cancel() -> void:
    if _telegraph != null:
        _telegraph.clear()
    _attack_cells.clear()
    _prepared = false


func get_cells() -> Array[Vector2i]:
    return _attack_cells.duplicate()


func clear_cell(cell: Vector2i) -> void:
    if _telegraph != null:
        _telegraph.clear_cell(cell)


## Computes a full line from the cell adjacent to origin to the grid boundary in the facing direction.
static func _full_line_cells(origin_cell: Vector2i, facing_cell: Vector2i, grid: GridArena) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    var cell := origin_cell + facing_cell
    while grid != null and grid.is_in_bounds(cell) and grid.is_land(cell):
        cells.append(cell)
        cell += facing_cell
    return cells


static func _append_line_origin_cells(origins: Array[Vector2i], target_cell: Vector2i, length: int, grid: GridArena = null) -> void:
    if length <= 0:
        return
    for facing_cell: Vector2i in CARDINAL_DIRECTIONS:
        for distance in range(1, length + 1):
            _append_origin_cell(origins, target_cell - facing_cell * distance, grid)


static func _append_wide_origin_cells(
        origins: Array[Vector2i],
        target_cell: Vector2i,
        depth: int,
        width: int,
        grid: GridArena = null,
) -> void:
    if depth <= 0 or width <= 0:
        return
    for facing_cell: Vector2i in CARDINAL_DIRECTIONS:
        var right_cell := Vector2i(facing_cell.y, -facing_cell.x)
        var half_width := int(width / 2)
        for row in range(1, depth + 1):
            for offset in range(-half_width, width - half_width):
                _append_origin_cell(origins, target_cell - facing_cell * row - right_cell * offset, grid)


static func _append_square_origin_cells(origins: Array[Vector2i], target_cell: Vector2i, radius: int, grid: GridArena = null) -> void:
    if radius < 0:
        return
    for x_offset in range(-radius, radius + 1):
        for y_offset in range(-radius, radius + 1):
            _append_origin_cell(origins, target_cell - Vector2i(x_offset, y_offset), grid)


static func _append_origin_cell(origins: Array[Vector2i], origin_cell: Vector2i, grid: GridArena = null) -> void:
    if grid != null and not grid.is_in_bounds(origin_cell):
        return
    if origin_cell not in origins:
        origins.append(origin_cell)


static func _max_grid_axis_length(grid: GridArena) -> int:
    if grid == null:
        return 0
    return maxi(grid.grid_size.x, grid.grid_size.y)
