# test_chain_dash_major_effect.gd
# Tests the Dash-only Chain Dash artifact eligibility and trigger application.
extends GutTest

func test_chain_dash_applies_for_dash_context() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build, CharacterClassData.MOBILITY_DASH)
    var chain_dash := _make_chain_dash()

    assert_true(chain_dash.is_eligible(context))
    assert_true(run_build.acquire_artifact(chain_dash, 1))
    chain_dash.apply(context, 1)

    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_CHAIN_DASH))
    assert_eq(run_build.legendary_count(), 1)


func test_chain_dash_is_ineligible_for_smash_context() -> void:
    var chain_dash := _make_chain_dash()
    var context := WaveRewardContext.new(null, RunBuild.new(), CharacterClassData.MOBILITY_SMASH)

    assert_false(chain_dash.is_eligible(context))


func test_chain_dash_cannot_be_offered_twice_once_owned() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build, CharacterClassData.MOBILITY_DASH)
    var first := _make_chain_dash()
    var second := _make_chain_dash()

    run_build.acquire_artifact(first, 1)

    assert_false(second.is_eligible(context))


func _make_chain_dash() -> Artifact:
    var effect := TriggerArtifactEffect.new()
    effect.trigger = RunBuild.TRIGGER_CHAIN_DASH

    var artifact := Artifact.new()
    artifact.id = &"chain_dash"
    artifact.display_name = "Chain Dash"
    artifact.description_template = "Qualifying Dash hits clear Dash cooldown and ready your next move or attack (%d)"
    artifact.rarity = Artifact.Rarity.LEGENDARY
    artifact.min_wave = 2
    artifact.magnitude = 1.0
    artifact.required_mobility = CharacterClassData.MOBILITY_DASH
    artifact.effects = [effect]
    return artifact
