# Scene Routing Standard

This document defines how Tickstrike scene transitions are registered and executed.

---

# 1. Ownership

`SceneRouter` is the only owner of normal scene transitions. `GameManager` owns boot orchestration only and must not hold scene tables, payload hand-off, or direct gameplay navigation APIs.

Use `SceneRouter.go_to(...)` or a narrow wrapper such as `SceneRouter.go_to_arena()` from scenes and systems. Use `SceneRouter.consume_payload()` once from the arriving scene when a transition carries data.

---

# 2. Route Registration

Routes live in the `SceneRegistry` resource embedded in `global/autoloads/scene_router/scene_router.tscn`.

The registry must include:

- `main_menu` — project entry menu.
- `arena` — default gameplay route.
- `test_runner` — unit-test route used by `--test-unit`.

Add route keys that name intent rather than file paths. For this project, prefer small wrappers on `SceneRouter` for production routes that will be called from multiple places.

---

# 3. Navigation API

Preferred calls:

```gdscript
SceneRouter.go_to_arena()
SceneRouter.go_to_main_menu()
SceneRouter.go_to(&"arena", {"spawn_id": spawn_id})
```

Payloads are one-shot hand-offs. The arriving scene owns consumption:

```gdscript
func _ready() -> void:
    var payload: Variant = SceneRouter.consume_payload()
    if payload is Dictionary:
        _load_payload(payload)
```

Do not store long-lived gameplay state in navigation payloads.

---

# 4. Forbidden Patterns

- Do not call `get_tree().change_scene_to_file()` or `get_tree().change_scene_to_packed()` from gameplay scenes.
- Do not add `GameManager.go_to(...)` or reintroduce scene tables into `GameManager`.
- Do not preload navigable scenes at call sites just to transition to them.
- Do not duplicate route strings across callers when a `SceneRouter.go_to_*()` wrapper would make the intent clearer.

---

# 5. Review Checklist

- New navigable scene is registered in `scene_router.tscn`.
- Caller uses `SceneRouter`.
- If payload is used, the arriving scene consumes it once and handles missing/invalid payload gracefully.
- `--test-unit` still routes through `SceneRouter.go_to_test_runner()`.
