# test_run_build_reset.gd
# Tests RunBuild.clear() as the sole production restart path (Tick Arena Consolidation 03):
# a single clear() call must drop channel entries, Major records, the mobility payload override,
# and mobility triggers together, exactly as a fresh RunBuild instance would start out.
extends GutTest

func test_clear_resets_entries_majors_payload_override_and_triggers_together() -> void:
    var run_build := RunBuild.new()
    run_build.record(RunBuild.CH_MAX_HEALTH, 20.0)
    run_build.record(RunBuild.CH_SPEED, 5.0)
    run_build.add_major("major_a", "")
    run_build.set_mobility_payload_override(RunBuild.PAYLOAD_SMASH)
    run_build.set_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER, true)

    run_build.clear()

    assert_eq(run_build.total(RunBuild.CH_MAX_HEALTH), 0.0, "clear() drops recorded channel entries")
    assert_eq(run_build.total(RunBuild.CH_SPEED), 0.0, "clear() drops recorded channel entries")
    assert_eq(run_build.major_count(), 0, "clear() drops Major records")
    assert_false(run_build.has_major("major_a"), "clear() drops Major records")
    assert_eq(run_build.get_mobility_payload(), RunBuild.PAYLOAD_DASH, "clear() resets the mobility payload override to the Dash default")
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER), "clear() drops mobility triggers")
