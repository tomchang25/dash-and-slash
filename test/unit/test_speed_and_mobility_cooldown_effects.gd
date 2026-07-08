# test_speed_and_mobility_cooldown_effects.gd
# Tests the Speed and Mobility Cooldown common channel artifacts: both are always eligible (no
# grid dependency) and record their stacked contribution to RunBuild's dedicated channel, the same
# RunBuild-projection pattern the enemy-pressure artifacts use.
extends GutTest

func test_speed_artifact_is_always_eligible() -> void:
    var artifact := _make_speed_artifact()
    var context := WaveRewardContext.new(null, RunBuild.new())

    assert_true(artifact.is_eligible(context))


func test_speed_artifact_records_stacked_contribution_to_run_build_channel() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var artifact := _make_speed_artifact()

    artifact.apply(context, 3)

    assert_eq(run_build.total(RunBuild.CH_SPEED), 3.0)


func test_speed_artifact_stacks_across_multiple_applications() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var artifact := _make_speed_artifact()

    artifact.apply(context, 2)
    artifact.apply(context, 1)

    assert_eq(run_build.total(RunBuild.CH_SPEED), 3.0)


func test_mobility_cooldown_artifact_is_always_eligible() -> void:
    var artifact := _make_mobility_cooldown_artifact()
    var context := WaveRewardContext.new(null, RunBuild.new())

    assert_true(artifact.is_eligible(context))


func test_mobility_cooldown_artifact_records_stacked_contribution_to_run_build_channel() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var artifact := _make_mobility_cooldown_artifact()

    artifact.apply(context, 2)

    assert_eq(run_build.total(RunBuild.CH_MOBILITY_COOLDOWN), 2.0)


func _make_speed_artifact() -> Artifact:
    return Artifact.new(
        &"speed_up",
        "Fleet Step",
        "+%d Speed",
        Artifact.Rarity.COMMON,
        5,
        &"",
        false,
        1,
        -1,
        1.0,
        [WaveRewardChoiceGenerator.Profile.CONSERVATIVE],
        [ChannelArtifactEffect.new(RunBuild.CH_SPEED, 1.0)],
    )


func _make_mobility_cooldown_artifact() -> Artifact:
    return Artifact.new(
        &"mobility_cooldown_down",
        "Light Footwork",
        "-%d mobility cooldown (ticks)",
        Artifact.Rarity.COMMON,
        3,
        &"",
        false,
        1,
        -1,
        1.0,
        [WaveRewardChoiceGenerator.Profile.CONSERVATIVE],
        [ChannelArtifactEffect.new(RunBuild.CH_MOBILITY_COOLDOWN, 1.0)],
    )
