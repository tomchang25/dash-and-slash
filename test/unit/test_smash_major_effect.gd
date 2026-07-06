# test_smash_major_effect.gd
# Tests the Smash Major-effect wire: applying Smash swaps the run's mobility payload, and Smash
# shares its exclusivity group with a synthetic Chain Dash stand-in so only one can ever be active.
extends GutTest

func test_smash_apply_registers_major_and_swaps_mobility_payload() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var smash := _make_smash()

    assert_eq(run_build.get_mobility_payload(), RunBuild.PAYLOAD_DASH)
    assert_true(smash.is_applicable(context))
    smash.apply(context, 1)

    assert_eq(run_build.major_count(), 1)
    assert_eq(run_build.get_mobility_payload(), RunBuild.PAYLOAD_SMASH)


func test_smash_and_synthetic_chain_dash_are_mutually_exclusive() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var smash := _make_smash()
    var chain_dash := _make_major("chain_dash_synthetic", SmashMajorEffect.EXCLUSIVITY_GROUP)

    smash.apply(context, 1)

    assert_false(chain_dash.is_applicable(context), "a synthetic Chain Dash sharing Smash's group must be rejected")
    assert_false(run_build.add_major(chain_dash.effect_id, chain_dash.exclusivity_group))
    assert_eq(run_build.major_count(), 1)
    assert_eq(run_build.get_mobility_payload(), RunBuild.PAYLOAD_SMASH)


func test_smash_still_respects_the_four_major_cap() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)

    for i in RunBuild.MAJOR_CAP:
        var filler := _make_major("major_%d" % i, "")
        filler.apply(context, 1)

    var smash := _make_smash()

    assert_false(smash.is_applicable(context), "cap reached should reject Smash regardless of its group")
    assert_false(run_build.add_major(smash.effect_id, smash.exclusivity_group))


func _make_smash() -> SmashMajorEffect:
    return SmashMajorEffect.new(
        "smash",
        "Smash",
        "Replace Dash with an area leap-and-slam (%d)",
        -4,
        1.0,
        1,
        2,
        [WaveRewardEffectDefinition.Profile.AGGRESSIVE],
        SmashMajorEffect.EXCLUSIVITY_GROUP,
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
