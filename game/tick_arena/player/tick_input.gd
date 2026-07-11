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

const HOLD_REPEAT_SEC := 0.24
const CONFIRM_REPEAT_SEC := 0.32

const MOVE_ACTIONS := {
    "move_up": Vector2i.UP,
    "move_down": Vector2i.DOWN,
    "move_left": Vector2i.LEFT,
    "move_right": Vector2i.RIGHT,
}

# -- State --

var _repeat_timer := 0.0
var _confirm_cooldown := 0.0
var _alt_was_pressed := false
var _rmb_was_pressed := false
var _space_was_pressed := false
var _move_was_pressed := false

# == Lifecycle ==


func _process(delta: float) -> void:
    _confirm_cooldown = maxf(_confirm_cooldown - delta, 0.0)
    var alt_pressed := Input.is_physical_key_pressed(KEY_ALT)
    var rmb_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
    var space_pressed := Input.is_physical_key_pressed(KEY_SPACE)
    var mouse_over_ui := get_viewport().gui_get_hovered_control() != null
    var move_direction := _held_move_direction()

    var verb := _edge_verb(alt_pressed, rmb_pressed, space_pressed, mouse_over_ui, move_direction)
    if verb != null:
        verb_requested.emit(verb)
        _arm_verb_cadence(verb)
    else:
        var held := _held_verb(space_pressed, mouse_over_ui, move_direction)
        if held == null:
            _repeat_timer = 0.0
        else:
            _repeat_timer -= delta
            if _repeat_timer <= 0.0:
                verb_requested.emit(held)
                _arm_verb_cadence(held)

    _alt_was_pressed = alt_pressed
    _rmb_was_pressed = rmb_pressed
    _space_was_pressed = space_pressed
    _move_was_pressed = move_direction != Vector2i.ZERO

# == Verb polling ==


func _edge_verb(alt_pressed: bool, rmb_pressed: bool, space_pressed: bool, mouse_over_ui: bool, move_direction: Vector2i) -> TickVerb:
    if alt_pressed != _alt_was_pressed:
        return TickVerb.mode_set(alt_pressed)
    if rmb_pressed and not _rmb_was_pressed and not mouse_over_ui:
        return TickVerb.cancel()
    if move_direction != Vector2i.ZERO and not _move_was_pressed:
        return TickVerb.move(move_direction)
    if Input.is_action_just_pressed("attack") and not mouse_over_ui and _confirm_cooldown <= 0.0:
        return TickVerb.confirm()
    if space_pressed and not _space_was_pressed:
        return TickVerb.wait()
    return null


func _held_verb(space_pressed: bool, mouse_over_ui: bool, move_direction: Vector2i) -> TickVerb:
    if move_direction != Vector2i.ZERO:
        return TickVerb.move(move_direction)
    if Input.is_action_pressed("attack") and not mouse_over_ui and _confirm_cooldown <= 0.0:
        return TickVerb.confirm(true)
    if space_pressed:
        return TickVerb.wait()
    return null


## Resolves any held directional chord to one deterministic cardinal direction.
func _held_move_direction() -> Vector2i:
    for action: String in MOVE_ACTIONS:
        if Input.is_action_pressed(action):
            return MOVE_ACTIONS[action]
    return Vector2i.ZERO


## Arms the held-repeat timer and the release-resistant confirm cadence for one emitted verb.
func _arm_verb_cadence(verb: TickVerb) -> void:
    if verb.kind == TickVerb.Kind.CONFIRM:
        _repeat_timer = CONFIRM_REPEAT_SEC
        _confirm_cooldown = CONFIRM_REPEAT_SEC
    else:
        _repeat_timer = HOLD_REPEAT_SEC
