# save_manager.gd
# Persistence coordinator: file IO, schema handling, and registered-provider dispatch.
# Holds NO gameplay state of its own — it only fans save/load/validate out to the
# providers that own state. This keeps the base paradigm-neutral: how a project
# organises the things that own state (one autoload per domain, a manager holding
# several state containers, or entities serialising their own slice) is a preset
# decision, not the save layer's concern.
#
# A provider is any object that implements the save interface:
#   func to_dict() -> Dictionary      — return this provider's section payload(s)
#   func from_dict(data: Dictionary)  — restore from the full sections dict
#   func validate() -> bool           — sanity-check restored state, return ok
# Providers register themselves via register_provider() in their _ready(), before
# GameManager calls load(). Per-section field migration lives inside each provider's
# from_dict(); whole-file migration (renaming/relocating sections) lives here.
#
# On-disk format: { "schema_version": int, "sections": { <id>: <payload> } }.
extends Node

const SAVE_PATH := "user://save.json"
const SCHEMA_VERSION := 1

## Registered providers, in registration order. Each implements to_dict(),
## from_dict(), and validate(). to_dict() returns a dict of one or more section
## keys; all providers' dicts are merged into the on-disk "sections" object.
var _providers: Array = []


## Registers a save provider. Call before load() runs (i.e. in the owning
## autoload's _ready()). The provider must implement to_dict() -> Dictionary,
## from_dict(Dictionary), and validate() -> bool.
func register_provider(provider: Object) -> void:
	assert(provider.has_method("to_dict"), "register_provider: %s missing to_dict()" % provider)
	assert(provider.has_method("from_dict"), "register_provider: %s missing from_dict()" % provider)
	assert(provider.has_method("validate"), "register_provider: %s missing validate()" % provider)
	_providers.append(provider)


## Calls validate() on every provider, accumulating failures. Returns true only
## when every provider passed. Call after load() (see GameManager._ready()).
func run_validation() -> bool:
	var ok := true
	for provider: Object in _providers:
		if not provider.validate():
			ok = false
	return ok


## Serializes every provider into one sections dict and writes it to disk.
func save() -> void:
	var sections_out: Dictionary = {}
	for provider: Object in _providers:
		sections_out.merge(provider.to_dict())
	var data := {
		"schema_version": SCHEMA_VERSION,
		"sections": sections_out,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open %s for writing" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))


## Reads the save file, runs whole-file migration, and hands the full sections
## dict to each provider's from_dict() (each reads only the keys it owns).
func load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: failed to open %s for reading" % SAVE_PATH)
		return
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("SaveManager: invalid save data in %s" % SAVE_PATH)
		return

	var save_dict: Dictionary = parsed
	save_dict = _migrate_schema(save_dict)
	if not (save_dict.has("sections") and save_dict["sections"] is Dictionary):
		push_error("SaveManager: save missing 'sections' key in %s" % SAVE_PATH)
		return

	var sections_data: Dictionary = save_dict["sections"].duplicate(true)
	for provider: Object in _providers:
		provider.from_dict(sections_data)


## Whole-file migration seam. The ONLY place that may move data between sections,
## rename a section, or otherwise transform the save as a whole — it has the
## whole-file view no single provider has. Per-section field migration (legacy
## field shapes within one section) belongs in that provider's from_dict(), not
## here. Add a step and bump SCHEMA_VERSION when the file shape changes.
func _migrate_schema(save_dict: Dictionary) -> Dictionary:
	var from_version: int = int(save_dict.get("schema_version", 1))
	if from_version >= SCHEMA_VERSION:
		return save_dict
	# One step per version. Whole-file transforms only (relocate/rename sections):
	# if from_version < 2:
	#     save_dict = _v1_to_v2(save_dict)
	return save_dict
