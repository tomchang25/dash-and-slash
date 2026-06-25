# scene_router.gd
# Scene-routing facade skeleton. Projects may move GameManager routing here.
extends Node

var _pending_payload: Dictionary = {}


## Navigates to [param scene_key] with an optional payload.
func go_to(_scene_key: String, payload: Dictionary = {}) -> void:
	_pending_payload = payload.duplicate(true)


## Returns and clears the pending navigation payload.
func consume_payload() -> Dictionary:
	var payload := _pending_payload.duplicate(true)
	_pending_payload.clear()
	return payload
