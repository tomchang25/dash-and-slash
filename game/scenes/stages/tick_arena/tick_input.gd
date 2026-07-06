# tick_input.gd
# Verb input layer for the tick arena: polls the two-channel grammar every frame (mouse aims for free,
# keys commit verbs), repeats held movement/attack/wait at the flow cadence, and emits verb_requested
# without knowing anything about legality — the scene root validates and executes.
class_name TickInput
extends Node

signal verb_requested(verb: Dictionary)

# -- Constants --

const HOLD_REPEAT_SEC := 0.14

const MOVE_ACTIONS := {
    "move_up": Vector2i.UP,
    "move_down": Vector2i.DOWN,
    "move_left": Vector2i.LEFT,
    "move_right": Vector2i.RIGHT,
}

# -- State --

var _repeat_timer := 0.0
var _rmb_was_pressed := false
var _space_was_pressed := false
var _escape_was_pressed := false

# == Lifecycle ==


func _process(delta: float) -> void:
    var rmb_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
    var space_pressed := Input.is_physical_key_pressed(KEY_SPACE)
    var escape_pressed := Input.is_physical_key_pressed(KEY_ESCAPE)

    var verb := _edge_verb(rmb_pressed, space_pressed, escape_pressed)
    if not verb.is_empty():
        verb_requested.emit(verb)
        _repeat_timer = HOLD_REPEAT_SEC
    else:
        var held := _held_verb(space_pressed)
        if held.is_empty():
            _repeat_timer = 0.0
        else:
            _repeat_timer -= delta
            if _repeat_timer <= 0.0:
                verb_requested.emit(held)
                _repeat_timer = HOLD_REPEAT_SEC

    _rmb_was_pressed = rmb_pressed
    _space_was_pressed = space_pressed
    _escape_was_pressed = escape_pressed

# == Verb polling ==


func _edge_verb(rmb_pressed: bool, space_pressed: bool, escape_pressed: bool) -> Dictionary:
    if escape_pressed and not _escape_was_pressed:
        return { "type": "mobility_cancel" }
    if not rmb_pressed and _rmb_was_pressed:
        return { "type": "mobility_release" }
    for action: String in MOVE_ACTIONS:
        if Input.is_action_just_pressed(action):
            return { "type": "move", "dir": MOVE_ACTIONS[action] }
    if Input.is_action_just_pressed("attack"):
        return { "type": "attack" }
    if rmb_pressed and not _rmb_was_pressed:
        return { "type": "mobility_press" }
    if space_pressed and not _space_was_pressed:
        return { "type": "wait" }
    return { }


func _held_verb(space_pressed: bool) -> Dictionary:
    for action: String in MOVE_ACTIONS:
        if Input.is_action_pressed(action):
            return { "type": "move", "dir": MOVE_ACTIONS[action] }
    if Input.is_action_pressed("attack"):
        return { "type": "attack" }
    if space_pressed:
        return { "type": "wait" }
    return { }
