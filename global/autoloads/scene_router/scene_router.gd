# scene_router.gd
# Global scene-transition owner with registry-backed routes and payload hand-off.
extends Node

signal scene_changed(key: StringName)
signal navigation_failed(key: StringName)

@export var scenes: SceneRegistry

var _pending_payload: Variant = null
var _current_key: StringName = &""

# == Common API ==


## Navigates to a registered scene key and stores an optional one-shot payload for the arriving scene.
func go_to(key: StringName, payload: Variant = null) -> bool:
    if scenes == null:
        ToastManager.show_error("SceneRouter: missing SceneRegistry")
        navigation_failed.emit(key)
        return false

    var scene := scenes.get_scene(key)
    if scene == null:
        ToastManager.show_error("SceneRouter: no scene registered for key '%s'" % String(key))
        navigation_failed.emit(key)
        return false

    _pending_payload = _clone_payload(payload)
    _current_key = key
    get_tree().change_scene_to_packed.call_deferred(scene)
    _emit_scene_changed.call_deferred(key)
    return true


## Navigates to the default gameplay route.
func go_to_default(payload: Variant = null) -> bool:
    if scenes == null:
        ToastManager.show_error("SceneRouter: missing SceneRegistry")
        return false

    return go_to(scenes.default_route, payload)


## Navigates to the arena route.
func go_to_arena(payload: Variant = null) -> bool:
    return go_to(&"arena", payload)


## Navigates to the main menu route.
func go_to_main_menu(payload: Variant = null) -> bool:
    if scenes == null:
        ToastManager.show_error("SceneRouter: missing SceneRegistry")
        return false

    return go_to(scenes.main_menu_route, payload)


## Navigates to the unit-test runner route.
func go_to_test_runner(payload: Variant = null) -> bool:
    if scenes == null:
        ToastManager.show_error("SceneRouter: missing SceneRegistry")
        return false

    return go_to(scenes.test_route, payload)


## Returns and clears the pending navigation payload. Call once from the arriving scene.
func consume_payload() -> Variant:
    var payload := _clone_payload(_pending_payload)
    _pending_payload = null
    return payload


## Returns true when a route exists and resolves to a PackedScene.
func has_route(key: StringName) -> bool:
    return scenes != null and scenes.has_route(key)


## Returns the most recent route key requested through this router.
func current_key() -> StringName:
    return _current_key

# == Internals ==


func _emit_scene_changed(key: StringName) -> void:
    scene_changed.emit(key)


func _clone_payload(payload: Variant) -> Variant:
    if payload is Dictionary or payload is Array:
        return payload.duplicate(true)
    return payload
