# tick_input.gd
# Verb input layer for the tick arena: polls the command-style grammar every frame (mouse aims for
# free, holding Alt enters Mobility Mode and releasing it returns to Attack Mode, left click confirms
# the active mode, right click cancels), repeats held movement/wait/confirm at the flow cadence, and
# emits verb_requested without knowing anything about legality or mode meaning — the scene root
# validates, interprets, and executes. Mouse-button verbs are suppressed while the cursor hovers any
# HUD Control (debug panel, confirm popup, etc.), since Input's raw button state ignores Godot's GUI
# input consumption chain and would otherwise fire a game verb from the same click that pressed a button.
class_name TickInput
extends Node

signal verb_requested(verb: TickVerb)

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
var _alt_was_pressed := false
var _rmb_was_pressed := false
var _space_was_pressed := false

# == Lifecycle ==


func _process(delta: float) -> void:
    var alt_pressed := Input.is_physical_key_pressed(KEY_ALT)
    var rmb_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
    var space_pressed := Input.is_physical_key_pressed(KEY_SPACE)
    var mouse_over_ui := get_viewport().gui_get_hovered_control() != null

    var verb := _edge_verb(alt_pressed, rmb_pressed, space_pressed, mouse_over_ui)
    if verb != null:
        verb_requested.emit(verb)
        _repeat_timer = HOLD_REPEAT_SEC
    else:
        var held := _held_verb(space_pressed, mouse_over_ui)
        if held == null:
            _repeat_timer = 0.0
        else:
            _repeat_timer -= delta
            if _repeat_timer <= 0.0:
                verb_requested.emit(held)
                _repeat_timer = HOLD_REPEAT_SEC

    _alt_was_pressed = alt_pressed
    _rmb_was_pressed = rmb_pressed
    _space_was_pressed = space_pressed

# == Verb polling ==


func _edge_verb(alt_pressed: bool, rmb_pressed: bool, space_pressed: bool, mouse_over_ui: bool) -> TickVerb:
    if alt_pressed != _alt_was_pressed:
        return TickVerb.mode_set(alt_pressed)
    if rmb_pressed and not _rmb_was_pressed and not mouse_over_ui:
        return TickVerb.cancel()
    for action: String in MOVE_ACTIONS:
        if Input.is_action_just_pressed(action):
            return TickVerb.move(MOVE_ACTIONS[action])
    if Input.is_action_just_pressed("attack") and not mouse_over_ui:
        return TickVerb.confirm()
    if space_pressed and not _space_was_pressed:
        return TickVerb.wait()
    return null


func _held_verb(space_pressed: bool, mouse_over_ui: bool) -> TickVerb:
    for action: String in MOVE_ACTIONS:
        if Input.is_action_pressed(action):
            return TickVerb.move(MOVE_ACTIONS[action])
    if Input.is_action_pressed("attack") and not mouse_over_ui:
        return TickVerb.confirm(true)
    if space_pressed:
        return TickVerb.wait()
    return null
