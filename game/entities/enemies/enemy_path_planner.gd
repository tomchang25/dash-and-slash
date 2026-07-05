# enemy_path_planner.gd
# Stateless grid path search for enemy movement planning: reservation-aware BFS over a GridArena on
# behalf of an asking entity. Kept free of enemy state so the shared enemy base owns only planning
# policy (candidate/scoring callables and where a resolved path is stored), not the search itself.
class_name EnemyPathPlanner
extends RefCounted

const NO_CELL := Vector2i(-1, -1)

# == Common API ================================================================


## BFS from start to the nearest cell in goal_cells, treating blocked_cell as impassable. The start
## cell and any goal cell must be claimable by the asker; interior cells may pass through occupied or
## reserved cells as a hint. Returns the step sequence (excluding start), or empty when unreachable.
static func find_path_to_cell(
        grid: GridArena,
        asker: Object,
        directions: Array,
        start: Vector2i,
        blocked_cell: Vector2i,
        goal_cells: Array[Vector2i],
        is_attack: bool,
) -> Array[Vector2i]:
    var queue: Array[Vector2i] = [start]
    var came_from: Dictionary = { }
    var queue_index := 0
    var goal := NO_CELL
    came_from[start] = start

    while queue_index < queue.size():
        var current := queue[queue_index]
        queue_index += 1

        if current in goal_cells:
            goal = current
            break

        for direction: Vector2i in directions:
            var next := current + direction
            if came_from.has(next):
                continue
            if not _can_path_through(grid, asker, current, next, start, blocked_cell, goal_cells, is_attack):
                continue
            came_from[next] = current
            queue.append(next)

    if goal == NO_CELL:
        var empty_path: Array[Vector2i] = []
        return empty_path

    return _reconstruct_path(came_from, goal)


## BFS that explores the reachable region and returns the path to the best-scoring valid endpoint,
## ranked by the caller's score_candidate callable (lower is better) with deterministic tie-breaks.
## is_candidate filters which reached cells are eligible endpoints; score_candidate ranks them.
static func find_path_to_best_reachable_cell(
        grid: GridArena,
        asker: Object,
        directions: Array,
        start: Vector2i,
        blocked_cell: Vector2i,
        is_attack: bool,
        is_candidate: Callable,
        score_candidate: Callable,
) -> Array[Vector2i]:
    var queue: Array[Vector2i] = [start]
    var came_from: Dictionary = { }
    var distances: Dictionary = { }
    var queue_index := 0
    var best_cell := NO_CELL
    var best_score := 999999
    var best_path_length := 999999
    var endpoint_goals: Array[Vector2i] = []
    came_from[start] = start
    distances[start] = 0

    while queue_index < queue.size():
        var current := queue[queue_index]
        queue_index += 1

        var path_length: int = distances[current]
        if _can_end_ranked_path_at(grid, asker, current, start, is_attack) and is_candidate.call(current):
            var score: int = score_candidate.call(current, path_length)
            if _is_better_ranked_endpoint(score, path_length, current, best_score, best_path_length, best_cell):
                best_cell = current
                best_score = score
                best_path_length = path_length

        for direction: Vector2i in directions:
            var next := current + direction
            if came_from.has(next):
                continue
            if not _can_path_through(grid, asker, current, next, start, blocked_cell, endpoint_goals, is_attack):
                continue
            came_from[next] = current
            distances[next] = path_length + 1
            queue.append(next)

    if best_cell == NO_CELL or best_cell == start:
        var empty_path: Array[Vector2i] = []
        return empty_path

    return _reconstruct_path(came_from, best_cell)


## Returns true when the asker may end a planned path on the cell: walkable land it can claim.
static func can_plan_goal_cell(grid: GridArena, asker: Object, cell: Vector2i, is_attack: bool) -> bool:
    if not grid.is_walkable(cell):
        return false
    return _can_claim_committed_path_cell(grid, asker, cell, is_attack)

# == Search internals ==========================================================


static func _reconstruct_path(came_from: Dictionary, goal: Vector2i) -> Array[Vector2i]:
    var path: Array[Vector2i] = []
    var path_cell := goal
    while came_from[path_cell] != path_cell:
        path.push_front(path_cell)
        path_cell = came_from[path_cell]
    return path


static func _can_end_ranked_path_at(grid: GridArena, asker: Object, cell: Vector2i, start: Vector2i, is_attack: bool) -> bool:
    return cell == start or can_plan_goal_cell(grid, asker, cell, is_attack)


static func _is_better_ranked_endpoint(
        score: int,
        path_length: int,
        cell: Vector2i,
        best_score: int,
        best_path_length: int,
        best_cell: Vector2i,
) -> bool:
    if best_cell == NO_CELL:
        return true
    if score != best_score:
        return score < best_score
    if path_length != best_path_length:
        return path_length < best_path_length
    if cell.y != best_cell.y:
        return cell.y < best_cell.y
    return cell.x < best_cell.x


static func _can_path_through(
        grid: GridArena,
        asker: Object,
        current: Vector2i,
        next: Vector2i,
        start: Vector2i,
        blocked_cell: Vector2i,
        goal_cells: Array[Vector2i],
        is_attack: bool,
) -> bool:
    if not grid.can_move_between(current, next):
        return false
    if next == blocked_cell:
        return false
    if _needs_committed_path_cell(current, next, start, goal_cells):
        return _can_claim_committed_path_cell(grid, asker, next, is_attack)
    return true


static func _needs_committed_path_cell(
        current: Vector2i,
        next: Vector2i,
        start: Vector2i,
        goal_cells: Array[Vector2i],
) -> bool:
    return current == start or next in goal_cells


static func _can_claim_committed_path_cell(grid: GridArena, asker: Object, cell: Vector2i, is_attack: bool) -> bool:
    if grid.is_occupied(cell):
        return false
    if not grid.is_reserved(cell):
        return true
    return grid.can_reserve_cell(asker, cell, is_attack)
