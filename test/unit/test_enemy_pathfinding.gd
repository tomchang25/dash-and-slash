# test_enemy_pathfinding.gd
# Verifies GridEnemy path planning treats temporary blockers as pass-through hints.
extends GutTest

class PathEnemy:
    extends GridEnemy

    var _test_attack_data: EnemyAttackData


    func setup_path_grid(grid: GridArena, start: Vector2i) -> void:
        _grid = grid
        _grid_pos = start


    func find_path_to(goal_cells: Array[Vector2i]) -> Array[Vector2i]:
        return _find_path_to_cell(_grid_pos, NO_BLOCKED_CELL, goal_cells, false)


    func setup_approach_grid(grid: GridArena, start: Vector2i, target: Node2D) -> void:
        _grid = grid
        _grid_pos = start
        _target = target
        _grid.register_occupant(self, [start])
        _grid.register_enemy_entity(self)


    func plan_approach() -> bool:
        return plan_approach_action()


    func get_planned_path() -> Array[Vector2i]:
        return _planned_path.duplicate()


    func set_attack_data(attack_data: EnemyAttackData) -> void:
        _test_attack_data = attack_data


    func get_current_attack_data() -> EnemyAttackData:
        return _test_attack_data


    func plan_charge() -> bool:
        return plan_charge_origin_action()


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


func test_approach_moves_closer_when_adjacent_cells_are_occupied() -> void:
    _setup_square_grid(Vector2i(5, 5))
    var target_cell := Vector2i(2, 2)
    var enemy: PathEnemy = autofree(PathEnemy.new())
    enemy.setup_approach_grid(_grid, Vector2i(0, 0), _make_target(target_cell))
    _occupy_cell(target_cell)
    for direction: Vector2i in GridEnemy.CARDINAL_DIRECTIONS:
        _occupy_cell(target_cell + direction)

    assert_true(enemy.plan_approach())

    var path := enemy.get_planned_path()
    assert_false(path.is_empty())
    assert_eq(path[path.size() - 1], Vector2i(1, 1))


func test_approach_moves_closer_when_adjacent_cells_are_sea() -> void:
    _setup_square_grid(Vector2i(7, 7))
    var target_cell := Vector2i(4, 4)
    var enemy: PathEnemy = autofree(PathEnemy.new())
    enemy.setup_approach_grid(_grid, Vector2i(0, 4), _make_target(target_cell))
    _occupy_cell(target_cell)
    for direction: Vector2i in GridEnemy.CARDINAL_DIRECTIONS:
        assert_true(_grid.set_sea(target_cell + direction))

    assert_true(enemy.plan_approach())

    var path := enemy.get_planned_path()
    assert_false(path.is_empty())
    assert_eq(path[path.size() - 1], Vector2i(2, 4))


func test_approach_moves_closer_without_stealing_active_step_reservations() -> void:
    _setup_square_grid(Vector2i(5, 5))
    var target_cell := Vector2i(2, 2)
    var enemy: PathEnemy = autofree(PathEnemy.new())
    enemy.setup_approach_grid(_grid, Vector2i(0, 0), _make_target(target_cell))
    _occupy_cell(target_cell)
    for direction: Vector2i in GridEnemy.CARDINAL_DIRECTIONS:
        var reserved_cell: Vector2i = target_cell + direction
        var reserver: Node = autofree(Node.new())
        assert_true(_grid.reserve_cells_with_active_steps(reserver, [reserved_cell], false, [reserved_cell]))

    assert_true(enemy.plan_approach())

    var path := enemy.get_planned_path()
    assert_false(path.is_empty())
    assert_eq(path[path.size() - 1], Vector2i(1, 1))


func test_charge_planning_uses_attack_data_origin_range() -> void:
    _setup_square_grid(Vector2i(6, 5))
    var target_cell := Vector2i(4, 2)
    var enemy: PathEnemy = autofree(PathEnemy.new())
    enemy.setup_approach_grid(_grid, Vector2i(0, 2), _make_target(target_cell))
    enemy.set_attack_data(_make_charge_line_attack(2))

    assert_false(enemy.can_charge_target_from_cell(enemy.get_grid_pos()))
    assert_true(enemy.plan_charge())

    var path := enemy.get_planned_path()
    assert_false(path.is_empty())
    assert_eq(path[path.size() - 1], Vector2i(2, 2))


func test_charge_planning_returns_ready_when_already_at_valid_origin() -> void:
    _setup_square_grid(Vector2i(6, 5))
    var target_cell := Vector2i(4, 2)
    var enemy: PathEnemy = autofree(PathEnemy.new())
    enemy.setup_approach_grid(_grid, Vector2i(2, 2), _make_target(target_cell))
    enemy.set_attack_data(_make_charge_line_attack(2))

    assert_true(enemy.can_charge_target_from_cell(enemy.get_grid_pos()))
    assert_true(enemy.plan_charge())
    assert_true(enemy.get_planned_path().is_empty())


func _setup_square_grid(size: Vector2i) -> void:
    _grid = autofree(GridArena.new())
    _grid.grid_size = size
    _grid.starting_land_size = size
    _grid.generate_grid()


func _make_target(cell: Vector2i) -> Node2D:
    var target: Node2D = autofree(Node2D.new())
    target.global_position = _grid.cell_center(cell)
    return target


func _occupy_cell(cell: Vector2i) -> void:
    var occupant: Node = autofree(Node.new())
    _grid.register_occupant(occupant, [cell])


func _make_charge_line_attack(line_length: int) -> EnemyAttackData:
    var attack_data: EnemyAttackData = EnemyAttackData.new()
    attack_data.attack_kind = EnemyAttackData.AttackKind.CHARGE
    attack_data.cell_shape = EnemyAttackData.CellShape.LINE
    attack_data.line_length = line_length
    return attack_data
