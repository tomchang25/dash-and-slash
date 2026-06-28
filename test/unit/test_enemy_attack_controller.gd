# test_enemy_attack_controller.gd
# Verifies EnemyAttackController.get_attack_cells cell footprints.
extends GutTest

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


func test_full_line_profile_stops_at_grid_bounds() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.FULL_LINE
    var grid: GridArena = autofree(GridArena.new())

    var cells := EnemyAttackController.get_attack_cells(Vector2i(3, 2), Vector2.RIGHT, attack_data, grid)

    assert_eq(cells, [Vector2i(4, 2), Vector2i(5, 2)])
