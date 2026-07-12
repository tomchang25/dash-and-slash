# test_tick_hit_resolver_chain_dash.gd
# Tests Chain Dash qualification and multi-victim single-state-application folding on typed hit outcomes.
extends GutTest

func test_kill_outcome_qualifies() -> void:
    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.FRONT, 0, _snapshot(10.0, 0, false, false), 100.0)

    assert_true(outcome.killed)
    assert_true(TickHitResolver.qualifies_for_chain_dash(outcome))


func test_guard_break_outcome_qualifies() -> void:
    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.FRONT, 20, _snapshot(1000.0, 20, false, true), 30.0)

    assert_true(outcome.guard_broken)
    assert_true(TickHitResolver.qualifies_for_chain_dash(outcome))


func test_back_angle_outcome_qualifies() -> void:
    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.BACK, 5, _snapshot(1000.0, 20, false, true), 10.0)

    assert_true(TickHitResolver.qualifies_for_chain_dash(outcome))


func test_already_staggered_outcome_qualifies_from_front() -> void:
    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.FRONT, 0, _snapshot(1000.0, 0, true, true), 10.0)

    assert_true(outcome.staggered)
    assert_true(TickHitResolver.qualifies_for_chain_dash(outcome))


func test_front_hit_without_special_outcome_does_not_qualify() -> void:
    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.FRONT, 5, _snapshot(1000.0, 20, false, true), 10.0)

    assert_false(TickHitResolver.qualifies_for_chain_dash(outcome))


func test_empty_outcome_does_not_qualify() -> void:
    assert_false(TickHitResolver.qualifies_for_chain_dash(TickHitResolver.empty_outcome()))


func test_any_qualifies_folds_multiple_victims_into_one_flag() -> void:
    var ordinary := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.FRONT, 5, _snapshot(1000.0, 20, false, true), 10.0)
    var staggered := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.FRONT, 0, _snapshot(1000.0, 0, true, true), 10.0)
    var outcomes: Array[TickHitOutcome] = [ordinary, staggered]

    assert_true(TickHitResolver.any_qualifies_for_chain_dash(outcomes))


func test_any_qualifies_returns_false_for_empty_outcomes() -> void:
    var outcomes: Array[TickHitOutcome] = []

    assert_false(TickHitResolver.any_qualifies_for_chain_dash(outcomes))


func test_any_qualifies_returns_false_when_no_victim_qualifies() -> void:
    var ordinary_a := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.FRONT, 5, _snapshot(1000.0, 20, false, true), 10.0)
    var ordinary_b := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.FRONT, 8, _snapshot(1000.0, 20, false, true), 10.0)
    var outcomes: Array[TickHitOutcome] = [ordinary_a, ordinary_b]

    assert_false(TickHitResolver.any_qualifies_for_chain_dash(outcomes))


func _snapshot(hp: float, guard_current: int, staggered: bool, has_guard: bool) -> Dictionary:
    return {
        "cell": Vector2i.ZERO,
        "facing": Vector2i.DOWN,
        "has_guard": has_guard,
        "guard_current": guard_current,
        "guard_max": 40,
        "staggered": staggered,
        "hp": hp,
        "hp_max": hp,
        "defense": 0.0,
        "alive": true,
    }
