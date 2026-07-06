# test_guard_shredder_major_effect.gd
# Tests the Guard Shredder Major-effect wire: applying it registers the Major and activates the run's
# Guard Shredder mobility trigger without touching the mobility payload or the Execution trigger.
extends GutTest

func test_guard_shredder_apply_registers_major_and_activates_trigger() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var guard_shredder := _make_guard_shredder()

    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_true(guard_shredder.is_applicable(context))
    guard_shredder.apply(context, 1)

    assert_eq(run_build.major_count(), 1)
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))
    assert_eq(run_build.get_mobility_payload(), RunBuild.PAYLOAD_DASH)


func test_guard_shredder_and_execution_can_both_be_active() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var guard_shredder := _make_guard_shredder()
    var execution := _make_execution()

    guard_shredder.apply(context, 1)
    execution.apply(context, 1)

    assert_eq(run_build.major_count(), 2)
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))


func _make_guard_shredder() -> GuardShredderMajorEffect:
    return GuardShredderMajorEffect.new(
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


func _make_execution() -> ExecutionMajorEffect:
    return ExecutionMajorEffect.new(
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
