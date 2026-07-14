# health.gd
# Combat health state for one actor. Owns hit points and the only operations that change them.
class_name Health
extends Node

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal died

## Debug-only survival modes. Off applies normal damage/death rules. Undead floors
## hp at 1 so death never fires. No-Damage plays hit feedback but never changes hp.
enum GodMode {
    OFF,
    UNDEAD,
    NO_DAMAGE,
}

# ── Exports ─────────────────────────────────────────────────────────────────────

@export var max_health: float = 100.0
@export var invuln_seconds: float = 0.0

# ── State ─────────────────────────────────────────────────────────────────────

var _current: float = 0.0
var _enabled: bool = true
var _invuln_until_msec: int = 0
var _god_mode: GodMode = GodMode.OFF

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _current = max_health

# ══ Common API ════════════════════════════════════════════════════════════════


## Configures max hp from authored data (e.g. EnemyData). Called once by the owner during setup,
## before any combat or pool-lifecycle operation. Distinct from reset(), which restores pool-acquire
## defaults from the max_health already configured here.
func initialize(max_value: float) -> void:
    max_health = max_value
    _current = max_health


## Current hp. Read-only externally.
func current() -> float:
    return _current


func is_alive() -> bool:
    return _current > 0.0


func is_invulnerable() -> bool:
    return Time.get_ticks_msec() < _invuln_until_msec


## Applies [param amount] of damage from [param source]. No-op while disabled,
## dead, or invulnerable. Emits damaged + health_changed, and died on reaching 0.
## Under god mode Undead, hp is floored at 1 and died never fires. Under
## No-Damage, damaged still emits for hit feedback but hp is left unchanged.
func take_damage(amount: float, source: Node = null) -> void:
    if not _enabled or _current <= 0.0 or is_invulnerable():
        return
    if amount <= 0.0:
        return

    if invuln_seconds > 0.0:
        _invuln_until_msec = Time.get_ticks_msec() + int(invuln_seconds * 1000.0)

    if _god_mode == GodMode.NO_DAMAGE:
        damaged.emit(amount, source)
        return

    _current = max(_current - amount, 0.0)
    if _god_mode == GodMode.UNDEAD:
        _current = max(_current, 1.0)
    damaged.emit(amount, source)
    health_changed.emit(_current, max_health)
    if _current <= 0.0:
        died.emit()


## Debug-only: instantly kills regardless of invulnerability. No-op while
## disabled, already dead, or god mode is Undead/No-Damage. Callers must guard
## with Debug.enabled (see debug_standard.md).
func kill() -> void:
    if not _enabled or _current <= 0.0 or _god_mode != GodMode.OFF:
        return
    _current = 0.0
    health_changed.emit(_current, max_health)
    died.emit()


## Debug-only: cycles Off -> Undead -> No-Damage -> Off and returns the new mode.
## Callers must guard with Debug.enabled (see debug_standard.md).
func cycle_god_mode() -> GodMode:
    match _god_mode:
        GodMode.OFF:
            _god_mode = GodMode.UNDEAD
        GodMode.UNDEAD:
            _god_mode = GodMode.NO_DAMAGE
        GodMode.NO_DAMAGE:
            _god_mode = GodMode.OFF
    return _god_mode


## Returns the active debug god mode.
func get_god_mode() -> GodMode:
    return _god_mode


## Heals up to max. No-op while disabled or dead.
func heal(amount: float) -> void:
    if not _enabled or _current <= 0.0 or amount <= 0.0:
        return
    _current = min(_current + amount, max_health)
    health_changed.emit(_current, max_health)


## Increases maximum hp and optionally heals by the same amount.
func add_max_health(amount: float, heal_by_amount := true) -> void:
    if amount <= 0.0:
        return
    max_health += amount
    if heal_by_amount:
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
