# Debug Mode Usage

Use this when adding debug-only controls or diagnostics.

## Check debug state

```gdscript
if not Debug.enabled:
    return
```

Do not check `OS.is_debug_build()` directly in gameplay or scene code.

## React to toggles

```gdscript
func _ready() -> void:
    visible = Debug.enabled
    Debug.toggled.connect(_on_debug_toggled)


func _on_debug_toggled(is_enabled: bool) -> void:
    visible = is_enabled
```

## Add debug-only nodes

```gdscript
if Debug.enabled:
    var label := Label.new()
    label.text = "Debug"
    # node-src: debug
    add_child(label)
```

Every debug button handler that mutates state must guard again with `if not Debug.enabled: return` even if the button is hidden.
