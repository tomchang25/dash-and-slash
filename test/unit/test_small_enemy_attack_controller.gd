# test_small_enemy_attack_controller.gd
# Verifies SmallEnemy attack pattern cell footprints.
extends GutTest

func test_line_1x4_starts_one_cell_forward() -> void:
    var controller := SmallEnemyAttackController.new()
    controller.set_attack_pattern(SmallEnemyAttackController.AttackPattern.LINE_1X4)

    var cells := controller.get_attack_cells(Vector2i(2, 2), Vector2.RIGHT)

    assert_eq(cells, [Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)])


func test_wide_2x3_starts_one_cell_forward() -> void:
    var controller := SmallEnemyAttackController.new()
    controller.set_attack_pattern(SmallEnemyAttackController.AttackPattern.WIDE_2X3)

    var cells := controller.get_attack_cells(Vector2i(2, 2), Vector2.DOWN)

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
