# guard.gd
# Component: guard / shield / stagger system. Owns the guard-point pool and
# stagger state. Communicates via signals. Has reset() / set_enabled() for
# pool lifecycle.
class_name Guard
extends Node

signal guard_changed(current: int, maximum: int)
signal guard_broken
signal stagger_started
signal stagger_ended

@export var max_guard: int = 4
@export var stagger_duration: float = 3.0

var _current: int = 0
var _staggered: bool = false
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


func _start_stagger() -> void:
    _staggered = true
    stagger_started.emit()
    get_tree().create_timer(stagger_duration).timeout.connect(_end_stagger)


func _end_stagger() -> void:
    _current = max_guard
    _staggered = false
    guard_changed.emit(_current, max_guard)
    stagger_ended.emit()


func reset() -> void:
    _enabled = true
    _staggered = false
    _current = max_guard
    guard_changed.emit(_current, max_guard)


func set_enabled(value: bool) -> void:
    _enabled = value
