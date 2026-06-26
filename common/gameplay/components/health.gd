# health.gd
# Component: hit points for one entity. Owns its hp state and the only operations
# that change it. Communicates out via signals; never reaches into siblings.
# Lifecycle: reset() restores spawn defaults (pool acquire); set_enabled() toggles.
class_name Health
extends Node

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal died

# ── Exports ─────────────────────────────────────────────────────────────────────

@export var max_health: float = 100.0
@export var invuln_seconds: float = 0.0

# ── State ─────────────────────────────────────────────────────────────────────

var _current: float = 0.0
var _enabled: bool = true
var _invuln_until_msec: int = 0

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _current = max_health

# ══ Common API ════════════════════════════════════════════════════════════════


## Current hp. Read-only externally.
func current() -> float:
    return _current


func is_alive() -> bool:
    return _current > 0.0


func is_invulnerable() -> bool:
    return Time.get_ticks_msec() < _invuln_until_msec


## Applies [param amount] of damage from [param source]. No-op while disabled,
## dead, or invulnerable. Emits damaged + health_changed, and died on reaching 0.
func take_damage(amount: float, source: Node = null) -> void:
    if not _enabled or _current <= 0.0 or is_invulnerable():
        return
    if amount <= 0.0:
        return

    _current = max(_current - amount, 0.0)
    if invuln_seconds > 0.0:
        _invuln_until_msec = Time.get_ticks_msec() + int(invuln_seconds * 1000.0)
    damaged.emit(amount, source)
    health_changed.emit(_current, max_health)
    if _current <= 0.0:
        died.emit()


## Heals up to max. No-op while disabled or dead.
func heal(amount: float) -> void:
    if not _enabled or _current <= 0.0 or amount <= 0.0:
        return
    _current = min(_current + amount, max_health)
    health_changed.emit(_current, max_health)

# ══ Pool lifecycle ════════════════════════════════════════════════════════════


## Restores spawn defaults. Called on pool acquire.
func reset() -> void:
    _enabled = true
    _current = max_health
    _invuln_until_msec = 0
    health_changed.emit(_current, max_health)


## Cheap on/off without freeing. Called on pool release.
func set_enabled(value: bool) -> void:
    _enabled = value
