class_name State
extends Node

signal transition_requested(from: State, to: int)

@export var state_id: int = -1

## If false, external request_transition() calls on StateMachine are ignored.
## Use this for states that must run to completion (e.g. HEAVY_ATTACK).
## Internal change_state() from within the state itself is always allowed.
@export var interruptible: bool = true
@export var debug_enabled: bool = false
var _locked := false


func _ready() -> void:
    if state_id == -1:
        ToastManager.show_dev_error("State must have a state_id")


func _enter() -> void:
    pass


func _exit() -> void:
    pass


func _update(_delta: float) -> void:
    pass


func _physics_update(_delta: float) -> void:
    pass


## Tick-driven update hook. Called once per external tick advance instead of per frame,
## for state machines whose owner is clocked by a discrete tick engine rather than frame time.
func _advance_tick() -> void:
    pass


func enter() -> void:
    _locked = false
    if debug_enabled:
        print("State %s entered" % name)
    _enter()


func exit() -> void:
    _locked = true
    _exit()


func update(delta: float) -> void:
    if _locked:
        return
    _update(delta)


func physics_update(delta: float) -> void:
    if _locked:
        return
    _physics_update(delta)


## Advances this state by exactly one external tick. Ignored while locked (mid-transition),
## mirroring update()/physics_update().
func advance_tick() -> void:
    if _locked:
        return
    _advance_tick()


## Called by the state itself to move to the next state.
## This is the ONLY way a state should trigger its own transitions.
## External systems must use StateMachine.request_transition() instead.
func change_state(to: int) -> void:
    if _locked:
        ToastManager.show_dev_error("State '%s' tried change_state(%s) while locked — called from _exit()? Ignoring." % [name, to])
        return
    if to == state_id:
        return

    _locked = true
    transition_requested.emit(self, to)
