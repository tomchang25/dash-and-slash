# test_execution_major_effect.gd
# Tests the Execution Major-effect wire: applying it registers the Major and activates the run's
# Execution mobility trigger without touching the mobility payload or the Guard Shredder trigger.
extends GutTest

func test_execution_apply_registers_major_and_activates_trigger() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var execution := _make_execution()

    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))
    assert_true(execution.is_applicable(context))
    execution.apply(context, 1)

    assert_eq(run_build.major_count(), 1)
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_eq(run_build.get_mobility_payload(), RunBuild.PAYLOAD_DASH)


func test_execution_still_respects_the_four_major_cap() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)

    for i in RunBuild.MAJOR_CAP:
        var filler := _make_major("major_%d" % i, "")
        filler.apply(context, 1)

    var execution := _make_execution()

    assert_false(execution.is_applicable(context), "cap reached should reject Execution regardless of its group")
    assert_false(run_build.add_major(execution.effect_id, execution.exclusivity_group))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))


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


func _make_major(effect_id: String, exclusivity_group: String) -> MajorPlaceholderEffect:
    return MajorPlaceholderEffect.new(
        effect_id,
        "Major Placeholder",
        "Major placeholder (%d)",
        -4,
        1.0,
        1,
        2,
        [WaveRewardEffectDefinition.Profile.AGGRESSIVE],
        exclusivity_group,
    )
