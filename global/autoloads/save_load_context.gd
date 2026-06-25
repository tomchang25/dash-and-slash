# save_load_context.gd
# Save/load diagnostic accumulator used by larger projects during migrations.
class_name SaveLoadContext
extends RefCounted

var infos: Array[String] = []
var errors: Array[String] = []


## Records a non-fatal migration or recovery note.
func info(message: String) -> void:
	infos.append(message)


## Records a fatal or high-severity load issue.
func error(message: String) -> void:
	errors.append(message)


## Returns true when no errors were recorded.
func ok() -> bool:
	return errors.is_empty()
