# enemy_attack_controller.gd
# Shared cell-based attack controller that owns cell snapshots, telegraph phases,
# hitbox setup, hitbox enablement, and cleanup for tile attacks.
class_name EnemyAttackController
extends Node

var _grid: GridArena
var _telegraph: TileTelegraph
var _tile_hitbox: Hitbox
var _contact_hitbox: Hitbox
var _puff_hitbox: Hitbox
var _attack_cells: Array[Vector2i] = []
var _tile_hitbox_position := Vector2.ZERO
var _prepared := false


func setup(grid: GridArena, telegraph: TileTelegraph, tile_hitbox: Hitbox, contact_hitbox: Hitbox, puff_hitbox: Hitbox) -> void:
    _grid = grid
    _telegraph = telegraph
    _tile_hitbox = tile_hitbox
    _contact_hitbox = contact_hitbox
    _puff_hitbox = puff_hitbox
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


## Prepares the controller for an attack. Computes cells, configures the tile hitbox geometry,
## and stores prepared state for subsequent telegraph/attack calls.
func prepare(origin_cell: Vector2i, facing: Vector2, attack_data: EnemyAttackData) -> bool:
    cancel()
    if _grid == null:
        return false

    _attack_cells = get_attack_cells(origin_cell, facing, attack_data, _grid)
    if _attack_cells.is_empty():
        return false

    _apply_tile_hitbox_geometry(attack_data.damage, attack_data.damage_interval)
    _prepared = true
    return true


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
    if _tile_hitbox != null:
        _tile_hitbox.global_position = _tile_hitbox_position
        _tile_hitbox.set_enabled(true)


func end_attack() -> void:
    if _tile_hitbox != null:
        _tile_hitbox.set_enabled(false)
    if _contact_hitbox != null:
        _contact_hitbox.set_enabled(false)
    if _puff_hitbox != null:
        _puff_hitbox.set_enabled(false)
    if _telegraph != null:
        _telegraph.clear()
    _attack_cells.clear()
    _prepared = false


func cancel() -> void:
    if _tile_hitbox != null:
        _tile_hitbox.set_enabled(false)
    if _contact_hitbox != null:
        _contact_hitbox.set_enabled(false)
    if _puff_hitbox != null:
        _puff_hitbox.set_enabled(false)
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
    while grid != null and grid.is_in_bounds(cell):
        cells.append(cell)
        cell += facing_cell
    return cells


## Computes a bounding RectangleShape2D from the attack cells and positions the tile hitbox.
func _apply_tile_hitbox_geometry(damage: float, damage_interval: float) -> void:
    if _grid == null or _tile_hitbox == null or _attack_cells.is_empty():
        return

    _tile_hitbox.damage = damage
    _tile_hitbox.damage_interval = damage_interval
    _tile_hitbox.guard_damage_profile = Hitbox.GuardDamageProfile.NORMAL

    var min_cell := _attack_cells[0]
    var max_cell := _attack_cells[0]
    for cell in _attack_cells:
        min_cell.x = mini(min_cell.x, cell.x)
        min_cell.y = mini(min_cell.y, cell.y)
        max_cell.x = maxi(max_cell.x, cell.x)
        max_cell.y = maxi(max_cell.y, cell.y)

    var cell_span := max_cell - min_cell + Vector2i.ONE
    var rect := RectangleShape2D.new()
    rect.size = Vector2(cell_span) * _grid.tile_size * 0.9
    _tile_hitbox.set_collision_shape(rect)
    _tile_hitbox_position = _grid.cell_center(min_cell)
    _tile_hitbox_position += Vector2(cell_span - Vector2i.ONE) * _grid.tile_size * 0.5
