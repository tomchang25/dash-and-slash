# example_registry.gd
# Autoload that loads all ExampleEntityData resources at startup.
# Access globally via ExampleRegistry.get_example_by_id(id) / get_all_examples().
# Template starter — duplicate this pattern for each new designer resource type.
extends ResourceRegistry


func _dir_path() -> String:
	return DataPaths.EXAMPLES_DIR


func _id_of(r: Resource) -> String:
	return (r as ExampleEntityData).entity_id if r is ExampleEntityData else ""


## Returns all example entities as a typed array.
func get_all_examples() -> Array[ExampleEntityData]:
	var result: Array[ExampleEntityData] = []
	for r: Resource in get_all():
		result.append(r as ExampleEntityData)
	return result


## Returns the ExampleEntityData with the given id, or null.
func get_example_by_id(id: String) -> ExampleEntityData:
	return get_by_id(id) as ExampleEntityData
