# test_run_build_dash_triggers.gd
# Tests RunBuild's Dash Major triggers directly: activation, independent toggling, and reset.
extends GutTest

func test_mobility_triggers_default_inactive() -> void:
    var run_build := RunBuild.new()

    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_CHAIN_DASH))


func test_mobility_triggers_activate_independently() -> void:
    var run_build := RunBuild.new()

    run_build.set_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER, true)

    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_CHAIN_DASH))

    run_build.set_mobility_trigger(RunBuild.TRIGGER_EXECUTION, true)

    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_CHAIN_DASH))

    run_build.set_mobility_trigger(RunBuild.TRIGGER_CHAIN_DASH, true)

    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_CHAIN_DASH))

    run_build.set_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER, false)

    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))
    assert_true(run_build.has_mobility_trigger(RunBuild.TRIGGER_CHAIN_DASH))


func test_clear_resets_mobility_triggers() -> void:
    var run_build := RunBuild.new()
    run_build.set_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER, true)
    run_build.set_mobility_trigger(RunBuild.TRIGGER_EXECUTION, true)
    run_build.set_mobility_trigger(RunBuild.TRIGGER_CHAIN_DASH, true)

    run_build.clear()

    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION))
    assert_false(run_build.has_mobility_trigger(RunBuild.TRIGGER_CHAIN_DASH))


func test_unknown_mobility_trigger_is_rejected() -> void:
    var run_build := RunBuild.new()

    run_build.set_mobility_trigger(&"not_a_real_trigger", true)

    assert_false(run_build.has_mobility_trigger(&"not_a_real_trigger"))
    assert_push_error("RunBuild: unknown mobility trigger not_a_real_trigger")
