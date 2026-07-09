# entity.gd
# Base for composed world actors. This base only fans reset() / set_enabled() to children for pooling.
class_name Entity
extends Node2D

# == Lifecycle ================================================================

func _ready() -> void:
    pass

# == Common API ================================================================


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
