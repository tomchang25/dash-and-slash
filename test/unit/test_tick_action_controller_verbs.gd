# test_tick_action_controller_verbs.gd
# Tests TickActionController's mode_set verb handling and message state directly: default aim mode,
# mode_set toggling between Attack and Mobility, and the set/current message pair. These paths touch
# no exported scene dependency (grid/view/engine/player), so the controller can be exercised without
# a scene tree per Phase 6b's ownership split (mode and message are the action controller's own state).
extends GutTest

func test_default_aim_mode_is_attack() -> void:
    var controller: TickActionController = autofree(TickActionController.new())

    assert_eq(controller.aim_mode_name(), "ATTACK")
    assert_false(controller.is_mobility_mode())


func test_mode_set_verb_switches_to_mobility_and_back() -> void:
    var controller: TickActionController = autofree(TickActionController.new())

    controller.handle_verb({ "type": "mode_set", "mobility": true })
    assert_eq(controller.aim_mode_name(), "MOBILITY")
    assert_true(controller.is_mobility_mode())

    controller.handle_verb({ "type": "mode_set", "mobility": false })
    assert_eq(controller.aim_mode_name(), "ATTACK")
    assert_false(controller.is_mobility_mode())


func test_default_last_aim_is_right() -> void:
    var controller: TickActionController = autofree(TickActionController.new())

    assert_eq(controller.get_last_aim(), Vector2i.RIGHT)


func test_message_starts_empty_and_set_message_updates_it() -> void:
    var controller: TickActionController = autofree(TickActionController.new())

    assert_eq(controller.current_message(), "")

    controller.set_message("Whiff.")

    assert_eq(controller.current_message(), "Whiff.")
