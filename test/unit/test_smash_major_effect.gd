# test_smash_major_effect.gd
# Tests the Smash artifact wire: applying Smash swaps the run's mobility payload, and Smash shares
# its exclusivity group with a synthetic Chain Dash stand-in so only one can ever be active.
extends GutTest

func test_smash_apply_registers_artifact_and_swaps_mobility_payload() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var smash := _make_smash()

    assert_eq(run_build.get_mobility_payload(), RunBuild.PAYLOAD_DASH)
    assert_true(smash.is_eligible(context))
    run_build.acquire_artifact(smash, 1)
    smash.apply(context, 1)

    assert_eq(run_build.legendary_count(), 1)
    assert_eq(run_build.get_mobility_payload(), RunBuild.PAYLOAD_SMASH)


func test_smash_and_synthetic_chain_dash_are_mutually_exclusive() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var smash := _make_smash()
    var chain_dash := _make_legendary("chain_dash_synthetic", WaveRewardChoiceGenerator.SMASH_EXCLUSIVITY_GROUP)

    run_build.acquire_artifact(smash, 1)
    smash.apply(context, 1)

    assert_false(chain_dash.is_eligible(context), "a synthetic Chain Dash sharing Smash's group must be rejected")
    assert_false(run_build.acquire_artifact(chain_dash, 1))
    assert_eq(run_build.legendary_count(), 1)
    assert_eq(run_build.get_mobility_payload(), RunBuild.PAYLOAD_SMASH)


func test_smash_still_respects_the_legendary_cap() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)

    for i in RunBuild.LEGENDARY_CAP:
        var filler := _make_legendary("major_%d" % i, "")
        run_build.acquire_artifact(filler, 1)

    var smash := _make_smash()

    assert_false(smash.is_eligible(context), "cap reached should reject Smash regardless of its group")
    assert_false(run_build.acquire_artifact(smash, 1))


func _make_smash() -> Artifact:
    var effect := PayloadArtifactEffect.new()
    effect.payload = RunBuild.PAYLOAD_SMASH

    var artifact := Artifact.new()
    artifact.id = &"smash"
    artifact.display_name = "Smash"
    artifact.description_template = "Replace Dash with an area leap-and-slam (%d)"
    artifact.rarity = Artifact.Rarity.LEGENDARY
    artifact.max_stacks = 1
    artifact.exclusivity_group = WaveRewardChoiceGenerator.SMASH_EXCLUSIVITY_GROUP
    artifact.min_wave = 2
    artifact.magnitude = 1.0
    artifact.effects = [effect]
    return artifact


func _make_legendary(id: StringName, exclusivity_group: StringName) -> Artifact:
    var artifact := Artifact.new()
    artifact.id = id
    artifact.display_name = "Major Placeholder"
    artifact.description_template = "Major placeholder (%d)"
    artifact.rarity = Artifact.Rarity.LEGENDARY
    artifact.max_stacks = 1
    artifact.exclusivity_group = exclusivity_group
    artifact.min_wave = 2
    artifact.magnitude = 1.0
    return artifact
