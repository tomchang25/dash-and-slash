# test_guard.gd
# Focused lifecycle coverage for Stagger recovery and post-Stagger Guard protection timing.
extends GutTest

func test_refilled_guard_starts_protected_after_exact_stagger_duration() -> void:
    var guard := _make_guard()
    guard.take_guard_damage(32)

    assert_true(guard.is_staggered())
    for tick in 2:
        guard.advance_stagger()
        assert_true(guard.is_staggered())
        assert_false(guard.is_protected())

    guard.advance_stagger()
    assert_false(guard.is_staggered())
    assert_eq(guard.current(), 32)
    assert_true(guard.is_protected(), "the Stagger-ending tick begins protection without consuming it")


func test_refilled_guard_remains_protected_for_exactly_five_later_world_ticks() -> void:
    var guard := _make_guard()
    guard.take_guard_damage(32)
    for tick in 3:
        guard.advance_stagger()

    for tick in 5:
        assert_true(guard.is_protected(), "protection must be active before later world tick %d" % (tick + 1))
        guard.advance_protection()

    assert_false(guard.is_protected())


func test_disabled_guard_cannot_break_or_enter_stagger() -> void:
    var guard := _make_guard()
    guard.disable_guard()
    guard.take_guard_damage(32)

    assert_false(guard.is_enabled())
    assert_eq(guard.current(), 0)
    assert_false(guard.is_staggered())


func test_pool_reset_restores_a_profiled_guard_after_temporary_disable() -> void:
    var guard := _make_guard()
    guard.set_enabled(false)
    guard.reset()

    assert_true(guard.is_enabled())
    assert_eq(guard.current(), 32)


func _make_guard() -> Guard:
    var guard: Guard = autofree(Guard.new())
    guard.initialize(32, 3, 5, 0.5)
    return guard
