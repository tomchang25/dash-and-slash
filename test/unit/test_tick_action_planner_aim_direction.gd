# test_tick_action_planner_aim_direction.gd
# Tests TickActionPlanner.aim_direction(): the shared aim resolution the tick arena's action and
# preview controllers both call, so an ambiguous mouse delta falls back to the same last-aim value
# on both sides of the ownership boundary.
extends GutTest

func test_returns_the_dominant_orthogonal_direction() -> void:
    assert_eq(TickActionPlanner.aim_direction(Vector2i(5, 2), Vector2i(2, 2), Vector2i.UP), Vector2i.RIGHT)


func test_falls_back_to_last_aim_when_mouse_delta_is_zero() -> void:
    assert_eq(TickActionPlanner.aim_direction(Vector2i(2, 2), Vector2i(2, 2), Vector2i.UP), Vector2i.UP)


func test_falls_back_to_last_aim_when_mouse_delta_is_perfectly_diagonal() -> void:
    assert_eq(TickActionPlanner.aim_direction(Vector2i(5, 5), Vector2i(2, 2), Vector2i.LEFT), Vector2i.LEFT)
