# Enemy Kind Unification — Shared Tile And Point Attack Executors

## Goal

Give every enemy kind's attack preparation exactly two shared paths: the existing tile executor for footprint attacks, and a new point executor for single-hitbox attacks. Delete `ModeEnemyAttackController`'s private near-duplicate of tile preparation, and replace ChargeEnemy's and PuffEnemy's hand-rolled hitbox configuration with calls into the shared point executor.

## Relational Context

- `EnemyAttackController` (`game/entities/enemies/enemy_attack_controller.gd`) is already the shared tile executor — `SmallEnemy` composes it correctly today via `%AttackController`. This spec reuses it as-is for ModeEnemy's TILE mode instead of creating a second tile executor; it needs no internal behavior change.
- `ModeEnemy` currently owns one `ModeEnemyAttackController` instance that branches internally on `_mode` (TILE/PUFF/CHARGE) to decide cell shape, hitbox, and fallback data. After this change, `ModeEnemy` owns two executor instances — one tile executor, one point executor — and `ModeEnemy`'s own script picks which instance to call based on `_mode`; neither executor branches on mode internally.
- `ChargeEnemy` and `PuffEnemy` currently configure their single hitbox directly in `_configure_contact_hitbox()` / `_configure_puff_hitbox()`. Both methods are deleted and replaced by a call into a point-executor instance each kind composes as a child node, wired to the hitbox node that already exists in its scene (`ContactHitbox`, `PuffHitbox`).
- The point executor never creates or destroys hitbox nodes — unlike the tile executor, which creates one `Hitbox` per cell at runtime (`node-src: ephemeral`). It only stamps damage/interval/guard-profile fields onto, and enables/disables, a hitbox that already exists as a persistent scene node. Per `dev/foundation/platforms/godot/standards/scene_node_source_standard.md`, that hitbox stays pre-placed in each `.tscn`; the executor is composed as a sibling persistent node, not instantiated at runtime.
- The point executor's cell-based telegraph drive is optional per instance, matching what each kind already does today: ChargeEnemy's charge attack shows a cell telegraph (`_telegraph.show_warning(cells)` today), and so does ModeEnemy's CHARGE and PUFF mode (via `ModeEnemyAttackController`'s shared `_telegraph` calls, which fire for every mode). PuffEnemy shows no cell telegraph at all — it has no `TileTelegraph` node in its scene; its telegraph is the expand/shrink VFX in its Puff state. The executor must not hardcode telegraph-driving as always-on or always-off — it is configured per instance, on for ChargeEnemy's and ModeEnemy's instances, off for PuffEnemy's.
- Profile selection stays where it is: `ModeEnemy._select_attack_data_for_mode()`, `ChargeEnemy._select_attack_data()`, `PuffEnemy._select_attack_data()` are untouched. Executors only consume a profile handed to them; they do not choose one.
- `EnemyAttackController.get_attack_cells` / `get_attack_origin_cells` are static and already callable without an instance. Once `ModeEnemyAttackController` is deleted, ModeEnemy's TILE-mode planning (`plan_next_action`, `can_attack_current_mode`) calls these statics directly instead of through `ModeEnemyAttackController`'s instance wrapper methods.
- Charge movement itself — `begin_charge_attack`/`end_charge_attack` on ChargeEnemy, `_move_to_charge_cell`/`update_attack_motion` on ModeEnemy — is untouched by this spec except that the hitbox enable/disable call inside those methods redirects from a direct field write to the point executor. Movement/traversal consolidation is out of scope here (see the charge-traversal spec).

## Scope

### Included

- A new shared point attack executor component.
- Rewiring ChargeEnemy, PuffEnemy, and ModeEnemy's hitbox configuration through the tile executor (TILE family) or the new point executor (CHARGE/PUFF family).
- Deleting `ModeEnemyAttackController`.
- Scene edits composing the executor(s) as persistent child nodes in `charge_enemy.tscn`, `puff_enemy.tscn`, `mode_enemy.tscn`.

### Excluded

- Charge movement/traversal delivery (separate spec).
- Default/fallback attack-profile source consolidation (separate sketch).
- State-identity override cleanup and node-lookup convention (separate sketches, independent of this spec).
- Any numeric or tuning change to authored or fallback attack data.
- PuffEnemy's and ModeEnemy's puff expand/shrink visual or circular hitbox geometry, which stay bespoke.

## Files to Change

| File                                                         | Change Size     | Purpose                                                                                                                                                                                                                                                                                                  |
| ------------------------------------------------------------ | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `game/entities/enemies/enemy_attack_controller.gd`           | Small           | Existing tile executor; confirm/adjust its `setup`/`prepare` API supports being composed twice in one project (SmallEnemy, ModeEnemy) without shared state — likely no change needed.                                                                                                                    |
| `game/entities/enemies/enemy_point_attack_executor.gd` (new) | Large           | New shared point executor: configures damage/interval/guard-profile on one hitbox from a profile, enables/disables it for the active window, optional cell-telegraph drive.                                                                                                                              |
| `game/entities/enemies/charge_enemy.gd`                      | Medium          | Delete `_configure_contact_hitbox`; wire `begin_charge_attack`/`end_charge_attack` through the point executor instead of the hitbox directly.                                                                                                                                                            |
| `game/entities/enemies/charge_enemy.tscn`                    | Small           | Add a point-executor child node wired to `ContactHitbox` and `TileTelegraph` (telegraph on).                                                                                                                                                                                                             |
| `game/entities/enemies/puff_enemy.gd`                        | Medium          | Delete `_configure_puff_hitbox`; `enable_puff_hitbox()` becomes a thin call into the point executor (telegraph off).                                                                                                                                                                                     |
| `game/entities/enemies/puff_enemy.tscn`                      | Small           | Add a point-executor child node wired to `PuffHitbox` only, no telegraph.                                                                                                                                                                                                                                |
| `game/entities/enemies/mode_enemy.gd`                        | Large           | Replace the single `ModeEnemyAttackController` wiring with two executor instances; dispatch per mode (TILE → tile executor, CHARGE/PUFF → point executor) in `prepare_attack`, `show_attack_warning`, `show_attack_charge`, `begin_attack`, `end_attack`, `can_attack_current_mode`, `plan_next_action`. |
| `game/entities/enemies/mode_enemy.tscn`                      | Medium          | Remove the `AttackController` node (`ModeEnemyAttackController` script); add a tile-executor child (`EnemyAttackController` script) and a point-executor child; keep `TileAttackHitbox`/`ContactHitbox`/`PuffHitbox` as persistent nodes, now wired to the new executors.                                |
| `game/entities/enemies/mode_enemy_attack_controller.gd`      | Large (deleted) | Entire file removed. Its cell-computation duplication (`_get_tile_attack_cells`, `_get_charge_cells`) is superseded by `EnemyAttackController`'s statics, which ModeEnemy can call directly.                                                                                                             |

## Implementation Notes

- ModeEnemy's TILE mode today uses one bounding-box hitbox sized to the footprint's axis-aligned bounding rect (`_apply_tile_hitbox_geometry`), not per-cell hitboxes. Swapping to the shared tile executor changes this to one hitbox per cell, matching SmallEnemy. See the geometry edge case below.
- The point executor needs a constructor/setup parameter (or a boolean field) controlling whether it drives the cell telegraph, since that differs by which kind composes it.
- `ModeEnemy`'s TILE-mode fallback origin-candidate planning (`ModeEnemyAttackController._create_origin_candidate_attack_data`) currently builds a geometry-only partial profile for planning purposes only; once `ModeEnemyAttackController` is deleted, this needs a home — either inline in `ModeEnemy` or migrated into the default-profile source from the separate fallback-consolidation sketch. Do not leave it orphaned.

## Edge Cases

| Case                                                                                                                                        | Expected Handling                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ModeEnemy's TILE mode currently uses one bounding-box hitbox; the shared tile executor creates one hitbox per cell.                         | For the rectangular footprints ModeEnemy's TILE mode uses (WIDE, SQUARE, LINE), per-cell coverage matches the old bounding box's area exactly. Verify damage-tick retrigger timing per sub-cell (each per-cell hitbox tracks its own hit-interval independently) still satisfies the Plan's "attack shapes unchanged" acceptance criterion; flag if it doesn't and preserve single-hitbox behavior for TILE specifically if needed. |
| PuffEnemy has no `TileTelegraph` node; ModeEnemy's PUFF mode currently does show a cell telegraph via the shared controller.                | The point executor's telegraph flag is off for PuffEnemy's instance and on for ModeEnemy's PUFF (and CHARGE) instances — this is existing behavior on both sides and must not regress either kind.                                                                                                                                                                                                                                  |
| ModeEnemy's CHARGE mode currently runs through the generic ATTACK state via `update_attack_motion` overrides, not a dedicated charge state. | Out of scope here — covered by the charge-traversal spec. This spec only replaces hitbox/telegraph preparation, not charge movement delivery.                                                                                                                                                                                                                                                                                       |

## Acceptance Criteria

1. Every point-family attack (ChargeEnemy's charge, PuffEnemy's puff, ModeEnemy's CHARGE and PUFF modes) configures its hitbox's damage, damage interval, and guard-damage profile through the one shared point executor; none hand-configures those fields directly.
2. Every tile-family attack (SmallEnemy's tile attacks, ModeEnemy's TILE mode) computes its footprint and places its hitbox(es) through the one shared tile executor; `ModeEnemyAttackController` no longer exists.
3. Existing telegraph behavior per kind is unchanged: ChargeEnemy and ModeEnemy's CHARGE/PUFF modes still show a cell-based telegraph; PuffEnemy still shows none.
4. Every currently authored attack profile produces the same damage numbers, timings, and effective hit-cell coverage as before the consolidation.
