# enemy_spawn_planner.gd
# Produces complete, anchor-aware spawn-cell plans for a group's placement strategy, and
# strategy-aware replacements when warning resolution finds a reserved cell invalid. Reads the
# player's logical grid cell through an injected zero-argument Callable instead of a concrete player
# type, so it works for any arena whose player cell is queryable that way (the tick arena passes a
# callable reading TickPlayer.cell). A plan either returns exactly as many distinct legal cells as
# requested or reports failure; callers must never fall back to an occupied or player cell during
# atomic admission.
class_name EnemySpawnPlanner
extends RefCounted

const NO_CELL := Vector2i(-1, -1)
const PLAYER_RING_MIN_DISTANCE := 2
const PLAYER_RING_MAX_DISTANCE := 4
const ANCHOR_CLUSTER_MIN_DISTANCE := 3
const ANCHOR_CLUSTER_MAX_DISTANCE := 5

var _grid: GridArena
var _player_cell_provider: Callable

# == Lifecycle ==


func _init(grid: GridArena = null, player_cell_provider: Callable = Callable()) -> void:
    _grid = grid
    _player_cell_provider = player_cell_provider

# == Common API ==


func setup(grid: GridArena, player_cell_provider: Callable) -> void:
    _grid = grid
    _player_cell_provider = player_cell_provider


## Plans exactly `count` distinct legal cells for one group's placement strategy, returning
## {"cells": Array[Vector2i], "anchor": Vector2i}. `cells` is empty when no complete legal plan
## exists; callers must treat that as total failure rather than accepting a partial plan. `anchor`
## is the strategy's reference point (the player cell for PLAYER_RING, the chosen cluster center for
## ANCHOR_CLUSTER, or NO_CELL for SCATTER) and must be retained for later replacement calls so a
## requeued member can be replaced using the same anchor intent.
func plan_group_cells(strategy: SpawnGroupDefinition.PlacementStrategy, count: int) -> Dictionary:
    if count <= 0:
        return _plan_result([], NO_CELL)
    match strategy:
        SpawnGroupDefinition.PlacementStrategy.PLAYER_RING:
            return _plan_player_ring(count)
        SpawnGroupDefinition.PlacementStrategy.ANCHOR_CLUSTER:
            return _plan_anchor_cluster(count)
        SpawnGroupDefinition.PlacementStrategy.SCATTER:
            return _plan_scatter(count)
        _:
            ToastManager.show_dev_error("EnemySpawnPlanner: unknown placement_strategy %s" % strategy)
            return _plan_result([], NO_CELL)


## Returns true when a warning-resolved cell is still a legal spawn target. Unlike
## plan_group_cells(), this never falls back to an occupied cell, so a true result can be trusted to
## mean "safe to spawn here" rather than "least-bad choice."
func is_spawn_cell_still_valid(cell: Vector2i, excluded_cells: Array[Vector2i]) -> bool:
    return _is_legal_cell(cell, _player_cell(), excluded_cells)


## Finds a genuinely valid replacement cell for a warning-resolution entry whose reserved cell
## failed revalidation: first a cell matching the entry's stored strategy/anchor intent, then any
## legal cell. Returns NO_CELL when neither exists instead of masking that as a placement.
func find_replacement_cell(strategy: SpawnGroupDefinition.PlacementStrategy, anchor: Vector2i, excluded_cells: Array[Vector2i]) -> Vector2i:
    var replacement := _find_strategy_replacement(strategy, anchor, excluded_cells)
    if replacement != NO_CELL:
        return replacement
    return _find_any_legal_cell(excluded_cells)


## Best-effort single spawn cell for the Debug-gated Wave 1 boss convenience spawn, which sits
## outside the normal group-slot flow and must never fail to find somewhere to place its one enemy.
## Falls back through an occupied-but-walkable cell and finally the player's own cell.
func choose_fallback_cell() -> Vector2i:
    var plan := plan_group_cells(SpawnGroupDefinition.PlacementStrategy.SCATTER, 1)
    var cells: Array = plan.get("cells", [])
    if not cells.is_empty():
        return cells[0]
    var any_legal_cell := _find_any_legal_cell([])
    if any_legal_cell != NO_CELL:
        return any_legal_cell
    var walkable_cell := _choose_any_walkable_cell()
    return walkable_cell if walkable_cell != NO_CELL else _player_cell()

# == Placement strategies ==


## Rings the player at Manhattan distance 2-4, preferring angular separation between chosen cells so
## a multi-member batch doesn't cluster on one side of the player.
func _plan_player_ring(count: int) -> Dictionary:
    var player_cell := _player_cell()
    var candidates := _cells_in_band(player_cell, PLAYER_RING_MIN_DISTANCE, PLAYER_RING_MAX_DISTANCE, [])
    if candidates.size() < count:
        return _plan_result([], NO_CELL)
    return _plan_result(_select_angularly_spread_cells(candidates, count, player_cell), player_cell)


## Picks one legal anchor at Manhattan distance 3-5 from the player, then fills with the nearest
## legal cells to that anchor across the whole grid.
func _plan_anchor_cluster(count: int) -> Dictionary:
    var player_cell := _player_cell()
    var anchor_candidates := _cells_in_band(player_cell, ANCHOR_CLUSTER_MIN_DISTANCE, ANCHOR_CLUSTER_MAX_DISTANCE, [])
    if anchor_candidates.is_empty():
        return _plan_result([], NO_CELL)
    anchor_candidates.shuffle()
    var anchor: Vector2i = anchor_candidates[0]

    var legal_cells := _legal_cells([])
    if legal_cells.size() < count:
        return _plan_result([], NO_CELL)
    legal_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _manhattan_distance(anchor, a) < _manhattan_distance(anchor, b))
    return _plan_result(legal_cells.slice(0, count), anchor)


## Scatters independent legal cells anywhere on LAND, with no shared anchor.
func _plan_scatter(count: int) -> Dictionary:
    var candidates := _legal_cells([])
    if candidates.size() < count:
        return _plan_result([], NO_CELL)
    candidates.shuffle()
    return _plan_result(candidates.slice(0, count), NO_CELL)


func _plan_result(cells: Array[Vector2i], anchor: Vector2i) -> Dictionary:
    return { "cells": cells, "anchor": anchor }

# == Replacement ==


func _find_strategy_replacement(strategy: SpawnGroupDefinition.PlacementStrategy, anchor: Vector2i, excluded_cells: Array[Vector2i]) -> Vector2i:
    match strategy:
        SpawnGroupDefinition.PlacementStrategy.PLAYER_RING:
            var candidates := _cells_in_band(_player_cell(), PLAYER_RING_MIN_DISTANCE, PLAYER_RING_MAX_DISTANCE, excluded_cells)
            return _pick_random(candidates)
        SpawnGroupDefinition.PlacementStrategy.ANCHOR_CLUSTER:
            if anchor == NO_CELL:
                return NO_CELL
            var candidates := _legal_cells(excluded_cells)
            if candidates.is_empty():
                return NO_CELL
            candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _manhattan_distance(anchor, a) < _manhattan_distance(anchor, b))
            return candidates[0]
        SpawnGroupDefinition.PlacementStrategy.SCATTER:
            return _find_any_legal_cell(excluded_cells)
        _:
            return NO_CELL


func _find_any_legal_cell(excluded_cells: Array[Vector2i]) -> Vector2i:
    return _pick_random(_legal_cells(excluded_cells))


func _pick_random(candidates: Array[Vector2i]) -> Vector2i:
    if candidates.is_empty():
        return NO_CELL
    candidates.shuffle()
    return candidates[0]

# == Candidate collection ==


## Collects every currently legal LAND cell: not the player's cell, not occupied or reserved, not
## already claimed by excluded_cells (either duplicates within the same plan or cells reserved by
## other in-flight entries).
func _legal_cells(excluded_cells: Array[Vector2i]) -> Array[Vector2i]:
    var player_cell := _player_cell()
    var cells: Array[Vector2i] = []
    for x in _grid.grid_size.x:
        for y in _grid.grid_size.y:
            var cell := Vector2i(x, y)
            if _is_legal_cell(cell, player_cell, excluded_cells):
                cells.append(cell)
    return cells


## Collects legal LAND cells within a Manhattan distance band of `center`, which may be the player's
## cell (PLAYER_RING) or an authored anchor (ANCHOR_CLUSTER replacement).
func _cells_in_band(center: Vector2i, min_distance: int, max_distance: int, excluded_cells: Array[Vector2i]) -> Array[Vector2i]:
    var player_cell := _player_cell()
    var cells: Array[Vector2i] = []
    for x in _grid.grid_size.x:
        for y in _grid.grid_size.y:
            var cell := Vector2i(x, y)
            var distance := _manhattan_distance(center, cell)
            if distance < min_distance or distance > max_distance:
                continue
            if _is_legal_cell(cell, player_cell, excluded_cells):
                cells.append(cell)
    return cells


func _is_legal_cell(cell: Vector2i, player_cell: Vector2i, excluded_cells: Array[Vector2i]) -> bool:
    return (
        cell != player_cell
        and not excluded_cells.has(cell)
        and _grid.is_in_bounds(cell)
        and _grid.is_walkable(cell)
        and _grid.is_empty(cell)
    )


func _choose_any_walkable_cell() -> Vector2i:
    var player_cell := _player_cell()
    var candidates: Array[Vector2i] = []
    for x in _grid.grid_size.x:
        for y in _grid.grid_size.y:
            var cell := Vector2i(x, y)
            if cell == player_cell:
                continue
            if _grid.is_walkable(cell):
                candidates.append(cell)
    return _pick_random(candidates)

# == Geometry helpers ==


func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
    return absi(a.x - b.x) + absi(a.y - b.y)


## Greedily picks `count` cells that maximize angular spread around `origin`: each pick maximizes
## its minimum angular distance to cells already chosen, so a batch spreads around the player
## instead of clustering in one direction.
func _select_angularly_spread_cells(candidates: Array[Vector2i], count: int, origin: Vector2i) -> Array[Vector2i]:
    var remaining := candidates.duplicate()
    remaining.shuffle()
    var chosen: Array[Vector2i] = [remaining.pop_back()]
    while chosen.size() < count:
        var best_cell := NO_CELL
        var best_min_diff := -1.0
        for candidate in remaining:
            var min_diff := INF
            for picked in chosen:
                var diff := _angle_diff(_angle_from(origin, candidate), _angle_from(origin, picked))
                min_diff = min(min_diff, diff)
            if min_diff > best_min_diff:
                best_min_diff = min_diff
                best_cell = candidate
        chosen.append(best_cell)
        remaining.erase(best_cell)
    return chosen


func _angle_from(origin: Vector2i, cell: Vector2i) -> float:
    return Vector2(cell - origin).angle()


func _angle_diff(a: float, b: float) -> float:
    var diff := absf(a - b)
    return min(diff, TAU - diff)

# == Player cell ==


func _player_cell() -> Vector2i:
    if not _player_cell_provider.is_valid():
        return Vector2i.ZERO
    return _player_cell_provider.call()
