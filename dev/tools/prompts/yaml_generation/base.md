# Adding a New Entity Type to the Template

This guide walks through the full chain for introducing a new designer-authored resource type.

## Overview

One entity type spans six layers:

```
data/definitions/<x>_data.gd                    # Resource class (fields)
data/yaml/<x>.yaml                               # Authored content (human-edited)
dev/tools/tres_lib/entities/<x>.py               # Pipeline spec (YAML → .tres)
dev/tools/tres_lib/registry.py                   # Registers the spec
data/tres/<x_plural>/                            # Generated .tres files (gitignored)
global/autoloads/registries/<x>_registry.gd      # Runtime loader (autoload)
global/constants/data_paths.gd                   # Directory constant
project.godot                                    # Autoload declaration
```

## Step-by-step

### 1. Define the Resource class

Create `data/definitions/<x>_data.gd`:

```gdscript
# <x>_data.gd
# Designer resource for <X>.
class_name <X>Data
extends Resource

@export var <x>_id: String = ""
@export var display_name: String = ""
# Add your fields here.
```

Open the project in Godot once so the editor generates `<x>_data.gd.uid` sidecar.

### 2. Author YAML content

Create `data/yaml/<x>.yaml`:

```yaml
<x_plural>:
  - <x>_id: "my_first_<x>"
    display_name: "My First X"
```

IDs must be snake_case, globally unique within their type, and stable once authored.

### 3. Write the pipeline spec

Copy `dev/tools/tres_lib/entities/example_entity.py` to `<x>.py`. Change:
- `yaml_key` → `"<x_plural>"`
- `tres_subdir` → `"<x_plural>"`
- `uid_prefix` → `"<x>"`
- `script_paths` → path to your `<x>_data.gd`
- `build_tres()` → write your fields with `TresWriter`
- `parse_tres()` → read them back
- `validate()` → check required fields, cross-references

If this entity cross-references another (e.g. points to a category), list the dependency before it in the registry.

### 4. Register the spec

In `dev/tools/tres_lib/registry.py`, add your spec to `REGISTRY` in dependency order:

```python
from tres_lib.entities.<x> import SPEC as <x>_spec

REGISTRY = [
    example_entity_spec,
    <x>_spec,   # after any entities it references
]
```

### 5. Generate .tres files

```bash
cd dev/tools
python yaml_to_tres.py --godot-root ../..
```

Re-run whenever YAML is edited.

### 6. Write the registry autoload

Create `global/autoloads/registries/<x>_registry.gd`:

```gdscript
# <x>_registry.gd
# Autoload: loads all <X>Data resources. Access via <X>Registry.get_<x>_by_id(id).
extends ResourceRegistry

func _dir_path() -> String:
    return DataPaths.<X_PLURAL>_DIR

func _id_of(r: Resource) -> String:
    return (r as <X>Data).<x>_id if r is <X>Data else ""

func get_all_<x_plural>() -> Array[<X>Data]:
    var result: Array[<X>Data] = []
    for r: Resource in get_all():
        result.append(r as <X>Data)
    return result

func get_<x>_by_id(id: String) -> <X>Data:
    return get_by_id(id) as <X>Data
```

### 7. Wire up

Add to `global/constants/data_paths.gd`:
```gdscript
const <X_PLURAL>_DIR: String = "res://data/tres/<x_plural>"
```

Add to `project.godot` `[autoload]` (before `SaveManager`):
```
<X>Registry="*res://global/autoloads/registries/<x>_registry.gd"
```

### 8. Verify

```bash
cd dev/tools
python yaml_to_tres.py --godot-root ../..
python validate_yaml.py --yaml-dir ../../data/yaml
python lint_standards.py --files ../../global/autoloads/registries/<x>_registry.gd
```

Then open the project in Godot and confirm the registry loads without errors at boot.
