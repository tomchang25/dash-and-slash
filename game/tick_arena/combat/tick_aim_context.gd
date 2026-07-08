# tick_aim_context.gd
# Shared aim/plan resolution for the tick arena's action and preview controllers: mouse cell, aim
# direction, dash plan, Smash target clamp/area, and Chebyshev distance, projected through the run's
# mobility range bonus. Constructed by each controller's setup() and read every frame; both controllers
# resolve exclusively through this instead of each keeping its own copy of the TickActionPlanner
# wrapping, so a preview can never disagree with what a commit resolves.
class_name TickAimContext
extends RefCounted

# -- State --

var _grid: GridArena
var _engine: TickEngine
var _player: TickPlayer
var _run_build: RunBuild
var _last_aim_getter: Callable

# == Lifecycle ==


## last_aim_getter is called fresh on every resolution so the context always reads the owner's current
## last-aim direction, never a value snapshotted at construction time.
func _init(grid: GridArena, engine: TickEngine, player: TickPlayer, run_build: RunBuild, last_aim_getter: Callable) -> void:
    _grid = grid
    _engine = engine
    _player = player
    _run_build = run_build
    _last_aim_getter = last_aim_getter

# == Common API ==


## Resolves the world-space mouse position to a grid cell, falling back to the player's cell plus the
## live last-aim direction when the grid is not yet inside the scene tree (pre-spawn, unit tests).
func mouse_cell() -> Vector2i:
    if not _grid.is_inside_tree():
        return _player.cell + _last_aim()
    return TickActionPlanner.mouse_cell(_grid)


func aim_direction() -> Vector2i:
    return TickActionPlanner.aim_direction(mouse_cell(), _player.cell, _last_aim())


## Computes the dash plan shared by the preview and the verb, ranged through the run's Mobility Range bonus.
func compute_dash_plan() -> Dictionary:
    return TickActionPlanner.compute_dash_plan(_grid, _engine, mouse_cell(), _player.cell, _last_aim(), dash_range())


## Clamps the mouse-aimed Smash target, ranged through the run's Mobility Range bonus.
func clamped_smash_target() -> Vector2i:
    return TickActionPlanner.clamped_smash_target(mouse_cell(), _player.cell, smash_range())


func smash_area(center: Vector2i) -> Array[Vector2i]:
    return TickActionPlanner.smash_area(center)


func chebyshev(delta: Vector2i) -> int:
    return TickActionPlanner.chebyshev(delta)


## Dash's base range projected through the run's Mobility Range bonus.
func dash_range() -> int:
    return TickCombatProjection.mobility_range_cells(_run_build, TickCombatRules.DASH_RANGE)


## Smash's base range projected through the run's Mobility Range bonus.
func smash_range() -> int:
    return TickCombatProjection.mobility_range_cells(_run_build, TickCombatRules.SMASH_RANGE)

# == Aiming ==


func _last_aim() -> Vector2i:
    return _last_aim_getter.call()
