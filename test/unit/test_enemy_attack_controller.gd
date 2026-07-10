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


func test_line_profile_up_facing_computes_correct_forward_cells() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.LINE
    attack_data.line_length = 3
    var grid: GridArena = autofree(GridArena.new())

    var cells := EnemyAttackController.get_attack_cells(Vector2i(5, 5), Vector2.UP, attack_data, grid)

    assert_eq(cells, [Vector2i(5, 4), Vector2i(5, 3), Vector2i(5, 2)])


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


func test_wide_origin_cells_reverse_forward_and_opposing_facings() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.WIDE
    attack_data.depth = 2
    attack_data.width = 3
    var grid: GridArena = autofree(GridArena.new())

    var origins := EnemyAttackController.get_attack_origin_cells(Vector2i(2, 3), attack_data, grid)

    assert_true(Vector2i(2, 2) in origins, "an enemy facing DOWN at (2,2) would hit (2,3) as its nearest forward-center cell")
    assert_true(Vector2i(2, 4) in origins, "an enemy facing UP at (2,4) would also hit (2,3) as its nearest forward-center cell")
    assert_false(Vector2i(2, 3) in origins, "WIDE starts one cell forward, so the target's own cell is never a valid origin")


func test_square_origin_cells_include_the_target_cell_itself() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.SQUARE
    attack_data.radius = 1
    var grid: GridArena = autofree(GridArena.new())

    var origins := EnemyAttackController.get_attack_origin_cells(Vector2i(5, 5), attack_data, grid)

    assert_true(Vector2i(5, 5) in origins, "SQUARE's radius includes the origin cell, so the target cell itself is always a valid origin")
    assert_true(Vector2i(4, 4) in origins)
    assert_true(Vector2i(6, 6) in origins)


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


func test_square_profile_normalizes_to_local_offsets() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.SQUARE
    attack_data.radius = 1
    var grid: GridArena = autofree(GridArena.new())

    var cells := EnemyAttackController.get_attack_cells(Vector2i(2, 2), Vector2.LEFT, attack_data, grid)

    assert_eq(cells.size(), 9)
    assert_true(Vector2i(2, 2) in cells)
    assert_true(Vector2i(1, 1) in cells)
    assert_true(Vector2i(3, 3) in cells)


func test_line_origin_cells_reverse_normalized_footprints() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.LINE
    attack_data.line_length = 2
    var grid: GridArena = autofree(GridArena.new())

    var origins := EnemyAttackController.get_attack_origin_cells(Vector2i(3, 2), attack_data, grid)

    assert_true(Vector2i(2, 2) in origins)
    assert_true(Vector2i(1, 2) in origins)
    assert_false(Vector2i(3, 2) in origins)


func test_custom_offsets_use_forward_left_local_space() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.CUSTOM_OFFSETS
    attack_data.cell_offsets = [
        Vector2i(1, -1),
        Vector2i(1, 0),
        Vector2i(1, 1),
    ]
    var grid: GridArena = autofree(GridArena.new())

    var right_facing_cells := EnemyAttackController.get_attack_cells(Vector2i(2, 2), Vector2.RIGHT, attack_data, grid)
    var down_facing_cells := EnemyAttackController.get_attack_cells(Vector2i(2, 2), Vector2.DOWN, attack_data, grid)

    assert_eq(right_facing_cells, [Vector2i(3, 3), Vector2i(3, 2), Vector2i(3, 1)])
    assert_eq(down_facing_cells, [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)])


func test_custom_offset_origin_cells_reverse_committed_footprints() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.CUSTOM_OFFSETS
    attack_data.cell_offsets = [
        Vector2i(1, 0),
        Vector2i(2, 0),
    ]
    var grid: GridArena = autofree(GridArena.new())

    var origins := EnemyAttackController.get_attack_origin_cells(Vector2i(3, 2), attack_data, grid)

    assert_true(Vector2i(2, 2) in origins)
    assert_true(Vector2i(1, 2) in origins)
    assert_false(Vector2i(3, 2) in origins)


func test_cancel_clears_prepared_cells() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.LINE
    var grid: GridArena = autofree(GridArena.new())
    var controller: EnemyAttackController = autofree(EnemyAttackController.new())

    controller.setup(grid, null)
    assert_true(controller.prepare(Vector2i(1, 1), Vector2.RIGHT, attack_data))
    controller.cancel()

    assert_eq(controller.get_cells(), [])
