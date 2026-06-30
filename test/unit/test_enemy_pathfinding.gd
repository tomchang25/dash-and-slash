# test_enemy_pathfinding.gd
# Verifies GridEnemy path planning treats temporary blockers as pass-through hints.
extends GutTest

class PathEnemy:
    extends GridEnemy

    func setup_path_grid(grid: GridArena, start: Vector2i) -> void:
        _grid = grid
        _grid_pos = start


    func find_path_to(goal_cells: Array[Vector2i]) -> Array[Vector2i]:
        return _find_path_to_cell(_grid_pos, NO_BLOCKED_CELL, goal_cells, false)


var _grid: GridArena


func before_each() -> void:
    _grid = autofree(GridArena.new())
    _grid.grid_size = Vector2i(5, 1)
    _grid.starting_land_size = Vector2i(5, 1)
    _grid.generate_grid()


func after_each() -> void:
    _grid = null


func test_path_can_pass_through_occupied_middle_cell() -> void:
    var enemy: PathEnemy = autofree(PathEnemy.new())
    enemy.setup_path_grid(_grid, Vector2i(0, 0))
    var blocker: Node = autofree(Node.new())
    _grid.register_occupant(blocker, [Vector2i(2, 0)])

    var path := enemy.find_path_to([Vector2i(4, 0)])

    assert_eq(path, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)])


func test_path_can_pass_through_reserved_middle_cell() -> void:
    var enemy: PathEnemy = autofree(PathEnemy.new())
    enemy.setup_path_grid(_grid, Vector2i(0, 0))
    var reserver: Node = autofree(Node.new())
    assert_true(_grid.reserve_cell(reserver, Vector2i(2, 0)))

    var path := enemy.find_path_to([Vector2i(4, 0)])

    assert_eq(path, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)])


func test_path_rejects_occupied_first_step() -> void:
    var enemy: PathEnemy = autofree(PathEnemy.new())
    enemy.setup_path_grid(_grid, Vector2i(0, 0))
    var blocker: Node = autofree(Node.new())
    _grid.register_occupant(blocker, [Vector2i(1, 0)])

    var path := enemy.find_path_to([Vector2i(4, 0)])

    assert_true(path.is_empty())
