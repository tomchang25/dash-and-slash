# test_enemy_spawn_planner.gd
# Covers EnemySpawnPlanner's three placement strategies (PLAYER_RING, ANCHOR_CLUSTER, SCATTER):
# complete-plan success and failure, anchor retention, warning-resolution revalidation, and
# strategy-aware replacement with its any-legal-cell fallback. WaveController's own scheduling and
# atomic-admission bookkeeping are covered in test_wave_controller.gd with a stubbed planner.
extends GutTest

# == plan_group_cells: PLAYER_RING ==

func test_plan_player_ring_returns_cells_within_band_excluding_player() -> void:
    var grid := _make_grid(Vector2i(11, 11))
    var player_cell := Vector2i(5, 5)
    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return player_cell)

    var plan := planner.plan_group_cells(SpawnGroupDefinition.PlacementStrategy.PLAYER_RING, 3)

    assert_eq(plan["cells"].size(), 3)
    assert_eq(plan["anchor"], player_cell, "PLAYER_RING anchors on the player cell")
    for cell: Vector2i in plan["cells"]:
        assert_ne(cell, player_cell)
        var distance := absi(cell.x - player_cell.x) + absi(cell.y - player_cell.y)
        assert_true(distance >= 2 and distance <= 4, "cell %s must sit in the 2-4 Manhattan band" % cell)


func test_plan_player_ring_fails_when_band_lacks_enough_cells() -> void:
    var grid := _make_grid(Vector2i(3, 3))
    var player_cell := Vector2i(1, 1)
    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return player_cell)

    var plan := planner.plan_group_cells(SpawnGroupDefinition.PlacementStrategy.PLAYER_RING, 5)

    assert_true(plan["cells"].is_empty(), "only the 4 corners sit in the band on a 3x3 grid, fewer than the requested 5")

# == plan_group_cells: ANCHOR_CLUSTER ==


func test_plan_anchor_cluster_picks_an_anchor_in_band_and_fills_nearest_cells() -> void:
    var grid := _make_grid(Vector2i(13, 13))
    var player_cell := Vector2i(6, 6)
    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return player_cell)

    var plan := planner.plan_group_cells(SpawnGroupDefinition.PlacementStrategy.ANCHOR_CLUSTER, 4)

    assert_eq(plan["cells"].size(), 4)
    var anchor: Vector2i = plan["anchor"]
    var anchor_distance := absi(anchor.x - player_cell.x) + absi(anchor.y - player_cell.y)
    assert_true(anchor_distance >= 3 and anchor_distance <= 5, "the anchor must sit in the 3-5 Manhattan band from the player")
    for cell: Vector2i in plan["cells"]:
        assert_ne(cell, player_cell)


func test_plan_anchor_cluster_fails_when_no_anchor_candidate_exists() -> void:
    var grid := _make_grid(Vector2i(3, 3))
    var player_cell := Vector2i(1, 1)
    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return player_cell)

    var plan := planner.plan_group_cells(SpawnGroupDefinition.PlacementStrategy.ANCHOR_CLUSTER, 1)

    assert_true(plan["cells"].is_empty(), "no cell on a 3x3 grid reaches Manhattan distance 3 from the center")


func test_plan_anchor_cluster_fails_when_fewer_legal_cells_than_requested() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var player_cell := Vector2i(2, 2)
    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return player_cell)

    var plan := planner.plan_group_cells(SpawnGroupDefinition.PlacementStrategy.ANCHOR_CLUSTER, 30)

    assert_true(plan["cells"].is_empty(), "a 5x5 grid has far fewer than 30 legal cells")

# == plan_group_cells: SCATTER ==


func test_plan_scatter_returns_distinct_legal_cells_with_no_anchor() -> void:
    var grid := _make_grid(Vector2i(6, 6))
    var player_cell := Vector2i(3, 3)
    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return player_cell)

    var plan := planner.plan_group_cells(SpawnGroupDefinition.PlacementStrategy.SCATTER, 5)

    assert_eq(plan["cells"].size(), 5)
    assert_eq(plan["anchor"], EnemySpawnPlanner.NO_CELL, "SCATTER has no shared anchor")
    var seen: Dictionary = { }
    for cell: Vector2i in plan["cells"]:
        assert_ne(cell, player_cell)
        assert_false(seen.has(cell), "SCATTER must not repeat a cell within one plan")
        seen[cell] = true


func test_plan_scatter_excludes_occupied_and_reserved_cells() -> void:
    var grid := _make_grid(Vector2i(3, 3))
    var player_cell := Vector2i(1, 1)
    grid.register_occupant(autofree(Node.new()), [Vector2i(0, 0)])
    assert_true(grid.reserve_cell(autofree(Node.new()), Vector2i(0, 1)))
    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return player_cell)

    var plan := planner.plan_group_cells(SpawnGroupDefinition.PlacementStrategy.SCATTER, 6)
    assert_eq(plan["cells"].size(), 6, "6 legal cells remain: 9 total minus player, one occupied, one reserved")
    assert_false(Vector2i(0, 0) in plan["cells"])
    assert_false(Vector2i(0, 1) in plan["cells"])

    var failing_plan := planner.plan_group_cells(SpawnGroupDefinition.PlacementStrategy.SCATTER, 7)
    assert_true(failing_plan["cells"].is_empty(), "only 6 legal cells remain once one is occupied and one reserved")


func test_plan_group_cells_returns_empty_for_non_positive_count() -> void:
    var grid := _make_grid(Vector2i(4, 4))
    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return Vector2i(0, 0))

    var plan := planner.plan_group_cells(SpawnGroupDefinition.PlacementStrategy.SCATTER, 0)

    assert_true(plan["cells"].is_empty())

# == is_spawn_cell_still_valid ==


func test_is_spawn_cell_still_valid_rejects_occupied_cell() -> void:
    var grid := _make_grid(Vector2i(4, 4))
    grid.register_occupant(autofree(Node.new()), [Vector2i(1, 1)])

    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return Vector2i(3, 3))
    assert_false(planner.is_spawn_cell_still_valid(Vector2i(1, 1), []), "an occupied cell is not a valid spawn target")
    assert_true(planner.is_spawn_cell_still_valid(Vector2i(2, 2), []), "an unoccupied land cell is valid")


func test_is_spawn_cell_still_valid_rejects_player_cell() -> void:
    var grid := _make_grid(Vector2i(4, 4))

    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return Vector2i(2, 2))
    assert_false(planner.is_spawn_cell_still_valid(Vector2i(2, 2), []), "the player's own cell is never a valid spawn target")


func test_is_spawn_cell_still_valid_rejects_excluded_cell() -> void:
    var grid := _make_grid(Vector2i(4, 4))

    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return Vector2i(3, 3))
    assert_false(planner.is_spawn_cell_still_valid(Vector2i(1, 1), [Vector2i(1, 1)]), "a cell already claimed within the same batch is not valid")

# == find_replacement_cell: anchor/strategy retention and fallback ==


func test_find_replacement_cell_player_ring_prefers_the_band() -> void:
    var grid := _make_grid(Vector2i(11, 11))
    var player_cell := Vector2i(5, 5)
    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return player_cell)

    var replacement := planner.find_replacement_cell(SpawnGroupDefinition.PlacementStrategy.PLAYER_RING, player_cell, [])

    var distance := absi(replacement.x - player_cell.x) + absi(replacement.y - player_cell.y)
    assert_true(distance >= 2 and distance <= 4, "PLAYER_RING replacement should prefer the band when it has room")


func test_find_replacement_cell_player_ring_falls_back_to_any_legal_cell_when_band_is_exhausted() -> void:
    var grid := _make_grid(Vector2i(5, 1))
    var player_cell := Vector2i(2, 0)
    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return player_cell)

    var excluded: Array[Vector2i] = [Vector2i(0, 0), Vector2i(4, 0)]
    var replacement := planner.find_replacement_cell(SpawnGroupDefinition.PlacementStrategy.PLAYER_RING, player_cell, excluded)

    assert_true(replacement in [Vector2i(1, 0), Vector2i(3, 0)], "with both band cells excluded, replacement must fall back to any remaining legal cell")


func test_find_replacement_cell_anchor_cluster_prefers_the_cell_nearest_the_stored_anchor() -> void:
    var grid := _make_grid(Vector2i(9, 1))
    var player_cell := Vector2i(4, 0)
    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return player_cell)
    var anchor := Vector2i(8, 0)

    var replacement := planner.find_replacement_cell(SpawnGroupDefinition.PlacementStrategy.ANCHOR_CLUSTER, anchor, [])

    assert_eq(replacement, Vector2i(8, 0), "the nearest legal cell to the stored anchor is the anchor cell itself")


func test_find_replacement_cell_anchor_cluster_falls_back_to_any_legal_cell_when_anchor_is_missing() -> void:
    var grid := _make_grid(Vector2i(3, 3))
    var player_cell := Vector2i(1, 1)
    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return player_cell)

    var replacement := planner.find_replacement_cell(SpawnGroupDefinition.PlacementStrategy.ANCHOR_CLUSTER, EnemySpawnPlanner.NO_CELL, [])

    assert_ne(replacement, EnemySpawnPlanner.NO_CELL, "a missing anchor must still fall back to any legal cell rather than failing")
    assert_ne(replacement, player_cell)


func test_find_replacement_cell_scatter_returns_any_legal_cell() -> void:
    var grid := _make_grid(Vector2i(2, 2))
    var player_cell := Vector2i(0, 0)
    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return player_cell)

    var replacement := planner.find_replacement_cell(SpawnGroupDefinition.PlacementStrategy.SCATTER, EnemySpawnPlanner.NO_CELL, [Vector2i(1, 0), Vector2i(0, 1)])

    assert_eq(replacement, Vector2i(1, 1), "the only remaining legal cell should be chosen")


func test_find_replacement_cell_returns_no_cell_when_grid_is_full() -> void:
    var grid := _make_grid(Vector2i(2, 2))
    grid.register_occupant(autofree(Node.new()), [Vector2i(0, 0)])
    grid.register_occupant(autofree(Node.new()), [Vector2i(1, 0)])
    grid.register_occupant(autofree(Node.new()), [Vector2i(0, 1)])
    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return Vector2i(1, 1))

    var replacement := planner.find_replacement_cell(SpawnGroupDefinition.PlacementStrategy.SCATTER, EnemySpawnPlanner.NO_CELL, [])

    assert_eq(replacement, EnemySpawnPlanner.NO_CELL, "no legal cell remains open")

# == choose_fallback_cell (debug Wave 1 boss convenience) ==


func test_choose_fallback_cell_uses_a_legal_cell_when_available() -> void:
    var grid := _make_grid(Vector2i(4, 4))
    var player_cell := Vector2i(2, 2)
    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return player_cell)

    var cell := planner.choose_fallback_cell()

    assert_ne(cell, player_cell)
    assert_true(grid.is_walkable(cell))


func test_choose_fallback_cell_never_fails_even_on_a_fully_occupied_grid() -> void:
    var grid := _make_grid(Vector2i(2, 2))
    var player_cell := Vector2i(0, 0)
    grid.register_occupant(autofree(Node.new()), [Vector2i(1, 0)])
    grid.register_occupant(autofree(Node.new()), [Vector2i(0, 1)])
    grid.register_occupant(autofree(Node.new()), [Vector2i(1, 1)])
    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return player_cell)

    var cell := planner.choose_fallback_cell()

    assert_true(
        cell in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), player_cell],
        "a completely full grid must still return some cell, falling back through occupied land or the player cell",
    )

# == Test helpers ==


func _make_grid(size: Vector2i) -> GridArena:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = size
    grid.starting_land_size = size
    grid.generate_grid()
    return grid
