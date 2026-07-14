# test_tick_hit_resolver_dash_triggers.gd
# Tests the Guard Shredder and Execution mobility-slot-trigger seam on TickHitResolver's pure
# resolution math, independent of RunBuild or the arena scene: the same resolve_precomputed()/
# resolve_hit() paths previews and commits both call, so a passing test here guarantees preview/commit
# honesty for both effects when the Ninja's fixed Dash Mobility is active.
# The resolve_hit() tests below use a Smash-shaped call (a landing cell as attacker_origin_cell, not
# adjacent to the victim's own travel path) to prove the angle-from-origin math is action-agnostic.
extends GutTest

func test_guard_shredder_zeroes_guard_and_staggers_on_back_hit() -> void:
    var snapshot := _snapshot(50, 20, false)

    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.BACK, 8, snapshot, 30.0, true, false)

    assert_true(outcome.guard_broken)
    assert_eq(outcome.guard_damage, 20, "guard shredder should zero the full 20 guard, not the 8 the back table would deal")
    assert_eq(outcome.major_trigger, TickHitOutcome.MajorTrigger.GUARD_SHREDDER)


func test_guard_shredder_does_not_trigger_off_back_angle() -> void:
    var snapshot := _snapshot(50, 20, false)

    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.SIDE, 5, snapshot, 30.0, true, false)

    assert_false(outcome.guard_broken, "side angle should keep the normal table, not shred")
    assert_eq(outcome.guard_damage, 5)
    assert_eq(outcome.major_trigger, TickHitOutcome.MajorTrigger.NONE)


func test_guard_shredder_does_not_retrigger_on_already_staggered_target() -> void:
    var snapshot := _snapshot(50, 0, true)

    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.BACK, 8, snapshot, 30.0, true, false)

    assert_eq(outcome.major_trigger, TickHitOutcome.MajorTrigger.NONE)


func test_protected_normal_hit_halves_guard_damage_without_changing_hp_damage() -> void:
    var snapshot := _snapshot(100, 4, false)
    snapshot["guard_protection_multiplier"] = 0.5

    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.FRONT, 4, snapshot, 20.0)

    assert_eq(outcome.guard_damage, 2)
    assert_false(outcome.guard_broken)
    assert_eq(outcome.hp_damage, 4.0, "protection affects Guard only; regular blocked HP damage stays unchanged")


func test_protected_mobility_hit_halves_guard_damage_without_changing_hp_damage() -> void:
    var snapshot := _snapshot(100, 16, false)
    snapshot["guard_protection_multiplier"] = 0.5

    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.SIDE, 16, snapshot, 30.0)

    assert_eq(outcome.guard_damage, 8)
    assert_false(outcome.guard_broken)
    assert_eq(outcome.hp_damage, 6.0)


func test_guard_shredder_bypasses_protected_guard_damage() -> void:
    var snapshot := _snapshot(100, 16, false)
    snapshot["guard_protection_multiplier"] = 0.5

    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.BACK, 32, snapshot, 30.0, true)

    assert_true(outcome.guard_broken)
    assert_eq(outcome.guard_damage, 16)


func test_guardless_target_takes_direct_hp_damage_without_guard_break() -> void:
    var snapshot := _snapshot(100, 0, false)
    snapshot["has_guard"] = false

    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.FRONT, 4, snapshot, 20.0)

    assert_eq(outcome.guard_damage, 4)
    assert_false(outcome.guard_broken)
    assert_false(outcome.was_guarded)
    assert_eq(outcome.hp_damage, 20.0)


func test_mobility_stagger_burst_applies_mobility_multiplier() -> void:
    var snapshot := _snapshot(100, 0, true)

    var outcome := TickHitResolver.resolve_precomputed(
        TileDirectionResolver.HitAngle.SIDE,
        0,
        snapshot,
        30.0,
        false,
        false,
        TickCombatRules.STAGGER_MOBILITY_MULTIPLIER,
    )

    assert_true(outcome.stagger_burst)
    assert_eq(outcome.hp_damage, 60.0)


func test_execution_kills_instantly_on_already_staggered_dash_hit() -> void:
    var snapshot := _snapshot(50, 0, true)

    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.SIDE, 4, snapshot, 1.0, false, true)

    assert_true(outcome.killed, "execution should kill regardless of how small base_damage is")
    assert_eq(outcome.major_trigger, TickHitOutcome.MajorTrigger.EXECUTION)


func test_execution_does_not_trigger_without_stagger() -> void:
    var snapshot := _snapshot(50, 20, false)

    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.FRONT, 8, snapshot, 1.0, false, true)

    assert_false(outcome.killed)
    assert_eq(outcome.major_trigger, TickHitOutcome.MajorTrigger.NONE)


func test_execution_takes_priority_over_guard_shredder_on_staggered_target() -> void:
    var snapshot := _snapshot(50, 0, true)

    var outcome := TickHitResolver.resolve_precomputed(TileDirectionResolver.HitAngle.BACK, 8, snapshot, 1.0, true, true)

    assert_true(outcome.killed)
    assert_eq(outcome.major_trigger, TickHitOutcome.MajorTrigger.EXECUTION)


func test_guard_shredder_triggers_from_a_smash_style_landing_origin() -> void:
    # Target at (5, 5) facing RIGHT; a Smash landing one cell to its LEFT is a back-angle hit even
    # though the origin is a locked landing cell, not "victim cell minus dash direction".
    var snapshot := _facing_snapshot(Vector2i(5, 5), Vector2i(1, 0), 50, 20, false)
    var landing := Vector2i(4, 5)

    var outcome := TickHitResolver.resolve_hit(landing, snapshot, 30.0, -1, true, false)

    assert_eq(outcome.angle, TileDirectionResolver.HitAngle.BACK)
    assert_true(outcome.guard_broken)
    assert_eq(outcome.guard_damage, 20)
    assert_eq(outcome.major_trigger, TickHitOutcome.MajorTrigger.GUARD_SHREDDER)


func test_execution_triggers_from_a_smash_style_landing_origin_on_staggered_target() -> void:
    var snapshot := _facing_snapshot(Vector2i(5, 5), Vector2i(1, 0), 50, 0, true)
    var landing := Vector2i(5, 4)

    var outcome := TickHitResolver.resolve_hit(landing, snapshot, 1.0, -1, false, true)

    assert_true(outcome.killed)
    assert_eq(outcome.major_trigger, TickHitOutcome.MajorTrigger.EXECUTION)


func _facing_snapshot(cell: Vector2i, facing: Vector2i, hp: float, guard_current: int, staggered: bool) -> Dictionary:
    var snapshot := _snapshot(hp, guard_current, staggered)
    snapshot["cell"] = cell
    snapshot["facing"] = facing
    return snapshot


func _snapshot(hp: float, guard_current: int, staggered: bool) -> Dictionary:
    return {
        "cell": Vector2i.ZERO,
        "facing": Vector2i.ZERO,
        "has_guard": true,
        "guard_current": guard_current,
        "guard_max": 40,
        "staggered": staggered,
        "hp": hp,
        "hp_max": hp,
        "defense": 0.0,
        "alive": true,
    }
