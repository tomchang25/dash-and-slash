# Scene Router Usage

Use this when adding or changing scene navigation.

## Add a route

1. Add the target scene as an `ext_resource` in `global/autoloads/scene_router/scene_router.tscn`.
2. Add a stable key to the embedded `SceneRegistry.routes` dictionary.
3. Navigate with `SceneRouter.go_to(&"route_key")` or a narrow `go_to_*()` wrapper.
4. If this is the Play button target, set `SceneRegistry.default_route` to the new key and update `SceneRouter.go_to_arena()` if the arena entry changes.

## Pass context

```gdscript
SceneRouter.go_to(&"arena", {"spawn_id": spawn_id})
```

In the arriving scene:

```gdscript
var payload: Variant = SceneRouter.consume_payload()
if payload is Dictionary:
    var spawn_id := String(payload.get("spawn_id", ""))
```

Payloads are transition context only. Save durable state through the project's save owner.

## Avoid

- `GameManager.go_to(...)`
- Direct `get_tree().change_scene_*()` from normal game screens
- Preloading scene files at each caller
