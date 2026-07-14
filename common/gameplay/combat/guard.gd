# guard.gd
# Combat Guard state for one actor. Owns enabled, point, Stagger, and post-Stagger protection state.
class_name Guard
extends Node

signal guard_changed(current: int, maximum: int)
signal guard_broken
signal stagger_started
signal stagger_ended
signal protection_changed(protected: bool)

@export var max_guard: int = 4
## Number of world ticks the enemy stays staggered after a guard break, counted down by advance_stagger().
@export var stagger_ticks: int = 3
@export var protection_ticks: int = 5
@export var protection_multiplier := 0.5

var _current: int = 0
var _staggered: bool = false
var _stagger_remaining: int = 0
var _enabled: bool = true
var _has_guard: bool = true
var _protection_remaining: int = 0


func _ready() -> void:
    _current = max_guard if is_enabled() else 0


## Configures max guard from authored data (e.g. EnemyData). Called once by the owner during setup,
## before any combat or pool-lifecycle operation. Distinct from reset(), which restores pool-acquire
## defaults from the max_guard already configured here.
func initialize(max_value: int, stagger_duration: int = 3, protection_duration: int = 5, protection_factor: float = 0.5) -> void:
    max_guard = max_value
    stagger_ticks = stagger_duration
    protection_ticks = protection_duration
    protection_multiplier = protection_factor
    _has_guard = true
    _enabled = true
    _staggered = false
    _stagger_remaining = 0
    _protection_remaining = 0
    _current = max_guard


func current() -> int:
    return _current


func is_broken() -> bool:
    return _current <= 0


func is_staggered() -> bool:
    return _staggered


## Returns whether this actor has a live Guard component, rather than merely a reusable scene node.
func is_enabled() -> bool:
    return _has_guard and _enabled


## Returns whether refilled Guard is currently protected after Stagger recovery.
func is_protected() -> bool:
    return _enabled and _protection_remaining > 0


## Returns the snapshot multiplier for ordinary Guard damage.
func current_protection_multiplier() -> float:
    return protection_multiplier if is_protected() else 1.0


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


## Consumes one later world tick of post-Stagger protection. The Stagger-ending tick does not call this.
func advance_protection() -> void:
    if not is_protected():
        return
    _protection_remaining -= 1
    if _protection_remaining <= 0:
        _protection_remaining = 0
        protection_changed.emit(false)


func _start_stagger() -> void:
    _staggered = true
    _stagger_remaining = stagger_ticks
    stagger_started.emit()


func _end_stagger() -> void:
    _current = max_guard
    _staggered = false
    _stagger_remaining = 0
    _protection_remaining = protection_ticks
    guard_changed.emit(_current, max_guard)
    stagger_ended.emit()
    if _protection_remaining > 0:
        protection_changed.emit(true)


func reset() -> void:
    _enabled = _has_guard
    _staggered = false
    _stagger_remaining = 0
    _protection_remaining = 0
    _current = max_guard if is_enabled() else 0
    guard_changed.emit(_current, max_guard)
    protection_changed.emit(false)


func set_enabled(value: bool) -> void:
    _enabled = value and _has_guard
    _staggered = false
    _stagger_remaining = 0
    _protection_remaining = 0
    _current = max_guard if is_enabled() else 0
    guard_changed.emit(_current, max_guard)
    protection_changed.emit(false)


## Permanently configures this reusable scene component as guardless until a profile initializes it.
func disable_guard() -> void:
    _has_guard = false
    _enabled = false
    _staggered = false
    _stagger_remaining = 0
    _protection_remaining = 0
    _current = 0
    guard_changed.emit(_current, max_guard)
    protection_changed.emit(false)
