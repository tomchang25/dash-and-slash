# test_tick_action_planner_smash_target.gd
# Tests TickActionPlanner.clamped_smash_target(): the shared Smash aim clamp the tick arena's action
# and preview controllers both call, clamping the mouse-aimed cell to a range box independently per axis.
extends GutTest

func test_leaves_target_unclamped_when_within_range() -> void:
    assert_eq(TickActionPlanner.clamped_smash_target(Vector2i(3, 1), Vector2i(2, 2), 3), Vector2i(3, 1))


func test_clamps_mouse_cell_to_the_max_range() -> void:
    assert_eq(TickActionPlanner.clamped_smash_target(Vector2i(10, 2), Vector2i(2, 2), 3), Vector2i(5, 2))


func test_clamps_independently_per_axis() -> void:
    assert_eq(TickActionPlanner.clamped_smash_target(Vector2i(10, -10), Vector2i(0, 0), 3), Vector2i(3, -3))
