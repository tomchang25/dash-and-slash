# attack_cell_shapes.gd
# Shared attack footprint helpers for grid-based enemies.
class_name AttackCellShapes
extends RefCounted

# == Common API ==

## Returns forward line cells, starting one cell in front of the origin.
static func line(origin_cell: Vector2i, facing_cell: Vector2i, length: int, grid: GridArena = null, require_grid: bool = false) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    if facing_cell == Vector2i.ZERO or length <= 0:
        return cells

    for depth in range(1, length + 1):
        append_if_in_bounds(cells, origin_cell + facing_cell * depth, grid, require_grid)
    return cells


## Returns a centered forward rectangle, starting one cell in front of the origin.
static func wide(origin_cell: Vector2i, facing_cell: Vector2i, depth: int, width: int, grid: GridArena = null, require_grid: bool = false) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    if facing_cell == Vector2i.ZERO or depth <= 0 or width <= 0:
        return cells

    var right_cell := Vector2i(facing_cell.y, -facing_cell.x)
    var half_width := int(width / 2)
    for row in range(1, depth + 1):
        var center_cell := origin_cell + facing_cell * row
        for offset in range(-half_width, width - half_width):
            append_if_in_bounds(cells, center_cell + right_cell * offset, grid, require_grid)
    return cells


## Returns a square footprint centered on the origin cell.
static func square(origin_cell: Vector2i, radius: int, grid: GridArena = null, require_grid: bool = false) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    if radius < 0:
        return cells

    for x_offset in range(-radius, radius + 1):
        for y_offset in range(-radius, radius + 1):
            append_if_in_bounds(cells, origin_cell + Vector2i(x_offset, y_offset), grid, require_grid)
    return cells


## Returns the ring of cells adjacent to the origin cell, excluding the origin itself.
static func adjacent_ring(origin_cell: Vector2i, radius: int, grid: GridArena = null, require_grid: bool = false) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    if radius < 0:
        return cells

    for x_offset in range(-radius, radius + 1):
        for y_offset in range(-radius, radius + 1):
            if x_offset == 0 and y_offset == 0:
                continue
            append_if_in_bounds(cells, origin_cell + Vector2i(x_offset, y_offset), grid, require_grid)
    return cells


## Appends a unique cell when it is in-bounds for the provided grid.
static func append_if_in_bounds(cells: Array[Vector2i], cell: Vector2i, grid: GridArena = null, require_grid: bool = false) -> void:
    if require_grid and grid == null:
        return
    if grid != null and not grid.is_in_bounds(cell):
        return
    if cell not in cells:
        cells.append(cell)
