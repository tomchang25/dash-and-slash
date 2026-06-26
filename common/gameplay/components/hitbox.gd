# hitbox.gd
# Component: the dealing side of combat. An Area2D that, while enabled, deals damage
# to any Hurtbox it overlaps by calling that hurtbox's receive_hit(). Supports a
# one-shot-on-enter mode (damage_interval = 0) and a repeating tick mode
# (damage_interval > 0, re-hitting victims still inside after the interval).
#
# The owner is passed as the hit source for attribution and self-hit avoidance.
class_name Hitbox
extends Area2D

signal hit_landed(target: Hurtbox)

enum GuardDamageProfile { NORMAL, DASH }

# ── Exports ─────────────────────────────────────────────────────────────────────

@export var damage: float = 10.0
@export var guard_damage_profile: GuardDamageProfile = GuardDamageProfile.NORMAL

## Seconds between repeated hits on the same victim. 0 = hit once on enter only.
@export var damage_interval: float = 0.0

@export var collision_shape: CollisionShape2D

# ── State ─────────────────────────────────────────────────────────────────────

var _enabled: bool = true
## Last hit time per victim, in seconds. Key = Hurtbox, value = float.
var _hit_times: Dictionary = { }

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    area_entered.connect(_on_area_entered)
    area_exited.connect(_on_area_exited)


func _physics_process(_delta: float) -> void:
    if not _enabled or damage_interval <= 0.0:
        return
    # Purge victims freed without firing area_exited.
    for victim: Variant in _hit_times.keys():
        if not is_instance_valid(victim):
            _hit_times.erase(victim)
    # Re-hit victims still inside whose interval has elapsed.
    for area: Area2D in get_overlapping_areas():
        _try_hit(area)

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_area_entered(area: Area2D) -> void:
    if _enabled:
        _try_hit(area)


func _on_area_exited(area: Area2D) -> void:
    _hit_times.erase(area)

# ══ Hit resolution ════════════════════════════════════════════════════════════


func _try_hit(area: Area2D) -> void:
    var hurtbox := area as Hurtbox
    if hurtbox == null:
        return
    # Don't hit our own entity.
    if owner != null and hurtbox.owner == owner:
        return
    var now := Time.get_ticks_msec() / 1000.0
    if _hit_times.has(hurtbox):
        if damage_interval <= 0.0:
            return
        if now - float(_hit_times[hurtbox]) < damage_interval:
            return
    _hit_times[hurtbox] = now
    hurtbox.receive_hit(damage, owner, guard_damage_profile)
    hit_landed.emit(hurtbox)

# ══ Pool lifecycle ════════════════════════════════════════════════════════════


func reset() -> void:
    _enabled = true
    _hit_times.clear()
    set_deferred("monitoring", true)


func set_enabled(value: bool) -> void:
    _enabled = value
    _hit_times.clear()
    set_deferred("monitoring", value)


func set_collision_shape(shape: Shape2D) -> void:
    if collision_shape != null:
        collision_shape.shape = shape
