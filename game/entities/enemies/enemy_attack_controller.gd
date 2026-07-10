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
    if attack_data == null:
        return []

    var facing_cell := Vector2i(int(facing.x), int(facing.y))
    if facing_cell == Vector2i.ZERO:
        return []

    if attack_data.cell_shape == EnemyAttackData.CellShape.FULL_LINE:
        return _full_line_cells(origin_cell, facing_cell, grid)

    return AttackCellShapes.cells_from_local_offsets(
        origin_cell,
        facing_cell,
        AttackCellShapes.local_offsets_for(attack_data),
        grid,
        true,
    )


## Computes the origin cells that could include target_cell in the attack footprint.
static func get_attack_origin_cells(target_cell: Vector2i, attack_data: EnemyAttackData, grid: GridArena = null) -> Array[Vector2i]:
    var origins: Array[Vector2i] = []
    if attack_data == null:
        return origins

    var local_offsets: Array[Vector2i] = []
    if attack_data.cell_shape == EnemyAttackData.CellShape.FULL_LINE:
        local_offsets = AttackCellShapes.line_offsets(_max_grid_axis_length(grid))
    else:
        local_offsets = AttackCellShapes.local_offsets_for(attack_data)

    _append_offset_origin_cells(origins, target_cell, local_offsets, grid)
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
    if grid == null:
        return cells

    var distance := 1
    while true:
        var cell := AttackCellShapes.local_offset_to_cell(origin_cell, facing_cell, Vector2i(distance, 0))
        if not grid.is_in_bounds(cell) or not grid.is_land(cell):
            break
        cells.append(cell)
        distance += 1
    return cells


## Appends every in-bounds origin that can place target_cell at one local footprint offset.
static func _append_offset_origin_cells(
        origins: Array[Vector2i],
        target_cell: Vector2i,
        local_offsets: Array[Vector2i],
        grid: GridArena = null,
) -> void:
    if local_offsets.is_empty():
        return

    for facing_cell: Vector2i in CARDINAL_DIRECTIONS:
        for local_offset: Vector2i in local_offsets:
            var offset_cell := AttackCellShapes.local_offset_to_cell(Vector2i.ZERO, facing_cell, local_offset)
            _append_origin_cell(origins, target_cell - offset_cell, grid)


static func _append_origin_cell(origins: Array[Vector2i], origin_cell: Vector2i, grid: GridArena = null) -> void:
    if grid != null and not grid.is_in_bounds(origin_cell):
        return
    if origin_cell not in origins:
        origins.append(origin_cell)


static func _max_grid_axis_length(grid: GridArena) -> int:
    if grid == null:
        return 0
    return maxi(grid.grid_size.x, grid.grid_size.y)
