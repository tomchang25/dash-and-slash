# example_scene.gd
# Block 01 — Template demo scene. Lists all registered example entities;
# clicking one adds its value to the score and marks it collected.
# Demonstrates: Registry read, provider state, SaveManager save/load, EventBus signal.
extends Control

@onready var _score_label: Label = $RootVBox/ScoreLabel
@onready var _entity_list: ItemList = $RootVBox/EntityList


func _ready() -> void:
	$RootVBox/EntityList.item_selected.connect(_on_entity_selected)
	$RootVBox/ButtonRow/SaveButton.pressed.connect(_on_save_pressed)
	$RootVBox/ButtonRow/LoadButton.pressed.connect(_on_load_pressed)
	$RootVBox/ButtonRow/ResetButton.pressed.connect(_on_reset_pressed)
	_refresh()


func _refresh() -> void:
	_score_label.text = "Score: %d" % ExampleState.score
	_entity_list.clear()
	for entity: ExampleEntityData in ExampleRegistry.get_all_examples():
		var collected: bool = ExampleState.collected_ids.has(entity.entity_id)
		var label: String = "%s  (+%d)%s" % [
			entity.display_name,
			entity.value,
			"  ✓" if collected else "",
		]
		_entity_list.add_item(label)
		_entity_list.set_item_metadata(_entity_list.item_count - 1, entity.entity_id)


func _on_entity_selected(index: int) -> void:
	var entity_id: String = _entity_list.get_item_metadata(index)
	var entity: ExampleEntityData = ExampleRegistry.get_example_by_id(entity_id)
	if entity == null:
		return
	ExampleState.score += entity.value
	if not ExampleState.collected_ids.has(entity_id):
		ExampleState.collected_ids.append(entity_id)
	EventBus.emit_signal("example_entity_collected", entity_id)
	_refresh()


func _on_save_pressed() -> void:
	SaveManager.save()


func _on_load_pressed() -> void:
	SaveManager.load()
	_refresh()


func _on_reset_pressed() -> void:
	ExampleState.collected_ids.clear()
	ExampleState.score = 0
	_refresh()
