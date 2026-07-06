# test_run_build_dash_triggers.gd
# Tests RunBuild's mobility-slot-triggered Major seam (Guard Shredder, Execution) directly:
# activation, independent toggling, and reset on clear(). The same trigger fires whichever payload
# (Dash or Smash) occupies the mobility slot; RunBuild itself is payload-agnostic.
extends GutTest

func test_mobility_triggers_default_inactive() -> void:
    var run_build := RunBuild.new()

    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))


func test_mobility_triggers_activate_independently() -> void:
    var run_build := RunBuild.new()

    run_build.set_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER, true)

    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))

    run_build.set_mobility_trigger(RunBuild.TRIGGER_EXECUTION, true)

    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))

    run_build.set_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER, false)

    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))


func test_clear_resets_mobility_triggers() -> void:
    var run_build := RunBuild.new()
    run_build.set_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER, true)
    run_build.set_mobility_trigger(RunBuild.TRIGGER_EXECUTION, true)

    run_build.clear()

    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))
