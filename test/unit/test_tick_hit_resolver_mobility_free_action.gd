# test_tick_hit_resolver_mobility_free_action.gd
# Tests TickHitResolver's Mobility Free Action Major refund-condition helpers on typed outcomes,
# independent of RunBuild or the arena scene: a kill, a guard break, or a back-angle hit
# each qualify alone, a front/side hit with neither does not, and any_qualifies_for_mobility_free_action()
# folds a mobility strike's multiple victim outcomes into the single per-action refund flag TickArena reads.
extends GutTest

func test_kill_outcome_qualifies() -> void:
    var snapshot := _snapshot(10.0, 0, false, false)

    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.FRONT, 0, snapshot, 100.0)

    assert_true(outcome.killed)
    assert_true(TickHitResolver.qualifies_for_mobility_free_action(outcome))


func test_guard_break_outcome_qualifies() -> void:
    var snapshot := _snapshot(1000.0, 20, false, true)

    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.BACK, 20, snapshot, 30.0)

    assert_true(outcome.guard_broken)
    assert_false(outcome.killed)
    assert_true(TickHitResolver.qualifies_for_mobility_free_action(outcome))


func test_back_angle_hit_qualifies_even_without_kill_or_guard_break() -> void:
    # Target already staggered, so full damage lands but there is no guard left to break.
    var snapshot := _snapshot(1000.0, 0, true, true)

    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.BACK, 0, snapshot, 10.0)

    assert_false(outcome.killed)
    assert_false(outcome.guard_broken)
    assert_eq(outcome.angle, TileDirectionResolver.HitAngle.BACK)
    assert_true(TickHitResolver.qualifies_for_mobility_free_action(outcome))


func test_front_hit_with_no_kill_or_guard_break_does_not_qualify() -> void:
    var snapshot := _snapshot(1000.0, 20, false, true)

    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.FRONT, 5, snapshot, 10.0)

    assert_false(outcome.killed)
    assert_false(outcome.guard_broken)
    assert_false(TickHitResolver.qualifies_for_mobility_free_action(outcome))


func test_side_hit_with_no_kill_or_guard_break_does_not_qualify() -> void:
    var snapshot := _snapshot(1000.0, 20, false, true)

    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.SIDE, 5, snapshot, 10.0)

    assert_false(TickHitResolver.qualifies_for_mobility_free_action(outcome))


func test_empty_outcome_does_not_qualify() -> void:
    assert_false(TickHitResolver.qualifies_for_mobility_free_action(TickHitResolver.empty_outcome()))


func test_any_qualifies_is_false_for_an_empty_outcome_list() -> void:
    var outcomes: Array[TickHitOutcome] = []

    assert_false(TickHitResolver.any_qualifies_for_mobility_free_action(outcomes), "an empty mobility action (no victims) never refunds")


func test_any_qualifies_is_true_when_one_of_several_outcomes_qualifies() -> void:
    var non_qualifying := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.FRONT, 5, _snapshot(1000.0, 20, false, true), 10.0)
    var qualifying := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.FRONT, 0, _snapshot(10.0, 0, false, false), 100.0)
    var outcomes: Array[TickHitOutcome] = [non_qualifying, qualifying]

    assert_true(TickHitResolver.any_qualifies_for_mobility_free_action(outcomes), "a mobility action that hits several targets refunds if any one of them qualifies")


func test_any_qualifies_is_false_when_no_outcome_qualifies() -> void:
    var first := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.FRONT, 5, _snapshot(1000.0, 20, false, true), 10.0)
    var second := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.SIDE, 5, _snapshot(1000.0, 20, false, true), 10.0)
    var outcomes: Array[TickHitOutcome] = [first, second]

    assert_false(TickHitResolver.any_qualifies_for_mobility_free_action(outcomes))


func _snapshot(hp: float, guard_current: int, staggered: bool, has_guard: bool) -> Dictionary:
    return {
        "cell": Vector2i.ZERO,
        "facing": Vector2i.ZERO,
        "has_guard": has_guard,
        "guard_current": guard_current,
        "guard_max": 40,
        "staggered": staggered,
        "hp": hp,
        "hp_max": hp,
        "defense": 0.0,
        "alive": true,
    }
