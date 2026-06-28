# Debug Standard

This document defines debug-conditional code.

---

# 1. Architecture

Debug state has two gates:

- `OS.is_debug_build()` — engine/build-level gate.
- `SettingsStore.debug_mode` — user-facing persisted preference.

The `Debug` autoload combines them:

```gdscript
Debug.enabled = OS.is_debug_build() and SettingsStore.debug_mode
```

Scene and gameplay code must check `Debug.enabled`, not `OS.is_debug_build()` or `SettingsStore.debug_mode` directly.

---

# 2. API

- `Debug.enabled` — true only when the build allows debug and the setting is on.
- `Debug.toggled(is_enabled)` — emitted when the effective state changes.
- `Debug.set_debug_mode(value)` — changes and persists the user preference.

---

# 3. Debug UI

Create one-off debug labels/buttons in code behind a `Debug.enabled` guard and mark the `add_child` with `# node-src: debug`.

```gdscript
func _init_debug_label() -> void:
    if not Debug.enabled:
        return
    var label := Label.new()
    label.text = "Debug"
    # node-src: debug
    add_child(label)
```

Reusable, layout-sensitive debug panels may be dedicated `.tscn` components if they are hidden by default, self-gated by `Debug.enabled`, and every mutating button handler returns immediately when debug is disabled.

---

# 4. Release Safety

Release exports must not expose debug behavior. Because `OS.is_debug_build()` is false in release exports, `Debug.enabled` stays false even when a stale `debug_mode` preference exists in `user://settings.json`.

Never expose hidden gameplay values, editor shortcuts, test routes, data mutation buttons, or cheat actions outside a `Debug.enabled` guard.
