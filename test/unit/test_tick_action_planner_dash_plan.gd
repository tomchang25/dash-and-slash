# test_tick_action_planner_dash_plan.gd
# Tests TickActionPlanner.compute_dash_plan(): the shared dash geometry the tick arena's action and
# preview controllers both call, so a landing/victim disagreement between preview and commit is
# impossible by construction. Uses a real GridArena (fully-land terrain) and TickEngine actor
# registry, with a minimal GridEnemy stand-in so enemy_at() sees a live victim without needing a
# health/guard node graph, matching the pattern test_wave_controller.gd already uses for actor doubles.
extends GutTest

class FakeVictim:
    extends GridEnemy

    func is_alive() -> bool:
        return true


func _make_grid() -> GridArena:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = Vector2i(8, 8)
    grid.starting_land_size = Vector2i(8, 8)
    grid.generate_grid()
    return grid


func test_dash_lands_on_the_farthest_open_cell_with_no_victims() -> void:
    var grid := _make_grid()
    var engine: TickEngine = autofree(TickEngine.new())
    var origin := Vector2i(2, 2)

    var plan := TickActionPlanner.compute_dash_plan(grid, engine, Vector2i(5, 2), origin, Vector2i.RIGHT, 5)

    assert_true(plan["legal"])
    assert_eq(plan["dir"], Vector2i.RIGHT)
    assert_eq(plan["landing"], Vector2i(5, 2))
    assert_true((plan["victims"] as Array).is_empty())


func test_dash_collects_a_victim_along_the_path_and_still_lands_past_it() -> void:
    var grid := _make_grid()
    var engine: TickEngine = autofree(TickEngine.new())
    var origin := Vector2i(2, 2)
    var victim: GridEnemy = autofree(FakeVictim.new())
    victim.set_grid_pos(Vector2i(4, 2))
    engine.register_actor(victim)

    var plan := TickActionPlanner.compute_dash_plan(grid, engine, Vector2i(7, 2), origin, Vector2i.RIGHT, 5)

    assert_true(plan["legal"])
    assert_eq(plan["landing"], Vector2i(7, 2), "dash lands past the victim on the farthest open cell")
    var victims: Array = plan["victims"]
    assert_eq(victims.size(), 1)
    assert_eq((victims[0] as GridEnemy).get_grid_pos(), Vector2i(4, 2))


func test_dash_is_illegal_when_the_only_reachable_cell_is_occupied() -> void:
    var grid := _make_grid()
    var engine: TickEngine = autofree(TickEngine.new())
    var origin := Vector2i(2, 2)
    var victim: GridEnemy = autofree(FakeVictim.new())
    victim.set_grid_pos(Vector2i(3, 2))
    engine.register_actor(victim)

    var plan := TickActionPlanner.compute_dash_plan(grid, engine, Vector2i(3, 2), origin, Vector2i.RIGHT, 1)

    assert_false(plan["legal"], "the only cell within range is occupied, so the dash has nowhere to land")
