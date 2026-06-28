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


func test_full_line_profile_stops_at_grid_bounds() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.FULL_LINE
    var grid: GridArena = autofree(GridArena.new())

    var cells := EnemyAttackController.get_attack_cells(Vector2i(3, 2), Vector2.RIGHT, attack_data, grid)

    assert_eq(cells, [Vector2i(4, 2), Vector2i(5, 2)])


func test_prepare_configures_tile_hitbox_and_cleanup_clears_cells() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.LINE
    attack_data.line_length = 2
    attack_data.damage = 7.0
    attack_data.damage_interval = 0.25
    var grid: GridArena = autofree(GridArena.new())
    var telegraph: TileTelegraph = autofree(TileTelegraph.new())
    var hitbox: Hitbox = autofree(Hitbox.new())
    var collision_shape: CollisionShape2D = autofree(CollisionShape2D.new())
    hitbox.collision_shape = collision_shape
    var controller: EnemyAttackController = autofree(EnemyAttackController.new())

    controller.setup(grid, telegraph, hitbox)
    var prepared := controller.prepare(Vector2i(1, 1), Vector2.RIGHT, attack_data)

    assert_true(prepared)
    assert_eq(controller.get_cells(), [Vector2i(2, 1), Vector2i(3, 1)])
    assert_eq(hitbox.damage, 7.0)
    assert_eq(hitbox.damage_interval, 0.25)
    assert_not_null(collision_shape.shape)

    controller.end_attack()

    assert_eq(controller.get_cells(), [])


func test_cancel_clears_prepared_cells() -> void:
    var attack_data := EnemyAttackData.new()
    attack_data.cell_shape = EnemyAttackData.CellShape.LINE
    var grid: GridArena = autofree(GridArena.new())
    var controller: EnemyAttackController = autofree(EnemyAttackController.new())

    controller.setup(grid, null, null)
    assert_true(controller.prepare(Vector2i(1, 1), Vector2.RIGHT, attack_data))
    controller.cancel()

    assert_eq(controller.get_cells(), [])
