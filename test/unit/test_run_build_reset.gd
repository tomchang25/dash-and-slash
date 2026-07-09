# test_run_build_reset.gd
# Tests RunBuild.clear() as the sole production restart path (Tick Arena Consolidation 03):
# a single clear() call must drop channel entries, owned-artifact records, the mobility payload
# override, and mobility triggers together, exactly as a fresh RunBuild instance would start out.
extends GutTest

func test_clear_resets_entries_artifacts_payload_override_and_triggers_together() -> void:
    var run_build := RunBuild.new()
    var artifact := Artifact.new()
    artifact.id = &"major_a"
    artifact.display_name = "Major Placeholder"
    artifact.description_template = "Major placeholder (%d)"
    artifact.rarity = Artifact.Rarity.LEGENDARY
    artifact.max_stacks = 1
    artifact.min_wave = 2
    artifact.magnitude = 1.0
    run_build.record(RunBuild.CH_MAX_HEALTH, 20.0)
    run_build.record(RunBuild.CH_SPEED, 5.0)
    run_build.acquire_artifact(artifact, 1)
    run_build.set_mobility_payload_override(RunBuild.PAYLOAD_SMASH)
    run_build.set_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER, true)

    run_build.clear()

    assert_eq(run_build.total(RunBuild.CH_MAX_HEALTH), 0.0, "clear() drops recorded channel entries")
    assert_eq(run_build.total(RunBuild.CH_SPEED), 0.0, "clear() drops recorded channel entries")
    assert_eq(run_build.legendary_count(), 0, "clear() drops owned-artifact records")
    assert_false(run_build.has_artifact(&"major_a"), "clear() drops owned-artifact records")
    assert_eq(run_build.get_mobility_payload(), RunBuild.PAYLOAD_DASH, "clear() resets the mobility payload override to the Dash default")
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER), "clear() drops mobility triggers")
