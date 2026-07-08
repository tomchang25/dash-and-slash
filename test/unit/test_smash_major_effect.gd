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
    return Artifact.new(
        &"smash",
        "Smash",
        "Replace Dash with an area leap-and-slam (%d)",
        Artifact.Rarity.LEGENDARY,
        1,
        WaveRewardChoiceGenerator.SMASH_EXCLUSIVITY_GROUP,
        false,
        2,
        1.0,
        [PayloadArtifactEffect.new(RunBuild.PAYLOAD_SMASH)],
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
        1.0,
        [],
    )
