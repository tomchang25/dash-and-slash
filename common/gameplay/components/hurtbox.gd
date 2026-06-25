# hurtbox.gd
# Component: the receiving side of combat. An Area2D that a Hitbox overlaps to deal
# damage. It forwards incoming hits to the entity's Health and re-broadcasts them as
# a signal so other components (hit-flash, knockback, audio) can react.
#
# Wiring: set `health` in the inspector, or leave it null to auto-find a Health
# sibling under the same owner in _ready().
class_name Hurtbox
extends Area2D

signal got_hit(amount: float, source: Node)

# ── Exports ─────────────────────────────────────────────────────────────────────

@export var health: Health

# ── State ─────────────────────────────────────────────────────────────────────

var _enabled: bool = true

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if health == null and owner != null:
        health = owner.find_child("Health", true, false) as Health

# ══ Common API ════════════════════════════════════════════════════════════════


## Called by an overlapping Hitbox. Applies damage to Health and re-broadcasts.
## No-op while disabled. [param source] is the attacker for attribution.
func receive_hit(amount: float, source: Node = null) -> void:
    if not _enabled:
        return
    if health != null:
        health.take_damage(amount, source)
    got_hit.emit(amount, source)

# ══ Pool lifecycle ════════════════════════════════════════════════════════════


func reset() -> void:
    _enabled = true
    set_deferred("monitoring", true)
    set_deferred("monitorable", true)


func set_enabled(value: bool) -> void:
    _enabled = value
    set_deferred("monitoring", value)
    set_deferred("monitorable", value)
