# scene_registry.gd
# Resource-backed table of scene route keys to PackedScene targets.
class_name SceneRegistry
extends Resource

@export var default_route: StringName = &"arena"
@export var main_menu_route: StringName = &"main_menu"
@export var test_route: StringName = &"test_runner"
@export var routes: Dictionary = { }

# == Common API ================================================================


## Returns true when [param key] resolves to a PackedScene route.
func has_route(key: StringName) -> bool:
    return get_scene(key) != null


## Returns the PackedScene registered for [param key], or null when missing or invalid.
func get_scene(key: StringName) -> PackedScene:
    var scene: Variant = routes.get(key)
    if scene == null:
        scene = routes.get(String(key))
    return scene as PackedScene


## Validates route wiring and reports missing default/main-menu/test routes.
func validate() -> bool:
    var ok := true
    for key: Variant in routes.keys():
        if not (routes[key] is PackedScene):
            ToastManager.show_dev_error("SceneRegistry: route '%s' is not a PackedScene" % String(key))
            ok = false
    for required_key: StringName in [default_route, main_menu_route, test_route]:
        if not has_route(required_key):
            ToastManager.show_dev_error("SceneRegistry: required route '%s' is missing" % String(required_key))
            ok = false
    return ok
