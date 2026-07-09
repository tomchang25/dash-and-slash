# GDScript Structure Standard

This document defines shared GDScript file structure rules. It applies to scene scripts, reusable UI components, autoloads, data resources, gameplay components, services, managers, and tests unless a narrower standard overrides one section.

Applies especially to:

- Block scene root scripts
- Testbed scenes
- Reusable UI component scripts
- Common framework scripts
- Autoloads and managers
- Resource definitions under `data/`

---

# 1. File Header

Every script must begin with a file header comment block.

Format:

```gdscript
# script_name.gd
# One-line description of this script's responsibility.
```

Scene scripts may add state annotations when useful:

```gdscript
# script_name.gd
# One-line description of this scene's responsibility.
# Reads:  SomeManager.state.field_name
# Writes: SomeManager.state.field_name
```

Rules:

- The first line is the filename.
- The second line is a single-sentence responsibility summary.
- `Reads` and `Writes` list managed state fields this script touches when that makes scene flow easier to review.
- If the script reads nothing, omit the `Reads` line.
- If the script writes nothing, omit the `Writes` line.
- Comment and docstring text (the file header description above, and `##` GDDoc comments on functions) is an explicit exception to the global no-hard-wrap-prose rule in `dev/agent_rules/agent_startup.md`, because the project's GDScript formatter enforces a hard 180-character max-line-length. Wrap comment prose one sentence per line. If a single sentence would exceed 180 characters, break it at the nearest clause boundary (comma, semicolon, or parenthetical) — never mid-word — and prefer a break near 120 characters over letting the line run close to 180. Continuation lines repeat the `#` / `##` marker.

---

# 2. Declaration Order

Declarations at the top of the file follow this order:

```gdscript
@tool (if needed)
class_name (if needed)
extends

inner classes (if any)

signals
enums

const
preload constants

@export / @export_group

private variables

@onready
```

Rules:

- `@tool` goes on the very first line when present, before `class_name` and `extends`.
- `class_name` goes before `extends`, matching Godot's generated script order.
- Inner classes go immediately after `class_name` / `extends`, before constants, variables, and function sections.
- Signals are declared before constants so they appear first in the class contract.
- Enums follow signals, as they can be used as export type hints and const initializers.
- Constants and preloads come before `@export` so export default values can reference them.
- `@onready` goes last because it is resolved after `_ready()` enters the scene tree.
- `class_name` is only added when the script needs to be referenced by type elsewhere. Omit it for scene root scripts that are never typed directly.

---

# 3. Variable Block Headers

Variable groups at the top of the file use the single-line format.

```gdscript
# -- Group name --

var _example_state := false
```

Use a consistent label from the table below.

| Header                          | Contents                                                            |
| ------------------------------- | ------------------------------------------------------------------- |
| `# -- Constants --`             | `const` and `preload`                                               |
| `# -- Exports --`               | `@export` vars                                                      |
| `# -- State --`                 | Runtime logic variables                                             |
| `# -- Timer / tween handles --` | `Timer`, `Tween` vars                                               |
| `# -- Node references --`       | `@onready` node references bound to `.tscn` nodes via `%UniqueName` |

Only include groups that have at least one variable. Do not create custom group names unless no standard label fits.

Do not pad variable block headers to a fixed width. Legacy padded headers may remain in untouched old files, but any touched header must use the exact single-line shape above.

Leave whitespace after a variable block header so the header reads as a section label rather than a comment on the first declaration. Let `gdscript-formatter` normalize the exact blank-line count.

---

# 4. Function Section Headers

Function groups use the double-line format.

```gdscript
# == Section name ==

func example() -> void:
    pass
```

Use ASCII `=` and `-` header characters. Do not pad headers to a fixed column. Legacy padded or Unicode headers may remain in old files; update touched headers opportunistically rather than performing bulk-only rewrites.

Padded function section headers are violations in touched files. Do not copy legacy fixed-width headers into new or edited scripts.

Leave whitespace after a function section header so the header reads as a section label rather than a comment on the first function. Let `gdscript-formatter` normalize the exact blank-line count.

---

# 5. Section Order

The same main section order applies across script types. Types differ in their subsection names, not in the top-level ordering rules.

Sections appear in this fixed order:

```gdscript
Inner classes
Lifecycle
Overridden custom methods
Signal handlers
Common API
Feature section 1
Feature section 2
...
```

## Inner Classes

Placed immediately after `class_name` / `extends` and before constants, variables, and function sections.

## Lifecycle

Contains only Godot built-in virtual callbacks, in this order when present:

```gdscript
_init()
_enter_tree()
_ready()
_process()
_physics_process()
remaining virtual methods
```

No private helpers here. Helpers belong in their feature section.

## Overridden Custom Methods

Methods overriding a non-Godot base class contract go after Godot lifecycle and before signal handlers. Omit this section when the script has no custom overrides.

## Signal Handlers

Contains only `_on_xxx()` callbacks. No public functions. No logic helpers.

## Common API

All public methods that other scripts may call go here, including public static methods such as `from_dict()` and paired instance methods such as `to_dict()`. Do not split public static methods into a separate main section.

## Feature Sections

Domain-specific private implementation groups. Feature sections contain private helpers only; move public methods to `Common API` even when they belong to a specific domain concept.

Private functions belong inside the section they serve, not in a global private section at the bottom. Exception: `_on_xxx` signal callbacks always go in `Signal handlers`.

---

# 6. Node Source Rule

Node-source rules are defined in `dev/standards/scene_node_source_standard.md`.

For this standard's scope, all persistent nodes in scenes, testbeds, and reusable UI components must be defined in `.tscn` and referenced from GDScript with `@onready`. Runtime-created nodes are allowed only for the permitted cases documented in the scene node source standard.

---

# 7. Signal Connections

Connect signals between a scene's own nodes in `_ready()`, not in the `.tscn`. This keeps the full connection surface visible in code without IDE dependency for wiring.

Connections go at the top of `_ready()`, before any logic or node setup:

```gdscript
func _ready() -> void:
    _confirm_button.pressed.connect(_on_confirm_pressed)
    _cancel_button.pressed.connect(_on_cancel_pressed)
    # ... rest of setup
```

This applies to all signal connections: buttons, custom signals from child nodes, and connections to autoloads.

---

# 8. Instantiating Packed Scenes

When instantiating a reusable component scene into a container, follow this fixed order:

```gdscript
for entry: ExampleEntry in _items:
    var row: ExampleRow = ExampleRowScene.instantiate()
    row.setup(entry)
    row.row_pressed.connect(_on_row_pressed)
    _row_container.add_child(row)
```

Apply data and connect signals before `add_child()` because `add_child()` triggers the child's `_ready()`.

---

# 9. Component `setup()` Implementation

A reusable component's `setup()` is its apply function, but it has a specific internal shape because it may be called either before or after the component enters the scene tree.

```gdscript
# -- State --

var _entity: EnemyData = null

# -- Node references --

@onready var _name_label: Label = %NameLabel


# == Lifecycle ==

func _ready() -> void:
    _select_button.pressed.connect(func() -> void: selected.emit())

    if _entity != null:
        _apply()


# == Common API ==

func setup(entity: EnemyData) -> void:
    _entity = entity

    if is_node_ready():
        _apply()


func refresh() -> void:
    if is_node_ready():
        _apply()


# == View ==

func _apply() -> void:
    _name_label.text = _entity.display_name
```

Rules:

- `setup()` only stores arguments to private variables, then calls `_apply()` guarded by `is_node_ready()`. It must not touch any `@onready` node directly.
- `_apply()` is private, takes no arguments, reads private state, and writes the `@onready` nodes. It is the only function that touches view nodes.
- `_ready()` connects signals first, then calls `_apply()` if private state has already been populated by an earlier `setup()` call.
- `refresh()`, if exposed, calls `_apply()` guarded by `is_node_ready()`. It never re-assigns private state.
