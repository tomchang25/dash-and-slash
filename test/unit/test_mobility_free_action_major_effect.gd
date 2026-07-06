# test_mobility_free_action_major_effect.gd
# Tests the Mobility Free Action Major-effect wire: applying it registers the Major and activates the
# run's Mobility Free Action mobility trigger without touching the mobility payload or the other
# mobility-slot triggers, and it can be owned alongside Guard Shredder and Execution.
extends GutTest

func test_mobility_free_action_apply_registers_major_and_activates_trigger() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var mobility_free_action := _make_mobility_free_action()

    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_MOBILITY_FREE_ACTION))
    assert_true(mobility_free_action.is_applicable(context))
    mobility_free_action.apply(context, 1)

    assert_eq(run_build.major_count(), 1)
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_MOBILITY_FREE_ACTION))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))
    assert_eq(run_build.get_mobility_payload(), RunBuild.PAYLOAD_DASH)


func test_mobility_free_action_cannot_be_offered_or_added_again_once_owned() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var first := _make_mobility_free_action()
    var second := _make_mobility_free_action()

    first.apply(context, 1)

    assert_false(
        second.is_applicable(context),
        "an empty exclusivity group must not let the same effect id be offered again",
    )
    assert_false(run_build.add_major(second.effect_id, second.exclusivity_group))
    assert_eq(run_build.major_count(), 1)


func test_mobility_free_action_can_be_active_alongside_guard_shredder_and_execution() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var mobility_free_action := _make_mobility_free_action()
    var guard_shredder := GuardShredderMajorEffect.new(
        "guard_shredder",
        "Guard Shredder",
        "Back-angle dash hits break guard instantly (%d)",
        -4,
        1.0,
        1,
        2,
        [WaveRewardEffectDefinition.Profile.AGGRESSIVE],
        "",
    )
    var execution := ExecutionMajorEffect.new(
        "execution",
        "Execution",
        "Dash hits on staggered targets kill instantly (%d)",
        -4,
        1.0,
        1,
        2,
        [WaveRewardEffectDefinition.Profile.AGGRESSIVE],
        "",
    )

    mobility_free_action.apply(context, 1)
    guard_shredder.apply(context, 1)
    execution.apply(context, 1)

    assert_eq(run_build.major_count(), 3)
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_MOBILITY_FREE_ACTION))
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))


func _make_mobility_free_action() -> MobilityFreeActionMajorEffect:
    return MobilityFreeActionMajorEffect.new(
        "mobility_free_action",
        "Flowing Strike",
        "Kill, guard-break, or back-angle mobility strikes skip world time (%d)",
        -4,
        1.0,
        1,
        2,
        [WaveRewardEffectDefinition.Profile.AGGRESSIVE],
        "",
    )
