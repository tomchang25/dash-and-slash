@tool
# grid_arena.gd
# Gameplay authority for grid terrain, occupancy, reservations, and telegraph state.
class_name GridArena
extends Node2D

signal terrain_generated
signal terrain_cells_changed(cells: Array[Vector2i])
signal telegraphs_changed
signal reservation_lost(entity: Object)

enum TelegraphPhase { NONE, WARNING, CHARGE, ACTIVE, SPAWNING }
enum TerrainTile { SEA, LAND }

const ORTHOGONAL_DIRECTIONS: Array[Vector2i] = [
    Vector2i.RIGHT,
    Vector2i.LEFT,
    Vector2i.DOWN,
    Vector2i.UP,
]

@export var grid_size := Vector2i(16, 16)
@export var starting_land_size := Vector2i(8, 8)
@export var tile_size: float = 128.0

var _terrain: Array[int] = []
var _occupants: Dictionary = { }
var _reservations: Dictionary = { }
var _reservation_owners: Dictionary = { }
var _telegraphs: Dictionary = { }
var _player_grid: Vector2i = Vector2i.ZERO
var _generated := false
var _registration_counter := 0
var _entity_registration_indices: Dictionary = { }

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


## Returns sea cells that can become LAND while staying attached to the current landmass.
func get_add_connected_land_candidates() -> Array[Vector2i]:
    var candidates: Array[Vector2i] = []
    for land_cell in get_land_cells():
        for direction: Vector2i in ORTHOGONAL_DIRECTIONS:
            var candidate: Vector2i = land_cell + direction
            if not is_in_bounds(candidate) or not is_sea(candidate) or candidate in candidates:
                continue
            candidates.append(candidate)
    return candidates


## Returns LAND cells that can be removed without invalidating actors or splitting land.
func get_remove_safe_connected_land_candidates() -> Array[Vector2i]:
    var candidates: Array[Vector2i] = []
    for cell in get_land_cells():
        if can_remove_connected_land(cell):
            candidates.append(cell)
    return candidates


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


## Creates LAND at a random connected candidate cell.
func add_random_connected_land(rng: RandomNumberGenerator = null) -> bool:
    var candidates := get_add_connected_land_candidates()
    if candidates.is_empty():
        return false
    var resolved_rng := _resolve_rng(rng)
    return set_land(candidates[resolved_rng.randi_range(0, candidates.size() - 1)])


## Adds one connected LAND cell and removes one old safe LAND cell.
func move_random_safe_land(rng: RandomNumberGenerator = null) -> bool:
    var add_candidates := get_add_connected_land_candidates()
    var remove_candidates := get_remove_safe_connected_land_candidates()
    if add_candidates.is_empty() or remove_candidates.is_empty():
        return false
    var resolved_rng := _resolve_rng(rng)
    var added_cell: Vector2i = add_candidates[resolved_rng.randi_range(0, add_candidates.size() - 1)]
    if not set_land(added_cell):
        return false
    remove_candidates.erase(added_cell)
    if remove_candidates.is_empty():
        return true
    return set_sea(remove_candidates[resolved_rng.randi_range(0, remove_candidates.size() - 1)])


## Removes LAND from a random safe cell while keeping the remaining land connected.
func remove_random_safe_connected_land(rng: RandomNumberGenerator = null) -> bool:
    var candidates := get_remove_safe_connected_land_candidates()
    if candidates.is_empty():
        return false
    var resolved_rng := _resolve_rng(rng)
    return set_sea(candidates[resolved_rng.randi_range(0, candidates.size() - 1)])


## Returns true when LAND can be safely removed without invalidating current actors.
func can_remove_land(cell: Vector2i) -> bool:
    if not is_land(cell):
        return false
    if is_occupied(cell) or is_reserved(cell):
        return false
    if _player_grid == cell:
        return false
    return true


## Returns true when LAND can be removed and the remaining landmass stays connected.
func can_remove_connected_land(cell: Vector2i) -> bool:
    return can_remove_land(cell) and _would_land_remain_connected_without(cell)

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
    return _reservation_owners.has(cell)


## Returns true when the cell is reserved by the given entity.
func is_reserved_by(cell: Vector2i, entity: Object) -> bool:
    return _reservation_owners.get(cell) == entity


func register_occupant(entity: Object, tiles: Array[Vector2i]) -> void:
    _occupants[entity] = tiles.duplicate()
    if not _entity_registration_indices.has(entity):
        _entity_registration_indices[entity] = _registration_counter
        _registration_counter += 1


func unregister_occupant(entity: Object) -> void:
    _occupants.erase(entity)
    _remove_entity_reservation(entity)
    _entity_registration_indices.erase(entity)


func reserve_cell(entity: Object, cell: Vector2i, is_attack := false) -> bool:
    return reserve_cells(entity, [cell], is_attack)


## Returns true when the entity would own the cell after reservation arbitration.
func can_reserve_cell(entity: Object, cell: Vector2i, is_attack := false) -> bool:
    return can_reserve_cells(entity, [cell], is_attack)


## Requests a reservation for the given cells. On conflict, compares priority:
## active movement step > attack intent > closer to player > earlier registration index.
## Returns true when the caller still owns all requested cells after arbitration.
func reserve_cells(entity: Object, cells: Array[Vector2i], is_attack := false) -> bool:
    var active_cells: Array[Vector2i] = []
    return _request_reservation_impl(entity, cells, is_attack, active_cells)


## Requests a reservation while marking cells already being actively moved into.
func reserve_cells_with_active_steps(entity: Object, cells: Array[Vector2i], is_attack: bool, active_cells: Array[Vector2i]) -> bool:
    return _request_reservation_impl(entity, cells, is_attack, active_cells)


## Returns true when the entity would win conflicts for all cells without changing reservations.
func can_reserve_cells(entity: Object, cells: Array[Vector2i], is_attack := false) -> bool:
    var active_cells: Array[Vector2i] = []
    for cell in cells:
        var cell_owner: Object = _reservation_owners.get(cell)
        if cell_owner == null or cell_owner == entity:
            continue
        if not _can_take_reserved_cell(entity, is_attack, active_cells, cell_owner, cell):
            return false
    return true


## Registers an enemy entity for deterministic priority ordering.
## Returns the assigned registration index.
func register_enemy_entity(entity: Object) -> int:
    if _entity_registration_indices.has(entity):
        return _entity_registration_indices[entity]
    var idx := _registration_counter
    _registration_counter += 1
    _entity_registration_indices[entity] = idx
    return idx


## Returns the entity's registration index, or -1 if unregistered.
func get_registration_index(entity: Object) -> int:
    return _entity_registration_indices.get(entity, -1)


func clear_reservation(entity: Object) -> void:
    _remove_entity_reservation(entity)


func _remove_entity_reservation(entity: Object) -> void:
    var data = _reservations.get(entity)
    if data == null:
        return
    for cell in data["cells"]:
        if _reservation_owners.get(cell) == entity:
            _reservation_owners.erase(cell)
    _reservations.erase(entity)


func _request_reservation_impl(entity: Object, cells: Array[Vector2i], is_attack: bool, active_cells: Array[Vector2i]) -> bool:
    # Remove this entity's old reservation first
    _remove_entity_reservation(entity)

    if cells.is_empty():
        return true

    # Collect entities that currently own any of the requested cells
    var losers: Array[Object] = []
    for cell in cells:
        var cell_owner: Object = _reservation_owners.get(cell)
        if cell_owner != null and cell_owner != entity and not cell_owner in losers:
            losers.append(cell_owner)

    # Verify this entity wins for every conflicting cell.
    for cell in cells:
        var cell_owner: Object = _reservation_owners.get(cell)
        if cell_owner == null or cell_owner == entity:
            continue
        if not _can_take_reserved_cell(entity, is_attack, active_cells, cell_owner, cell):
            return false

    # Remove losing reservations and notify
    for other in losers:
        _remove_entity_reservation(other)
        reservation_lost.emit(other)

    # Place the new reservation
    _reservations[entity] = {
        "cells": cells.duplicate(),
        "active_cells": active_cells.duplicate(),
        "is_attack": is_attack,
    }
    for cell in cells:
        _reservation_owners[cell] = entity

    return true


func _can_take_reserved_cell(
        entity: Object,
        is_attack: bool,
        active_cells: Array[Vector2i],
        other: Object,
        cell: Vector2i,
) -> bool:
    if _reservation_has_active_cell(other, cell):
        return false
    if cell in active_cells:
        return true
    return _is_higher_priority(entity, is_attack, other)


func _reservation_has_active_cell(entity: Object, cell: Vector2i) -> bool:
    var data = _reservations.get(entity)
    if data == null:
        return false
    var active_cells: Array[Vector2i] = data.get("active_cells", [])
    return cell in active_cells


func _is_higher_priority(entity: Object, is_attack: bool, other: Object) -> bool:
    var other_data = _reservations.get(other)
    if other_data == null:
        return true

    var other_is_attack: bool = other_data["is_attack"]

    # Attack intent beats ordinary movement
    if is_attack and not other_is_attack:
        return true
    if not is_attack and other_is_attack:
        return false

    # Same attack intent level: closer to player wins
    var entity_dist := _get_entity_distance_to_player(entity)
    var other_dist := _get_entity_distance_to_player(other)
    if entity_dist != other_dist:
        return entity_dist < other_dist

    # Same distance: earlier registration index wins
    var entity_idx := get_registration_index(entity)
    var other_idx := get_registration_index(other)
    return entity_idx < other_idx


func _get_entity_distance_to_player(entity: Object) -> int:
    var tiles: Array[Vector2i] = _occupants.get(entity, [])
    if tiles.is_empty():
        return 9999
    var pos := tiles[0]
    return absi(pos.x - _player_grid.x) + absi(pos.y - _player_grid.y)


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


## Clears telegraph ownership for a source, including stale freed-object keys held during scene reset cleanup.
func clear_telegraph(source: Variant, tiles: Array[Vector2i]) -> void:
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


func _would_land_remain_connected_without(removed_cell: Vector2i) -> bool:
    var remaining_land := get_land_cells()
    remaining_land.erase(removed_cell)
    if remaining_land.size() <= 1:
        return true

    var visited: Dictionary = { }
    var frontier: Array[Vector2i] = [remaining_land[0]]
    visited[remaining_land[0]] = true

    while not frontier.is_empty():
        var current: Vector2i = frontier.pop_front()
        for direction: Vector2i in ORTHOGONAL_DIRECTIONS:
            var neighbor: Vector2i = current + direction
            if neighbor == removed_cell or visited.has(neighbor) or not is_land(neighbor):
                continue
            visited[neighbor] = true
            frontier.append(neighbor)

    return visited.size() == remaining_land.size()


func _resolve_rng(rng: RandomNumberGenerator = null) -> RandomNumberGenerator:
    if rng != null:
        return rng
    var fallback := RandomNumberGenerator.new()
    fallback.randomize()
    return fallback


func _resolve_highest_phase(sources: Dictionary) -> int:
    var best := int(TelegraphPhase.NONE)
    for phase: int in sources.values():
        if phase > best:
            best = phase
    return best
