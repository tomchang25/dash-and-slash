# Tick Arena Visual Readability 03b: SmallEnemy Offsets And Palette Swap

Parent Plan: `tick_arena_visual_readability_and_identity.md`

## Goal

Refine the landed SmallEnemy variant implementation so pattern identity is authored as explicit local cell offsets and color identity uses palette swapping instead of whole-sprite modulation.

## Summary

Child 03 established four visible SmallEnemy variants, but two implementation details should be tightened before the pattern language grows: fixed attack footprints still execute through an expanding `CellShape` enum/match path, and variant color is currently scene-level `modulate`, which washes out pixel-art shading and makes the body read like a filter rather than a deliberate palette.

This slice normalizes every bounded `CellShape` preset into a local-offset footprint. `LINE`, `WIDE`, `SQUARE`, and `ADJACENT_RING` remain stable authoring presets, while `CUSTOM_OFFSETS` remains the direct authoring path. Offsets are stored relative to the enemy, where `Vector2i.x` means forward distance and `Vector2i.y` means left/right offset from the facing direction. SmallEnemy variants can then express their tactical identity directly: Line is three forward offsets, Sweep is the three cells in the row immediately ahead, Pierce is one forward offset, and Burst is the eight neighboring offsets around the enemy excluding origin. `FULL_LINE` remains the sole dynamic shape because it must stop at the first non-land cell or grid boundary.

This slice also replaces SmallEnemy identity `modulate` with a small palette-swap `CanvasItem` shader and per-variant `ShaderMaterial` resources. The original KappaGreen sheet remains the source texture, variant scenes select a target body palette through material uniforms, and `modulate` returns to being feedback-only for damage flash, stagger tint, and reset.

## Relational Context

- `EnemyAttackData` owns serialized authoring data. Existing enum order remains stable so existing `.tres` resources retain their meaning; SmallEnemy variant scenes point at one data resource whose footprint does not randomly vary at runtime.
- `AttackCellShapes` owns bounded-shape normalization, local-to-grid transformation, and in-bounds filtering. `EnemyAttackController.get_attack_cells()` remains a pure caller of that shared path for every shape except `FULL_LINE`.
- `EnemyAttackController.get_attack_origin_cells()` is used by origin planning and must invert the same local-to-grid transform for every bounded footprint. It may over-approximate `FULL_LINE` origins to the grid axis, because `GridEnemy.plan_cell_attack_action()` verifies the committed footprint before selecting an origin.
- Local offset coordinates are authored in enemy-facing space: `x > 0` is forward, `y > 0` is left, and `y < 0` is right. `FULL_LINE` reuses the single-offset transform but cannot use bounded batch filtering, because it must stop rather than skip a non-land cell.
- Existing formula presets remain valid authoring formats. This slice does not force ChargeEnemy, ModeEnemy, PuffEnemy, or future boss patterns to author explicit offsets unless their data deliberately opts in.
- `DirectionalSpriteFrameView` and `EnemyVisualPresenter` own sprite display and feedback; palette identity must live on the Sprite material while `modulate` remains available for flash and stagger feedback.
- Variant scene materials are presentation data only. They must not affect enemy data, attack timing, telegraph scheduling, damage, recovery, or support spawn selection.

## Scope

### Included

- Normalize bounded shape presets and custom authored offsets through one local-offset computation path.
- Keep `FULL_LINE` dynamic while sharing the common single-offset coordinate transform.
- Move the four SmallEnemy variant data resources from formula shapes to authored offsets.
- Add a reusable enemy palette-swap shader and SmallEnemy variant materials.
- Remove SmallEnemy variant identity `modulate` overrides so feedback can use modulation cleanly.
- Add or update focused tests for offset footprints and reverse origin planning.

### Excluded

- Removing `CellShape` presets or migrating every attack resource to `CUSTOM_OFFSETS`.
- Runtime palette editing, player skin systems, generated PNG output, or external art pipelines.
- Spawn weighting, support pool changes, PuffEnemy cleanup, or ChargeEnemy Skull identity.
- Final art direction or production palette lock-in beyond proving the palette-swap path.

## Files to Change

| File | Change Size | Purpose |
| ---- | ----------- | ------- |
| `data/enemies/definitions/enemy_attack_data.gd` | Small | Add the custom-offset shape and exported local offset array. |
| `game/entities/enemies/enemy_attack_controller.gd` | Medium | Route bounded footprints through the generic offset path and retain dynamic full-line traversal. |
| `game/entities/enemies/attack_cell_shapes.gd` | Medium | Normalize presets, transform local offsets, and preserve formula helper compatibility through that shared path. |
| `game/entities/enemies/enemy_palette_swap.gdshader` | Small | Provide the reusable CanvasItem palette replacement shader for enemy sprites. |
| `game/entities/enemies/materials/small_enemy_sweep_palette.tres` | Small | Define the Sweep target palette material. |
| `game/entities/enemies/materials/small_enemy_pierce_palette.tres` | Small | Define the Pierce target palette material. |
| `game/entities/enemies/materials/small_enemy_burst_palette.tres` | Small | Define the Burst target palette material. |
| `game/entities/enemies/data/small_enemy_line.tres` | Small | Author Line as explicit forward offsets. |
| `game/entities/enemies/data/small_enemy_sweep.tres` | Small | Author Sweep as the three-cell row one step forward. |
| `game/entities/enemies/data/small_enemy_pierce.tres` | Small | Author Pierce as one forward offset with its existing tuning. |
| `game/entities/enemies/data/small_enemy_burst.tres` | Small | Author Burst as eight neighboring offsets excluding origin. |
| `game/entities/enemies/small_enemy_sweep.tscn` | Small | Replace identity modulate with the Sweep palette material. |
| `game/entities/enemies/small_enemy_pierce.tscn` | Small | Replace identity modulate with the Pierce palette material. |
| `game/entities/enemies/small_enemy_burst.tscn` | Small | Replace identity modulate with the Burst palette material. |
| `game/entities/enemies/enemy_visual_presenter.gd` | Small | Ensure base tint remains feedback-safe when identity is material-driven. |
| `test/unit/test_enemy_attack_controller.gd` | Medium | Cover preset and custom-offset committed cells and origin-planning symmetry. |

## Execution Outline

1. Add the data shape for custom offsets, then normalize every bounded preset into one local-offset representation before changing existing variant data.
2. Route committed cells and reverse origin planning through the same local-to-grid transform, retaining only `FULL_LINE` as a dynamic branch with land-continuation traversal.
3. Add focused tests that prove preset and custom offsets resolve to expected cells and that origin planning remains reversible.
4. Convert SmallEnemy variant resources to the custom-offset path while preserving existing damage, warning, recovery, and support-spawn behavior.
5. Add the palette-swap shader and per-variant materials, then update variant scenes to use materials instead of identity `modulate`.
6. Check `EnemyVisualPresenter` feedback return paths with material-driven identity so damage flash, stagger tint, idle, and reset return to clean feedback tint without erasing palette identity.
7. Run standards lint and the focused unit tests for enemy attack controller behavior.

## Implementation Notes

- Offset transform should derive `forward_cell` from current facing and `left_cell` from the perpendicular direction. The committed cell is `origin_cell + forward_cell * offset.x + left_cell * offset.y`; forward cells and reverse origin planning must call that same primitive.
- `LINE`, `WIDE`, `SQUARE`, and `ADJACENT_RING` generators preserve their current dimensions and even-width alignment while returning local offsets. Existing world-cell helper methods delegate to the generic offset path so other callers remain compatible.
- The generic origin planner should iterate every normalized local offset against every cardinal facing, invert the same transform, and append unique in-bounds origins.
- `FULL_LINE` generates its next forward cell through the common transform in a sequential loop. Do not generate a maximum line and pass it to bounded filtering: that would incorrectly continue after a non-land gap.
- Keep existing enum values stable where possible to avoid noisy `.tres` churn. Add the new shape after existing values unless Godot serialization requires a different migration.
- Palette swap should use a small threshold comparison instead of exact RGB equality so Godot import sampling differences do not break replacement. Keep the replacement count small and fixed for this pass.
- Use shared shader code with separate material resources per variant. Do not allocate or mutate per-enemy materials during tick gameplay.
- Do not set variant scene `modulate` for identity after the material lands. Feedback code should remain free to drive `modulate` to white, red, stagger tint, and back to base.

## Edge Cases

| Case | Expected Handling |
| ---- | ----------------- |
| Bounded offset array is empty | The attack computes no cells and preparation fails like any empty footprint. |
| Facing is zero | The controller returns no committed cells and no side effects occur. |
| Offset footprint reaches out of bounds | Out-of-bounds cells are filtered consistently with existing shape helpers when a grid is provided. |
| Palette source color misses by a tiny import delta | The shader threshold still maps the intended source color. |
| Damage flash plays on a palette-swapped sprite | The flash modulates the palette-swapped output and returns to the neutral feedback tint without removing the material identity. |

## Acceptance Criteria

1. SmallEnemy Line, Sweep, Pierce, and Burst footprints are authored as explicit local offsets and still match their intended tactical shapes.
2. Preset and custom-offset committed attack cells and origin planning remain symmetric across cardinal facings.
3. Existing non-SmallEnemy authoring presets continue to work through the normalized path without resource migration.
4. SmallEnemy variant colors read through palette-swapped pixel art rather than whole-sprite color modulation.
5. Damage flash, stagger tint, idle, and reset feedback still work on palette-swapped variants without destroying their identity color.
