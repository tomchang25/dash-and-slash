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
    return _make_channel_artifact(&"speed_up", "Fleet Step", "+%d Speed", 5, RunBuild.CH_SPEED, 1.0)


func _make_mobility_cooldown_artifact() -> Artifact:
    return _make_channel_artifact(&"mobility_cooldown_down", "Light Footwork", "-%d mobility cooldown (ticks)", 3, RunBuild.CH_MOBILITY_COOLDOWN, 1.0)


func _make_channel_artifact(id: StringName, display_name: String, description_template: String, max_stacks: int, channel: StringName, magnitude: float) -> Artifact:
    var effect := ChannelArtifactEffect.new()
    effect.channel = channel
    effect.amount = magnitude

    var artifact := Artifact.new()
    artifact.id = id
    artifact.display_name = display_name
    artifact.description_template = description_template
    artifact.max_stacks = max_stacks
    artifact.magnitude = magnitude
    artifact.effects = [effect]
    return artifact
