# resource_registry.gd
# Base class for data-driven registries: loads all .tres under a directory,
# keyed by an id getter, and exposes generic lookup + lifecycle hooks.
# Subclasses override _dir_path() and _id_of() to specialise for their type.
class_name ResourceRegistry
extends Node

var _by_id: Dictionary = { } # id (String) -> Resource


## Override: return the res:// directory path that holds this registry's .tres files.
func _dir_path() -> String:
    return ""


## Override: return the entity id from a resource instance (return "" to skip).
func _id_of(_r: Resource) -> String:
    return ""


func _ready() -> void:
    _by_id = ResourceDirLoader.load_by_id(
        _dir_path(),
        func(r: Resource) -> String: return _id_of(r)
    )


## Returns the resource with the given id, or null if not found.
func get_by_id(id: String) -> Resource:
    return _by_id.get(id, null)


## Returns all resources in this registry (untyped).
## Typed subclass wrappers (e.g. get_all_<plural>()) are the preferred call site.
func get_all() -> Array:
    return _by_id.values()


## Returns the number of resources loaded.
func size() -> int:
    return _by_id.size()


## Default validation: non-empty. Override in subclasses for cross-checks.
func validate() -> bool:
    if size() == 0:
        ToastManager.show_dev_error("%s: registry is empty" % name)
        return false
    return true
