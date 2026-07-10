# test_enemy_attack_controller.gd
# Verifies EnemyAttackController.get_attack_cells cell footprints.
extends GutTest

class FailingAttackEnemy:
    extends GridEnemy

    var end_called := false


    func begin_attack() -> bool:
        return false


    func end_attack() -> void:
        end_called = true


func test_line_profile_starts_one_cell_forward() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.LINE
    attack_data.line_length = 3
    var grid: GridArena = autofree(GridArena.new())

    var cells := EnemyAttackController.get_attack_cells(Vector2i(2, 2), Vector2.RIGHT, attack_data, grid)

    assert_eq(cells, [Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)])


func test_wide_profile_starts_one_cell_forward() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.WIDE
    attack_data.depth = 2
    attack_data.width = 3
    var grid: GridArena = autofree(GridArena.new())

    var cells := EnemyAttackController.get_attack_cells(Vector2i(2, 2), Vector2.DOWN, attack_data, grid)

    assert_eq(
        cells,
        [
            Vector2i(1, 3),
            Vector2i(2, 3),
            Vector2i(3, 3),
            Vector2i(1, 4),
            Vector2i(2, 4),
            Vector2i(3, 4),
        ],
    )


func test_adjacent_ring_profile_excludes_origin_cell() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.ADJACENT_RING
    attack_data.radius = 1
    var grid: GridArena = autofree(GridArena.new())

    var cells := EnemyAttackController.get_attack_cells(Vector2i(2, 2), Vector2.DOWN, attack_data, grid)

    assert_eq(cells.size(), 8)
    assert_false(Vector2i(2, 2) in cells)
    assert_true(Vector2i(1, 1) in cells)
    assert_true(Vector2i(3, 3) in cells)


func test_adjacent_ring_origin_cells_exclude_target_cell() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.ADJACENT_RING
    attack_data.radius = 1
    var grid: GridArena = autofree(GridArena.new())

    var origins := EnemyAttackController.get_attack_origin_cells(Vector2i(2, 2), attack_data, grid)

    assert_eq(origins.size(), 8)
    assert_false(Vector2i(2, 2) in origins)
    assert_true(Vector2i(1, 1) in origins)
    assert_true(Vector2i(3, 3) in origins)


func test_cancel_clears_prepared_cells() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.LINE
    var grid: GridArena = autofree(GridArena.new())
    var controller: EnemyAttackController = autofree(EnemyAttackController.new())

    controller.setup(grid, null)
    assert_true(controller.prepare(Vector2i(1, 1), Vector2.RIGHT, attack_data))
    controller.cancel()

    assert_eq(controller.get_cells(), [])
