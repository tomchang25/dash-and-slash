# attack_cell_shapes.gd
# Shared local-footprint generation and grid-cell transformation helpers for grid-based enemies.
class_name AttackCellShapes
extends RefCounted

# == Common API ==

## Normalizes an authored bounded shape into local offsets where x is forward and y is left.
static func local_offsets_for(attack_data: EnemyAttackData) -> Array[Vector2i]:
    match attack_data.cell_shape:
        EnemyAttackData.CellShape.LINE:
            return line_offsets(attack_data.line_length)
        EnemyAttackData.CellShape.WIDE:
            return wide_offsets(attack_data.depth, attack_data.width)
        EnemyAttackData.CellShape.SQUARE:
            return square_offsets(attack_data.radius)
        EnemyAttackData.CellShape.FULL_LINE:
            return []
        EnemyAttackData.CellShape.ADJACENT_RING:
            return adjacent_ring_offsets(attack_data.radius)
        EnemyAttackData.CellShape.CUSTOM_OFFSETS:
            return attack_data.cell_offsets.duplicate()
    return []


## Returns local offsets for a line starting one cell forward.
static func line_offsets(length: int) -> Array[Vector2i]:
    var offsets: Array[Vector2i] = []
    if length <= 0:
        return offsets

    for distance in range(1, length + 1):
        offsets.append(Vector2i(distance, 0))
    return offsets


## Returns local offsets for a centered forward rectangle.
static func wide_offsets(depth: int, width: int) -> Array[Vector2i]:
    var offsets: Array[Vector2i] = []
    if depth <= 0 or width <= 0:
        return offsets

    var half_width := int(width / 2)
    for row in range(1, depth + 1):
        for lateral_offset in range(-half_width, width - half_width):
            offsets.append(Vector2i(row, lateral_offset))
    return offsets


## Returns local offsets for a square centered on the origin.
static func square_offsets(radius: int) -> Array[Vector2i]:
    var offsets: Array[Vector2i] = []
    if radius < 0:
        return offsets

    for forward_offset in range(-radius, radius + 1):
        for lateral_offset in range(-radius, radius + 1):
            offsets.append(Vector2i(forward_offset, lateral_offset))
    return offsets


## Returns local offsets for the cells surrounding the origin, excluding the origin itself.
static func adjacent_ring_offsets(radius: int) -> Array[Vector2i]:
    var offsets: Array[Vector2i] = []
    if radius < 0:
        return offsets

    for forward_offset in range(-radius, radius + 1):
        for lateral_offset in range(-radius, radius + 1):
            if forward_offset == 0 and lateral_offset == 0:
                continue
            offsets.append(Vector2i(forward_offset, lateral_offset))
    return offsets


## Converts one local offset into a grid cell for the given origin and cardinal facing.
static func local_offset_to_cell(origin_cell: Vector2i, facing_cell: Vector2i, local_offset: Vector2i) -> Vector2i:
    var left_cell := Vector2i(facing_cell.y, -facing_cell.x)
    return origin_cell + facing_cell * local_offset.x + left_cell * local_offset.y


## Returns in-bounds grid cells for a bounded local-offset footprint.
static func cells_from_local_offsets(
        origin_cell: Vector2i,
        facing_cell: Vector2i,
        local_offsets: Array[Vector2i],
        grid: GridArena = null,
        require_grid: bool = false,
) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    if facing_cell == Vector2i.ZERO:
        return cells

    for local_offset: Vector2i in local_offsets:
        append_if_in_bounds(cells, local_offset_to_cell(origin_cell, facing_cell, local_offset), grid, require_grid)
    return cells


## Returns forward line cells, starting one cell in front of the origin.
static func line(origin_cell: Vector2i, facing_cell: Vector2i, length: int, grid: GridArena = null, require_grid: bool = false) -> Array[Vector2i]:
    return cells_from_local_offsets(origin_cell, facing_cell, line_offsets(length), grid, require_grid)


## Returns a centered forward rectangle, starting one cell in front of the origin.
static func wide(origin_cell: Vector2i, facing_cell: Vector2i, depth: int, width: int, grid: GridArena = null, require_grid: bool = false) -> Array[Vector2i]:
    return cells_from_local_offsets(origin_cell, facing_cell, wide_offsets(depth, width), grid, require_grid)


## Returns a square footprint centered on the origin cell.
static func square(origin_cell: Vector2i, radius: int, grid: GridArena = null, require_grid: bool = false) -> Array[Vector2i]:
    return cells_from_local_offsets(origin_cell, Vector2i.RIGHT, square_offsets(radius), grid, require_grid)


## Returns the ring of cells adjacent to the origin cell, excluding the origin itself.
static func adjacent_ring(origin_cell: Vector2i, radius: int, grid: GridArena = null, require_grid: bool = false) -> Array[Vector2i]:
    return cells_from_local_offsets(origin_cell, Vector2i.RIGHT, adjacent_ring_offsets(radius), grid, require_grid)


## Appends a unique cell when it is in-bounds for the provided grid.
static func append_if_in_bounds(cells: Array[Vector2i], cell: Vector2i, grid: GridArena = null, require_grid: bool = false) -> void:
    if require_grid and grid == null:
        return
    if grid != null and not grid.is_in_bounds(cell):
        return
    if cell not in cells:
        cells.append(cell)
