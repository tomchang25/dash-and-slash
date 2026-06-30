# enemy_spawn_planner.gd
# Computes valid enemy spawn cells around the player for wave starts.
class_name EnemySpawnPlanner
extends RefCounted

const ENEMY_SPAWN_MIN_RADIUS := 2.0
const ENEMY_SPAWN_MAX_RADIUS := 6.0
const ENEMY_SPAWN_OUTWARD_BIAS := 1.8
const ENEMY_SPAWN_RADIUS_JITTER := 1.25
const ENEMY_SPAWN_RESERVED_DISTANCE_WEIGHT := 0.45
const ENEMY_SPAWN_RANDOM_SCORE_WEIGHT := 0.3
const NO_CELL := Vector2i(-1, -1)

var _grid: GridArena
var _player: Player

# == Lifecycle ==


func _init(grid: GridArena = null, player: Player = null) -> void:
    _grid = grid
    _player = player

# == Common API ==


func setup(grid: GridArena, player: Player) -> void:
    _grid = grid
    _player = player


## Picks a spawn cell from available LAND cells, spreading each wave from inner to outer bands.
func choose_enemy_spawn_cell(index: int, spawn_count: int, reserved_spawn_cells: Array[Vector2i]) -> Vector2i:
    var player_cell := _grid.world_to_grid(_player.global_position)
    var candidates := _get_available_enemy_spawn_cells(player_cell, reserved_spawn_cells)
    if not candidates.is_empty():
        var target_radius := _enemy_spawn_target_radius(index, spawn_count, player_cell, candidates)
        return _pick_enemy_spawn_candidate(candidates, player_cell, reserved_spawn_cells, target_radius)

    var empty_cell := _choose_any_empty_spawn_cell(player_cell, reserved_spawn_cells)
    if empty_cell != NO_CELL:
        return empty_cell

    var walkable_cell := _choose_any_walkable_spawn_cell(player_cell, reserved_spawn_cells)
    return walkable_cell if walkable_cell != NO_CELL else player_cell

# == Candidate Collection ==


## Collects currently valid LAND cells for enemy spawn reservation.
func _get_available_enemy_spawn_cells(player_cell: Vector2i, reserved_spawn_cells: Array[Vector2i]) -> Array[Vector2i]:
    var candidates: Array[Vector2i] = []
    for x in _grid.grid_size.x:
        for y in _grid.grid_size.y:
            var candidate := Vector2i(x, y)
            if _is_enemy_spawn_cell_available(candidate, player_cell, reserved_spawn_cells):
                candidates.append(candidate)
    return candidates


## Randomly picks any empty LAND cell as a simple fallback.
func _choose_any_empty_spawn_cell(player_cell: Vector2i, reserved_spawn_cells: Array[Vector2i]) -> Vector2i:
    var candidates := _get_available_enemy_spawn_cells(player_cell, reserved_spawn_cells)
    if candidates.is_empty():
        return NO_CELL
    candidates.shuffle()
    return candidates[0]


## Final fallback that allows overlapping enemies but still requires LAND.
func _choose_any_walkable_spawn_cell(player_cell: Vector2i, reserved_spawn_cells: Array[Vector2i]) -> Vector2i:
    var candidates: Array[Vector2i] = []
    var overlapping_candidates: Array[Vector2i] = []
    for x in _grid.grid_size.x:
        for y in _grid.grid_size.y:
            var candidate := Vector2i(x, y)
            if candidate == player_cell:
                continue
            if not _grid.is_walkable(candidate):
                continue
            overlapping_candidates.append(candidate)
            if not reserved_spawn_cells.has(candidate):
                candidates.append(candidate)
    if candidates.is_empty():
        candidates = overlapping_candidates
    if candidates.is_empty():
        return NO_CELL
    candidates.shuffle()
    return candidates[0]


func _is_enemy_spawn_cell_available(cell: Vector2i, player_cell: Vector2i, reserved_spawn_cells: Array[Vector2i]) -> bool:
    return (
        cell != player_cell
        and not reserved_spawn_cells.has(cell)
        and _grid.is_in_bounds(cell)
        and _grid.is_walkable(cell)
        and _grid.is_empty(cell)
    )

# == Candidate Scoring ==


## Returns the preferred ring radius for this enemy, biased toward inner rings while expanding outward.
func _enemy_spawn_target_radius(index: int, spawn_count: int, player_cell: Vector2i, candidates: Array[Vector2i]) -> float:
    var available_outer_radius := ENEMY_SPAWN_MIN_RADIUS
    for candidate in candidates:
        available_outer_radius = max(available_outer_radius, _cell_distance(player_cell, candidate))

    var outer_radius: float = min(ENEMY_SPAWN_MAX_RADIUS, available_outer_radius)
    var inner_radius: float = min(ENEMY_SPAWN_MIN_RADIUS, outer_radius)
    var progress := 0.0
    if spawn_count > 1:
        progress = float(index) / float(spawn_count - 1)
    progress = pow(progress, ENEMY_SPAWN_OUTWARD_BIAS)

    var target_radius := lerpf(inner_radius, outer_radius, progress)
    target_radius += randf_range(-ENEMY_SPAWN_RADIUS_JITTER, ENEMY_SPAWN_RADIUS_JITTER)
    return clamp(target_radius, inner_radius, outer_radius)


## Picks the lowest-scoring candidate for the target radius while spreading away from reserved spawns.
func _pick_enemy_spawn_candidate(
        candidates: Array[Vector2i],
        player_cell: Vector2i,
        reserved_spawn_cells: Array[Vector2i],
        target_radius: float,
) -> Vector2i:
    candidates.shuffle()
    var best_cell := candidates[0]
    var best_score := INF

    for candidate in candidates:
        var radius_error := absf(_cell_distance(player_cell, candidate) - target_radius)
        var score := radius_error
        if not reserved_spawn_cells.is_empty():
            var nearest_reserved_distance := _nearest_reserved_spawn_distance(candidate, reserved_spawn_cells)
            score -= min(nearest_reserved_distance / max(target_radius, 1.0), 1.0) * ENEMY_SPAWN_RESERVED_DISTANCE_WEIGHT
        score += randf() * ENEMY_SPAWN_RANDOM_SCORE_WEIGHT

        if score < best_score:
            best_score = score
            best_cell = candidate

    return best_cell


func _nearest_reserved_spawn_distance(cell: Vector2i, reserved_spawn_cells: Array[Vector2i]) -> float:
    var nearest_distance := INF
    for reserved_cell in reserved_spawn_cells:
        nearest_distance = min(nearest_distance, _cell_distance(cell, reserved_cell))
    return nearest_distance


func _cell_distance(a: Vector2i, b: Vector2i) -> float:
    return Vector2(a - b).length()
