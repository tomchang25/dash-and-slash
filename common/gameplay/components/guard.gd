# guard.gd
# Component: guard / shield / stagger system. Owns the guard-point pool and
# stagger state. Communicates via signals. Has reset() / set_enabled() for
# pool lifecycle.
# Stagger is a tick countdown driven by the owner's tick callback via advance_stagger()
# it is not a wall-clock timer, so displayed stagger windows stay honest in player actions.
class_name Guard
extends Node

signal guard_changed(current: int, maximum: int)
signal guard_broken
signal stagger_started
signal stagger_ended

@export var max_guard: int = 4
## Number of world ticks the enemy stays staggered after a guard break, counted down by advance_stagger().
@export var stagger_ticks: int = 3

var _current: int = 0
var _staggered: bool = false
var _stagger_remaining: int = 0
var _enabled: bool = true


func _ready() -> void:
    _current = max_guard


func current() -> int:
    return _current


func is_broken() -> bool:
    return _current <= 0


func is_staggered() -> bool:
    return _staggered


func take_guard_damage(amount: int) -> void:
    if not _enabled or _staggered or _current <= 0:
        return
    if amount <= 0:
        return
    _current = max(_current - amount, 0)
    guard_changed.emit(_current, max_guard)
    if _current <= 0:
        guard_broken.emit()
        _start_stagger()


## Counts the stagger window down by one world tick. Called by the owner's per-tick status pass.
## Refills guard and ends the stagger when the countdown reaches zero.
func advance_stagger() -> void:
    if not _staggered:
        return
    _stagger_remaining -= 1
    if _stagger_remaining <= 0:
        _end_stagger()


func _start_stagger() -> void:
    _staggered = true
    _stagger_remaining = stagger_ticks
    stagger_started.emit()


func _end_stagger() -> void:
    _current = max_guard
    _staggered = false
    _stagger_remaining = 0
    guard_changed.emit(_current, max_guard)
    stagger_ended.emit()


func reset() -> void:
    _enabled = true
    _staggered = false
    _stagger_remaining = 0
    _current = max_guard
    guard_changed.emit(_current, max_guard)


func set_enabled(value: bool) -> void:
    _enabled = value
