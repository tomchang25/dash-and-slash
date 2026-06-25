# game_manager.gd
# Central autoload for scene transitions and cross-scene payload hand-off.
# Register all navigable scenes in _SCENES, then navigate with go_to("key").
# Supports --test-unit (skip boot, route to unit tests).
extends Node

## Scene registry — map of string key to PackedScene.
## Add your game scenes here when building out a new project.
const _SCENES: Dictionary = {
	"example": preload("res://game/scenes/testbed/example_scene.tscn"),
}

## Optional payload forwarded to the next scene via consume_payload().
var _pending_payload: Variant = null

@warning_ignore("return_value_discarded")

func _ready() -> void:
	var args := OS.get_cmdline_args()

	if "--test-unit" in args:
		_boot_for_tests()
		return

	_boot_normal()


func _boot_normal() -> void:
	SaveManager.load()
	SaveManager.run_validation()


func _boot_for_tests() -> void:
	# Autoloads have already initialized — registries, managers, event bus all
	# ready. Skip save loading, validation, and scene routing. Route to the
	# test runner scene which will create a GUT node and run all unit tests.
	# The test runner handles its own exit via get_tree().quit().
	var test_scene := load("res://test/test_runner.tscn")
	if test_scene == null:
		push_error("GameManager: test_runner.tscn not found — falling back to normal boot")
		_boot_normal()
		return
	get_tree().change_scene_to_packed.call_deferred(test_scene)


## Navigate to a registered scene by key, optionally passing a payload.
func go_to(key: String, payload: Variant = null) -> void:
	_pending_payload = payload
	if not _SCENES.has(key):
		push_error("GameManager: no scene registered for key '%s'" % key)
		return
	get_tree().change_scene_to_packed(_SCENES[key])


## Retrieve and clear the pending payload (call once from the arriving scene).
func consume_payload() -> Variant:
	var p := _pending_payload
	_pending_payload = null
	return p
