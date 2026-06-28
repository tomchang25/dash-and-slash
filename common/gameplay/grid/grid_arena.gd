@tool
# grid_arena.gd
# Gameplay authority for grid terrain, occupancy, reservations, and telegraph state.
class_name GridArena
extends Node2D

signal terrain_generated
signal terrain_cells_changed(cells: Array[Vector2i])
signal telegraphs_changed

enum TelegraphPhase { NONE, WARNING, CHARGE, ACTIVE, SPAWNING }
enum TerrainTile { SEA, LAND }

@export var grid_size := Vector2i(16, 16)
@export var starting_land_size := Vector2i(8, 8)
@export var tile_size: float = 128.0

var _terrain: Array[int] = []
var _occupants: Dictionary = { }
var _reservations: Dictionary = { }
var _telegraphs: Dictionary = { }
var _player_grid: Vector2i = Vector2i.ZERO
var _generated := false

# == Lifecycle ================================================================


func _ready() -> void:
    if not _generated:
        generate_grid()

# == Terrain Generation =======================================================


## Regenerates gameplay terrain with a centered starting LAND footprint.
func generate_grid() -> void:
    var total_cells := grid_size.x * grid_size.y
    if _terrain.size() != total_cells:
        _terrain.resize(total_cells)
    for i in total_cells:
        _terrain[i] = TerrainTile.SEA
    _generate_starting_land()
    _ensure_spawn_land()
    _generated = true
    terrain_generated.emit()


func _generate_starting_land() -> void:
    var offset := (grid_size - starting_land_size) / 2
    for x in starting_land_size.x:
        for y in starting_land_size.y:
            var cell := Vector2i(offset.x + x, offset.y + y)
            _terrain[_terrain_index(cell)] = TerrainTile.LAND


func _ensure_spawn_land() -> void:
    var center := grid_size / 2
    if is_in_bounds(center) and not is_land(center):
        _terrain[_terrain_index(center)] = TerrainTile.LAND

# == Terrain Queries ==========================================================


## Returns true when the cell is in bounds and generated as LAND.
func is_land(cell: Vector2i) -> bool:
    return is_in_bounds(cell) and _terrain[_terrain_index(cell)] == TerrainTile.LAND


## Returns true when the cell is outside LAND terrain.
func is_sea(cell: Vector2i) -> bool:
    return not is_land(cell)


## Returns true when enemy pathfinding may enter the cell.
func is_walkable(cell: Vector2i) -> bool:
    return is_land(cell)


## Returns true when an enemy may move between two adjacent cells without cutting SEA corners.
func can_move_between(from: Vector2i, to: Vector2i) -> bool:
    if not is_land(to):
        return false
    var delta := to - from
    if absi(delta.x) == 1 and absi(delta.y) == 1:
        if not is_land(from + Vector2i(delta.x, 0)):
            return false
        if not is_land(from + Vector2i(0, delta.y)):
            return false
    return true


## Returns all LAND cells in the generated grid.
func get_land_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for x in grid_size.x:
        for y in grid_size.y:
            var cell := Vector2i(x, y)
            if is_land(cell):
                cells.append(cell)
    return cells


## Returns in-bounds cells around a changed terrain cell that may need redraw.
func get_cell_and_neighbors(cell: Vector2i) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for ox in range(-1, 2):
        for oy in range(-1, 2):
            var neighbor := cell + Vector2i(ox, oy)
            if is_in_bounds(neighbor):
                cells.append(neighbor)
    return cells

# == Terrain Mutation =========================================================


## Creates LAND at the cell when it is inside grid bounds.
func set_land(cell: Vector2i) -> bool:
    if not is_in_bounds(cell):
        return false
    _terrain[_terrain_index(cell)] = TerrainTile.LAND
    terrain_cells_changed.emit(get_cell_and_neighbors(cell))
    return true


## Removes LAND from the cell when active gameplay state allows it.
func set_sea(cell: Vector2i) -> bool:
    if not can_remove_land(cell):
        return false
    _terrain[_terrain_index(cell)] = TerrainTile.SEA
    terrain_cells_changed.emit(get_cell_and_neighbors(cell))
    return true


## Returns true when LAND can be safely removed without invalidating current actors.
func can_remove_land(cell: Vector2i) -> bool:
    if not is_land(cell):
        return false
    if is_occupied(cell) or is_reserved(cell):
        return false
    if _player_grid == cell:
        return false
    return true

# == Coordinate Conversion ====================================================


func _top_left() -> Vector2:
    var total := Vector2(grid_size) * tile_size
    return global_position - total * 0.5


func world_to_grid(world: Vector2) -> Vector2i:
    var local := world - _top_left()
    return Vector2i(int(local.x / tile_size), int(local.y / tile_size))


func grid_to_world(cell: Vector2i) -> Vector2:
    return _top_left() + Vector2(cell) * tile_size + Vector2.ONE * tile_size * 0.5


func cell_center(cell: Vector2i) -> Vector2:
    return grid_to_world(cell)


## Returns true when the cell is inside the gameplay grid.
func is_in_bounds(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y

# == Occupancy ================================================================


func is_occupied(cell: Vector2i) -> bool:
    for tiles in _occupants.values():
        if cell in tiles:
            return true
    return false


func is_reserved(cell: Vector2i) -> bool:
    for cells in _reservations.values():
        if cell in cells:
            return true
    return false


func register_occupant(entity: Object, tiles: Array[Vector2i]) -> void:
    _occupants[entity] = tiles.duplicate()


func unregister_occupant(entity: Object) -> void:
    _occupants.erase(entity)
    _reservations.erase(entity)


func reserve_cell(entity: Object, cell: Vector2i) -> void:
    reserve_cells(entity, [cell])


func reserve_cells(entity: Object, cells: Array[Vector2i]) -> void:
    _reservations[entity] = cells.duplicate()


func clear_reservation(entity: Object) -> void:
    _reservations.erase(entity)


func is_blocked(cell: Vector2i) -> bool:
    return is_occupied(cell) or is_reserved(cell)


func is_empty(cell: Vector2i) -> bool:
    return not is_blocked(cell)


func get_occupants() -> Array:
    return _occupants.keys()


func set_player_cell(pos: Vector2) -> void:
    _player_grid = world_to_grid(pos)


func get_player_cell() -> Vector2i:
    return _player_grid


func nearest_empty_cell(near: Vector2) -> Vector2i:
    var center := world_to_grid(near)
    if is_walkable(center) and is_empty(center):
        return center
    var best: Vector2i = Vector2i.ZERO
    var best_dist := 9999.0
    for x in grid_size.x:
        for y in grid_size.y:
            var c := Vector2i(x, y)
            if is_walkable(c) and is_empty(c):
                var d := Vector2(c).distance_squared_to(Vector2(center))
                if d < best_dist:
                    best_dist = d
                    best = c
    return best

# == Telegraph =================================================================


func set_telegraph(source: Object, tiles: Array[Vector2i], phase: TelegraphPhase) -> void:
    for t in tiles:
        var sources: Dictionary = _telegraphs.get(t, { })
        sources[source] = phase
        _telegraphs[t] = sources
    telegraphs_changed.emit()


func clear_telegraph(source: Object, tiles: Array[Vector2i]) -> void:
    for t in tiles:
        if not _telegraphs.has(t):
            continue
        var sources: Dictionary = _telegraphs[t]
        sources.erase(source)
        if sources.is_empty():
            _telegraphs.erase(t)
    telegraphs_changed.emit()


func clear_all_telegraphs() -> void:
    _telegraphs.clear()
    telegraphs_changed.emit()


## Returns the highest telegraph phase currently applied to a cell.
func get_telegraph_phase(cell: Vector2i) -> int:
    if not _telegraphs.has(cell):
        return TelegraphPhase.NONE
    var sources: Dictionary = _telegraphs[cell]
    return _resolve_highest_phase(sources)


## Returns every cell with at least one active telegraph source.
func get_telegraphed_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for cell: Vector2i in _telegraphs.keys():
        cells.append(cell)
    return cells

# == Terrain Helpers ==========================================================


func _terrain_index(cell: Vector2i) -> int:
    return cell.y * grid_size.x + cell.x


func _resolve_highest_phase(sources: Dictionary) -> int:
    var best := int(TelegraphPhase.NONE)
    for phase: int in sources.values():
        if phase > best:
            best = phase
    return best
