# tick_action_planner.gd
# Pure static geometry and plan functions shared by the tick arena's action and preview controllers:
# mouse-cell resolution, aim direction, dash plan construction, Smash target clamp, Smash area, and
# Chebyshev distance. Every function takes GridArena/TickEngine and resolved cell/range values as
# explicit read-only arguments; it never reads RunBuild, so callers project totals through
# TickCombatRules and pass the resolved results in.
class_name TickActionPlanner

# == Common API ==

## Resolves the world-space mouse position to a grid cell.
static func mouse_cell(grid: GridArena) -> Vector2i:
    return grid.world_to_grid(grid.get_global_mouse_position())


## Resolves the dominant aim direction from the mouse cell relative to the origin cell, falling back
## to the given last-aim when the mouse delta is zero or perfectly diagonal.
static func aim_direction(mouse_cell_pos: Vector2i, origin_cell: Vector2i, last_aim: Vector2i) -> Vector2i:
    var dir := TickCombatRules.dominant_direction(mouse_cell_pos - origin_cell)
    if dir == Vector2i.ZERO:
        return last_aim
    return dir


## Computes the dash plan shared by the preview and the verb: direction and wanted length from the
## cursor (falling back to last-aim when the cursor gives no dominant direction), landing on the
## farthest open cell at or before it, victims collected along the traveled path.
static func compute_dash_plan(grid: GridArena, engine: TickEngine, mouse_cell_pos: Vector2i, origin_cell: Vector2i, last_aim: Vector2i, max_range: int) -> Dictionary:
    var delta := mouse_cell_pos - origin_cell
    var dir := TickCombatRules.dominant_direction(delta)
    if dir == Vector2i.ZERO:
        dir = last_aim
    var wanted := clampi(absi(delta.x * dir.x + delta.y * dir.y), 1, max_range)

    var preview_path: Array[Vector2i] = []
    var travel_path: Array[Vector2i] = []
    var landing_index := -1
    for i in range(1, wanted + 1):
        var step_cell := origin_cell + dir * i
        if not grid.is_land(step_cell):
            break
        preview_path.append(step_cell)
        travel_path.append(step_cell)
        if engine.enemy_at(step_cell) == null:
            landing_index = travel_path.size() - 1
    if landing_index < 0:
        return { "legal": false, "dir": dir, "path": preview_path }

    var travel := travel_path.slice(0, landing_index + 1)
    var victims: Array[GridEnemy] = []
    for travel_cell: Vector2i in travel:
        var enemy := engine.enemy_at(travel_cell)
        if enemy != null:
            victims.append(enemy)
    return {
        "legal": true,
        "dir": dir,
        "path": travel,
        "landing": travel[landing_index],
        "victims": victims,
    }


## Clamps the mouse-aimed cell to a range box centered on the origin cell, independently per axis.
static func clamped_smash_target(mouse_cell_pos: Vector2i, origin_cell: Vector2i, max_range: int) -> Vector2i:
    var delta := mouse_cell_pos - origin_cell
    delta.x = clampi(delta.x, -max_range, max_range)
    delta.y = clampi(delta.y, -max_range, max_range)
    return origin_cell + delta


## Returns the 3x3 block of cells centered on the given landing cell.
static func smash_area(center: Vector2i) -> Array[Vector2i]:
    var area: Array[Vector2i] = []
    for ox in range(-1, 2):
        for oy in range(-1, 2):
            area.append(center + Vector2i(ox, oy))
    return area


## Returns the Chebyshev (chessboard) distance of a cell delta.
static func chebyshev(delta: Vector2i) -> int:
    return maxi(absi(delta.x), absi(delta.y))
