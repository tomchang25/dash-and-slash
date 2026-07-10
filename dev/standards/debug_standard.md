# Debug Standard

This document defines how debug-conditional code works in this project.

---

# 1. Architecture

Debug state is managed by two layers:

- **`OS.is_debug_build()`** — Engine-level gate. True in editor and debug exports, false in release exports. Not a runtime toggle — determined at build time.
- **`SettingsStore.debug_mode`** — User-facing preference. Persisted by `SettingsStore.save_settings()`. Toggled via the Settings Overlay's Debug Mode checkbox.

The **`Debug` autoload** combines both into a single runtime check:

```
Debug.enabled = OS.is_debug_build() AND SettingsStore.debug_mode
```

`Debug.enabled` is the **only check** debug-conditional code should use. Do not call `OS.is_debug_build()` or `SettingsStore.debug_mode` directly in scene or gameplay code.

---

# 2. Autoload Details

`Debug` loads immediately after `SettingsStore` in the autoload order. It connects to `SettingsStore.debug_mode_changed` (fired by the setter on `debug_mode`) and recomputes `enabled` on every change.

**Signal:** `Debug.toggled(is_enabled: bool)` — emitted when `enabled` changes. Scenes that create debug UI should connect to this for reactive show/hide.

**Mutator:** `Debug.set_debug_mode(value: bool)` — the canonical way to change the debug preference. Writes `SettingsStore.debug_mode`, persists, and triggers the signal chain. The Settings Overlay calls this; other code generally should not.

---

# 3. How to Write Debug-Conditional Code

## One-shot init (most common)

Check `Debug.enabled` when building the scene. If off, skip debug node creation entirely:

```gdscript
func _init_debug_overlay() -> void:
    if not Debug.enabled:
        return
    _debug_label = Label.new()
    # ... configure label ...
    # node-src: debug
    add_child(_debug_label)
```

## Reactive toggle

If a scene should respond to mid-scene debug toggles, connect to `Debug.toggled`:

```gdscript
func _init_debug_overlay() -> void:
    if not Debug.enabled:
        return
    _debug_label = Label.new()
    # ... configure label ...
    # node-src: debug
    add_child(_debug_label)
    Debug.toggled.connect(_on_debug_toggled)


func _on_debug_toggled(is_enabled: bool) -> void:
    if _debug_label != null:
        _debug_label.visible = is_enabled
```

## Conditional logic (no UI)

For gameplay shortcuts (e.g. instant cooldowns, force-kill, free resources), guard with `Debug.enabled`:

```gdscript
if Debug.enabled:
    _grant_debug_bonus()
```

---

# 4. Node Source Rule

By default, debug-only nodes are created in code, never placed in `.tscn`. They carry the `# node-src: debug` marker for the linter. See `scene_node_source_standard.md` §5 for full marker details. Layout-sensitive reusable debug blocks may use the exception below.

## 4a. Debug Block Exception

Reusable, layout-sensitive debug UI blocks may be authored as dedicated `.tscn` + `.gd` pairs when the block exists only to package debug controls and layout. This exception is for panels/containers whose layout should be inspected in the editor; one-off debug labels and buttons should still be created in code.

Debug blocks may be pre-placed in gameplay scene `.tscn` files when all of these are true:

- The node is an instance of a dedicated debug block scene, not ad hoc debug controls placed directly in the gameplay scene.
- The debug block root is named with a clear debug prefix or suffix, such as `DebugPanel`.
- The debug block is hidden by default in the `.tscn`.
- The debug block script gates its own visibility from `Debug.enabled` in `_ready()` and reacts to `Debug.toggled` when needed.
- Every action handler that mutates game state must guard with `if not Debug.enabled: return` even if the block is hidden.
- Release exports may contain the hidden node in the scene tree, but must never show it or allow its actions to run because `Debug.enabled` is false.

```gdscript
func _ready() -> void:
    visible = Debug.enabled
    Debug.toggled.connect(_on_debug_toggled)


func _on_debug_toggled(is_enabled: bool) -> void:
    visible = is_enabled


func _on_add_random_item_pressed() -> void:
    if not Debug.enabled:
        return
    # mutate debug state here
```

---

# 5. The Reusable `DebugPanel` Component

`game/shared/debug_panel/debug_panel.tscn` (+ `debug_panel.gd`, `class_name DebugPanel`) is the paradigm-neutral implementation of the §4a exception, ported from the godot-template base. It ships with no game-specific actions — it is a self-gated `PanelContainer` shell that any scene can instance and populate.

## Instancing

`tick_arena.tscn` pre-places one instance, hidden by default, as a child of `HUD`:

```text
[node name="DebugPanel" parent="HUD" instance=ExtResource("...debug_panel.tscn")]
unique_name_in_owner = true
```

## Registering actions

`tick_arena.gd` calls `add_action(label: String, callback: Callable) -> Button` from `_wire_debug_panel()`, itself called at the end of `_ready()`. `DebugPanel` wraps every callback with its own `Debug.enabled` guard before invoking it, so a hidden-but-still-in-tree panel can never fire an action:

```gdscript
@onready var _debug_panel: DebugPanel = %DebugPanel


func _wire_debug_panel() -> void:
    _ninja_class_button = _debug_panel.add_action("Class - Ninja", _on_debug_set_ninja_class, "Player")
    _viking_class_button = _debug_panel.add_action("Class - Viking", _on_debug_set_viking_class, "Player")
    _guard_shredder_button = _debug_panel.add_action("Guard Shredder", _on_debug_toggle_guard_shredder, "Build")
    _chain_dash_button = _debug_panel.add_action("Chain Dash", _on_debug_toggle_chain_dash, "Build")


func _on_debug_set_ninja_class() -> void:
    if not Debug.enabled:
        return
    _set_debug_character_class(ninja_class)
```

The handler still guards with `if not Debug.enabled: return` per §4a — belt-and-suspenders in case the handler is ever called from another path. Do not extend `debug_panel.gd` itself with project-specific actions; keep the component generic and let the owning scene call `add_action()` for its own shortcuts.

---

# 6. Release Safety

In release exports, `OS.is_debug_build()` returns false, so `Debug.enabled` is always false regardless of the persisted `debug_mode` value. The Settings Overlay checkbox remains visible but has no effect — this is intentional (the preference persists for the next debug build).

Never expose sensitive gameplay internals (e.g. hidden stats, cheat actions, editor shortcuts, test routes) outside a `Debug.enabled` guard.

---

# 7. Summary

| Want to…                          | Use                                |
| --------------------------------- | ---------------------------------- |
| Check if debug is active          | `Debug.enabled`                    |
| React to debug toggle mid-scene   | `Debug.toggled.connect(callback)`  |
| Change the debug preference       | `Debug.set_debug_mode(value)`      |
| Gate debug node creation          | `if not Debug.enabled: return`     |
| Mark a debug node for the linter  | `# node-src: debug`                |
| Add a reusable debug action panel | `DebugPanel.add_action(label, cb)` |
