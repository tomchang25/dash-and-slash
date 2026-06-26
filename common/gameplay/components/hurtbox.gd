# hurtbox.gd
# Component: the receiving side of combat. An Area2D that a Hitbox overlaps to
# broadcast a hit_received signal. Health, guard, and damage rules are handled
# by the entity's parent script — Hurtbox is a pure event bridge.
class_name Hurtbox
extends Area2D

signal hit_received(amount: float, source: Node, guard_damage_profile: int)

# ── State ─────────────────────────────────────────────────────────────────────

var _enabled: bool = true

# ══ Common API ════════════════════════════════════════════════════════════════


## Called by an overlapping Hitbox. No-op while disabled.
## [param source] is the attacker for attribution.
## [param guard_damage_profile] is Hitbox.GuardDamageProfile — 0=NORMAL, 1=DASH.
func receive_hit(amount: float, source: Node = null, guard_damage_profile: int = 0) -> void:
    if not _enabled:
        return
    hit_received.emit(amount, source, guard_damage_profile)

# ══ Pool lifecycle ════════════════════════════════════════════════════════════


func reset() -> void:
    _enabled = true
    set_deferred("monitoring", true)
    set_deferred("monitorable", true)


func set_enabled(value: bool) -> void:
    _enabled = value
    set_deferred("monitoring", value)
    set_deferred("monitorable", value)
