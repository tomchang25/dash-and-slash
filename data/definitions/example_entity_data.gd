# example_entity_data.gd
# Designer resource for a single example entity: id, display name, and a numeric value.
# Template starter — rename/extend this to model your own domain objects
# (e.g. MonsterData, GeneratorData, UpgradeData).
class_name ExampleEntityData
extends Resource

@export var entity_id: String = ""
@export var display_name: String = ""
@export var value: int = 0
