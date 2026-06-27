# destructible_object.gd
# Simple non-health destructible entity that breaks after a fixed number of hits.
class_name DestructibleObject
extends Entity

signal hit_count_changed(current: int, required: int, source: Node)
signal destroyed(object: DestructibleObject)

# -- Exports ------------------------------------------------------------------
@export var hurtbox: Hurtbox
@export var required_hits: int = 3
@export var disable_on_destroy: bool = true

# -- State --------------------------------------------------------------------
var _hit_count := 0
var _destroyed := false

# == Lifecycle ================================================================


func _ready() -> void:
    super()
    if hurtbox != null:
        hurtbox.hit_received.connect(_on_hit_received)

# == Overridden Custom Methods ================================================


func reset() -> void:
    _hit_count = 0
    _destroyed = false
    super()
    set_enabled(true)
    hit_count_changed.emit(_hit_count, _required_hits(), null)

# == Signal handlers ==========================================================


func _on_hit_received(_amount: float, source: Node, _guard_damage_profile: int) -> void:
    apply_hit(source)

# == Common API ================================================================


func apply_hit(source: Node = null) -> void:
    if _destroyed:
        return

    _hit_count += 1
    hit_count_changed.emit(_hit_count, _required_hits(), source)
    if _hit_count >= _required_hits():
        destroy()


func destroy() -> void:
    if _destroyed:
        return

    _destroyed = true
    if hurtbox != null:
        hurtbox.set_enabled(false)
    destroyed.emit(self)
    if disable_on_destroy:
        set_enabled(false)


func current_hits() -> int:
    return _hit_count


func is_destroyed() -> bool:
    return _destroyed

# == Hit counting ==============================================================


func _required_hits() -> int:
    return maxi(required_hits, 1)
