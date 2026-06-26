# entity.gd
# Base for composed entities (player, enemy, …). The root is a body that holds
# almost no logic — capabilities live on Component children. This base just wires
# the common lifecycle: it relays an assigned Health component and fans
# reset() / set_enabled() to every component child so the entity can be pooled.
#
# Subclasses (player.gd, enemy.gd) add their own movement / input in _physics_process.
class_name Entity
extends CharacterBody2D

signal died(entity: Entity)
signal health_changed(current: float, maximum: float)

# ── Exports ───────────────────────────────────────────────────────────────────

@export var health: Health

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if health != null:
        health.died.connect(_on_health_died)
        health.health_changed.connect(_on_health_changed)
        emit_health_snapshot()


func emit_health_snapshot() -> void:
    if health != null:
        health_changed.emit(health.current(), health.max_health)

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_health_died() -> void:
    died.emit(self)


func _on_health_changed(current: float, maximum: float) -> void:
    health_changed.emit(current, maximum)

# ══ Pool lifecycle ════════════════════════════════════════════════════════════


## Restores every component child to spawn defaults. Called on pool acquire.
func reset() -> void:
    for child: Node in get_children():
        if child.has_method("reset"):
            child.reset()


## Toggles every component child without freeing. Called on pool release.
func set_enabled(value: bool) -> void:
    set_physics_process(value)
    visible = value
    for child: Node in get_children():
        if child.has_method("set_enabled"):
            child.set_enabled(value)
