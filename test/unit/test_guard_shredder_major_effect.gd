# test_guard_shredder_major_effect.gd
# Tests the Guard Shredder artifact wire: applying it registers the artifact and activates the run's
# Guard Shredder mobility trigger without touching the mobility payload or the Execution trigger.
extends GutTest

func test_guard_shredder_apply_registers_artifact_and_activates_trigger() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var guard_shredder := _make_guard_shredder()

    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_true(guard_shredder.is_eligible(context))
    run_build.acquire_artifact(guard_shredder, 1)
    guard_shredder.apply(context, 1)

    assert_eq(run_build.legendary_count(), 1)
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))
    assert_eq(run_build.get_mobility_payload(), RunBuild.PAYLOAD_DASH)


func test_guard_shredder_cannot_be_offered_or_acquired_again_once_owned() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var first := _make_guard_shredder()
    var second := _make_guard_shredder()

    run_build.acquire_artifact(first, 1)

    assert_false(
        second.is_eligible(context),
        "an empty exclusivity group must not let the same artifact id be offered again",
    )
    assert_false(run_build.acquire_artifact(second, 1))
    assert_eq(run_build.legendary_count(), 1)


func test_guard_shredder_and_execution_can_both_be_active() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var guard_shredder := _make_guard_shredder()
    var execution := _make_execution()

    run_build.acquire_artifact(guard_shredder, 1)
    guard_shredder.apply(context, 1)
    run_build.acquire_artifact(execution, 1)
    execution.apply(context, 1)

    assert_eq(run_build.legendary_count(), 2)
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))


func _make_guard_shredder() -> Artifact:
    return _make_trigger_artifact(&"guard_shredder", "Guard Shredder", "Back-angle dash hits break guard instantly (%d)", RunBuild.TRIGGER_GUARD_SHREDDER)


func _make_execution() -> Artifact:
    return _make_trigger_artifact(&"execution", "Execution", "Dash hits on staggered targets kill instantly (%d)", RunBuild.TRIGGER_EXECUTION)


func _make_trigger_artifact(id: StringName, display_name: String, description_template: String, trigger: StringName) -> Artifact:
    var effect := TriggerArtifactEffect.new()
    effect.trigger = trigger

    var artifact := Artifact.new()
    artifact.id = id
    artifact.display_name = display_name
    artifact.description_template = description_template
    artifact.rarity = Artifact.Rarity.LEGENDARY
    artifact.max_stacks = 1
    artifact.min_wave = 2
    artifact.magnitude = 1.0
    artifact.effects = [effect]
    return artifact
