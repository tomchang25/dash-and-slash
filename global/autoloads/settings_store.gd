# settings_store.gd
# Project-wide settings skeleton. Runtime projects can expand this provider.
extends Node

const SECTION_ID := "settings"

var tutorial_skip_all: bool = false


func to_dict() -> Dictionary:
	return {SECTION_ID: {"tutorial_skip_all": tutorial_skip_all}}


func from_dict(data: Dictionary) -> void:
	var section: Dictionary = data.get(SECTION_ID, {})
	tutorial_skip_all = bool(section.get("tutorial_skip_all", tutorial_skip_all))


func validate() -> bool:
	return true
