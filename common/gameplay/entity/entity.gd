# entity.gd
# Base for composed entities (player, enemy, …). The root is a body that holds
# almost no logic — capabilities live on Component children. This base just wires
# the common lifecycle: it locates a Health component, relays its death, and fans
# reset() / set_enabled() to every component child so the entity can be pooled.
#
# Subclasses (player.gd, enemy.gd) add their own movement / input in _physics_process.
class_name Entity
extends CharacterBody2D

signal died(entity: Entity)

# ── Node references ───────────────────────────────────────────────────────────

@onready var health: Health = find_child("Health", false, false) as Health

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if health != null:
        health.died.connect(_on_health_died)

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_health_died() -> void:
    died.emit(self)

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
