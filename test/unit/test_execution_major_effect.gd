# test_execution_major_effect.gd
# Tests the Execution artifact wire: applying it registers the artifact and activates the run's
# Execution mobility trigger without touching the mobility payload or the Guard Shredder trigger.
extends GutTest

func test_execution_apply_registers_artifact_and_activates_trigger() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var execution := _make_execution()

    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))
    assert_true(execution.is_eligible(context))
    run_build.acquire_artifact(execution, 1)
    execution.apply(context, 1)

    assert_eq(run_build.legendary_count(), 1)
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_eq(run_build.get_mobility_payload(), RunBuild.PAYLOAD_DASH)


func test_execution_cannot_be_offered_or_acquired_again_once_owned() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var first := _make_execution()
    var second := _make_execution()

    run_build.acquire_artifact(first, 1)

    assert_false(
        second.is_eligible(context),
        "an empty exclusivity group must not let the same artifact id be offered again",
    )
    assert_false(run_build.acquire_artifact(second, 1))
    assert_eq(run_build.legendary_count(), 1)


func test_execution_still_respects_the_legendary_cap() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)

    for i in RunBuild.LEGENDARY_CAP:
        var filler := _make_legendary("major_%d" % i, "")
        run_build.acquire_artifact(filler, 1)

    var execution := _make_execution()

    assert_false(execution.is_eligible(context), "cap reached should reject Execution regardless of its group")
    assert_false(run_build.acquire_artifact(execution, 1))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))


func _make_execution() -> Artifact:
    return Artifact.new(
        &"execution",
        "Execution",
        "Dash hits on staggered targets kill instantly (%d)",
        Artifact.Rarity.LEGENDARY,
        1,
        &"",
        false,
        2,
        -4,
        1.0,
        [WaveRewardChoiceGenerator.Profile.AGGRESSIVE],
        [TriggerArtifactEffect.new(RunBuild.TRIGGER_EXECUTION)],
    )


func _make_legendary(id: StringName, exclusivity_group: StringName) -> Artifact:
    return Artifact.new(
        id,
        "Major Placeholder",
        "Major placeholder (%d)",
        Artifact.Rarity.LEGENDARY,
        1,
        exclusivity_group,
        false,
        2,
        -4,
        1.0,
        [WaveRewardChoiceGenerator.Profile.AGGRESSIVE],
        [],
    )
