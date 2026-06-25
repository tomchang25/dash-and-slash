# example_state.gd
# Example save provider — holds the demo slice's live state and serializes it.
# This is the neutral base's single illustration of the save contract: an autoload
# that owns some state and registers itself with SaveManager as a provider.
#
# It deliberately takes NO position on how a real project should organise state
# across many domains — that "where does state live" decision is what each preset
# supplies (the sim-management preset layers a Store/Manager model on top; the
# action-rpg preset distributes state onto entity components). The base only shows
# the contract: implement to_dict / from_dict / validate, then register_provider().
extends Node

## Entity ids the player has collected. Validated against ExampleRegistry on load.
var collected_ids: Array[String] = []

## Running total score.
var score: int = 0


func _ready() -> void:
	SaveManager.register_provider(self)

# ══ Save contract ═════════════════════════════════════════════════════════════


## Serializes this slice's state under its section key. to_dict() may return more
## than one section key; here it returns just "example".
func to_dict() -> Dictionary:
	return {
		"example": {
			"_version": 1,
			"collected_ids": collected_ids.duplicate(),
			"score": score,
		}
	}


## Restores from the full sections dict, reading only the "example" key. Order:
## migrate legacy field shapes, read fields, then validate referential integrity.
func from_dict(data: Dictionary) -> void:
	var section: Dictionary = data.get("example", {})
	section = _migrate(section)

	score = int(section.get("score", 0))

	collected_ids = []
	if section.get("collected_ids") is Array:
		for id: Variant in section["collected_ids"]:
			if id is String:
				collected_ids.append(id)


## Drops collected ids that no longer resolve against ExampleRegistry — a renamed
## or removed entity must warn, not brick the load. Returns true (warnings only).
func validate() -> bool:
	var kept: Array[String] = []
	for id: String in collected_ids:
		if ExampleRegistry.get_example_by_id(id) == null:
			push_warning("ExampleState: collected id '%s' not found — dropped" % id)
			continue
		kept.append(id)
	collected_ids = kept
	return true

# ══ Migration ═════════════════════════════════════════════════════════════════


## Maps this section's legacy field shapes forward. Per-section only — whole-file
## migration (renaming/relocating sections) lives in SaveManager._migrate_schema().
## The body below is illustrative; safe to delete in a real project.
func _migrate(section: Dictionary) -> Dictionary:
	# Illustrative: an early build stored the running total under "points".
	if section.has("points") and not section.has("score"):
		section = section.duplicate()
		section["score"] = section["points"]
		section.erase("points")
	return section
