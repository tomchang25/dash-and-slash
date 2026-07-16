# Enemy Kind Unification — Attack Node Lookup Unification

## Goal

Convert ChargeEnemy's and PuffEnemy's attack-related child-node lookups from the dynamic `_find_child_node` fallback to `%UniqueName` references, matching SmallEnemy and ModeEnemy, so wiring or auditing an enemy's attack nodes doesn't depend on remembering which of two lookup styles that kind uses.

## Requirements

1. ChargeEnemy's `ContactHitbox` and `TileTelegraph` lookups convert to `%ContactHitbox` / `%TileTelegraph` — both nodes already carry `unique_name_in_owner = true` in `charge_enemy.tscn`, so this is a script-only change with no scene edit required.
2. PuffEnemy's `PuffHitbox` lookup converts to `%PuffHitbox` — `puff_enemy.tscn` already marks it unique, so this is likewise script-only.
3. `GridEnemy`'s own base-class lookups (`Guard`, `StatusBars`, `Hurtbox`, `Body`, `FacingArrow`, all via `_find_child_node`) are out of scope. The plan's requirement is scoped to attack-related child nodes (hitboxes, telegraph) specifically, not every node lookup on every kind.

## Design

`_find_child_node` stays in `GridEnemy` as the shared base-class helper for the lookups outside this change's scope, and remains available project-wide for genuinely dynamic or test-only lookups per `dev/foundation/platforms/godot/standards/scene_node_source_standard.md`. This change only touches the two kinds' attack-node accessors, converting them to the project's preferred `%UniqueName` `@onready` style — the same style `SmallEnemy` and `ModeEnemy` already use for their attack nodes.

## Sketch (non-normative)

`game/entities/enemies/charge_enemy.gd`, replace:

```gdscript
@onready var _contact_hitbox: Hitbox = _find_child_node("ContactHitbox") as Hitbox
@onready var _telegraph: TileTelegraph = _find_child_node("TileTelegraph") as TileTelegraph
```

with:

```gdscript
@onready var _contact_hitbox: Hitbox = %ContactHitbox
@onready var _telegraph: TileTelegraph = %TileTelegraph
```

`game/entities/enemies/puff_enemy.gd`, replace:

```gdscript
@onready var _puff_hitbox: Hitbox = _find_child_node("PuffHitbox") as Hitbox
```

with:

```gdscript
@onready var _puff_hitbox: Hitbox = %PuffHitbox
```

No `.tscn` changes: `ContactHitbox` and `TileTelegraph` in `charge_enemy.tscn`, and `PuffHitbox` in `puff_enemy.tscn`, already have `unique_name_in_owner = true` set — the scenes already support `%UniqueName` access, the scripts simply weren't using it.

## Non-Goals

1. No change to `GridEnemy`'s `_find_child_node` helper or its use for `Guard`, `StatusBars`, `Hurtbox`, `Body`, `FacingArrow`.
2. No change to `SmallEnemy` or `ModeEnemy`, which already use `%UniqueName` for their attack nodes.

## Acceptance Criteria

1. ChargeEnemy and PuffEnemy locate their attack-related nodes the same way SmallEnemy and ModeEnemy do.
2. No enemy kind uses `_find_child_node`, `get_node_or_null`, or `find_child` for an attack-related node (hitbox or telegraph).
3. Scene files are unchanged; only script node-reference declarations differ.
