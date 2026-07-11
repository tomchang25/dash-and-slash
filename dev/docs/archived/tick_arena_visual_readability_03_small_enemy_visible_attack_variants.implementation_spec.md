# Tick Arena Visual Readability 03: SmallEnemy Visible Attack Variants

Parent Plan: `tick_arena_visual_readability_and_identity.md`

## Goal

Replace SmallEnemy's hidden random attack profile with four visible, color-coded SmallEnemy variants so the same Kappa-family body becomes the main readable support-enemy content multiplier.

## Summary

SmallEnemy should stop being one scene that randomly chooses between multiple attack profiles. This slice turns it into a small family of stable variants: Line, Sweep, Pierce, and Burst. Each variant keeps the shared SmallEnemy behavior and presenter, but points at one authored `EnemyData` resource and one Godot-side sprite tint so the player's first read is "this color means this attack shape."

| Variant | Attack identity | Footprint |
| ------- | --------------- | --------- |
| Line | baseline lane pressure | three cells straight ahead |
| Sweep | near forward-width pressure | the three-cell row one step in front of the enemy |
| Pierce | high-damage point threat | one cell straight ahead |
| Burst | close surround pressure | the eight cells adjacent to the enemy, excluding the enemy's own cell |

Support-pool cleanup is specified separately in child 03a. This spec only defines the Kappa-family SmallEnemy variants and the support-pool entries needed for those variants.

## Relational Context

- SmallEnemy owns tile attack setup through `EnemyAttackController`; variants must change authored attack data, not fork SmallEnemy gameplay logic.
- EnemyData owns which attack profile a scene can select. Each visible variant should reference exactly one attack profile so visible color does not lie about behavior.
- `EnemyAttackController.get_attack_cells()` and `get_attack_origin_cells()` must stay symmetric. Any new Burst footprint shape needs both committed footprint computation and origin-planning support.
- `AttackCellShapes.square()` includes the origin cell today. Burst must not reuse it directly unless the origin cell is removed by a named helper, because the enemy's own cell must not be part of the attack.
- Variant color is presentation data on the scene/presenter path. Damage flash, stagger tint, reset, and idle restore must settle back to the variant's base tint rather than hard-coded white.
- WaveController owns support scene selection. This visual identity slice adds the four SmallEnemy variant scenes that child 03a will combine with the non-SmallEnemy support entries.

## Scope

### Included

- Four visible SmallEnemy attack variants using fixed attack data and Godot-side sprite color.
- A new adjacent-ring attack footprint for the Burst variant if no existing shape can express eight neighboring cells excluding self.
- Support pool update to expose the four visible SmallEnemy variants as spawnable support scenes.

### Excluded

- PNG edits, generated asset pipelines, final pixel-art polish, or weapon/silhouette marker art.
- Weighted spawn economy, wave-by-wave spawn tuning, or reward-driven spawn modifiers.
- PuffEnemy behavior deletion or redesign, non-SmallEnemy sprite replacement, and final support pool cleanup; those are handled by child 03a.
- Boss, ModeEnemy, player, or character-class changes.

## Files to Change

| File | Change Size | Purpose |
| ---- | ----------- | ------- |
| `data/enemies/definitions/enemy_attack_data.gd` | Small | Add a named cell shape for Burst's adjacent ring if required. |
| `game/entities/enemies/attack_cell_shapes.gd` | Small | Add the adjacent-neighbor footprint helper that excludes the origin cell. |
| `game/entities/enemies/enemy_attack_controller.gd` | Medium | Route the new shape through attack-cell computation and origin planning. |
| `game/entities/enemies/enemy_visual_presenter.gd` | Small | Preserve scene-authored base sprite tint through damage, stagger, idle, and reset feedback. |
| `game/entities/enemies/data/small_enemy_line.tres` | Small | Author the three-cell forward line variant data. |
| `game/entities/enemies/data/small_enemy_sweep.tres` | Small | Author the one-row, three-cell forward sweep variant data. |
| `game/entities/enemies/data/small_enemy_pierce.tres` | Small | Author the one-cell high-damage pierce variant data. |
| `game/entities/enemies/data/small_enemy_burst.tres` | Small | Author the adjacent-ring burst variant data. |
| `game/entities/enemies/small_enemy.tscn` | Small | Convert the existing scene into the Line variant or keep it as the Line scene target with a single line-only data resource. |
| `game/entities/enemies/small_enemy_sweep.tscn` | Medium | Add a colored SmallEnemy scene variant using Sweep data. |
| `game/entities/enemies/small_enemy_pierce.tscn` | Medium | Add a colored SmallEnemy scene variant using Pierce data. |
| `game/entities/enemies/small_enemy_burst.tscn` | Medium | Add a colored SmallEnemy scene variant using Burst data. |
| `game/tick_arena/wave/wave_controller.gd` | Medium | Add the four SmallEnemy variant scenes to the support-pool surface that child 03a finalizes. |

## Execution Outline

1. Add the adjacent-ring footprint support first, including both committed-cell and origin-planning paths, so Burst can be authored like the other variants.
2. Update EnemyVisualPresenter tint handling so scene-authored variant colors survive flash, stagger, idle, and reset.
3. Split SmallEnemy attack data into four one-profile resources and make the existing SmallEnemy scene line-only.
4. Add Sweep, Pierce, and Burst scene variants by reusing the SmallEnemy scene structure, `SmallEnemy.gd`, and `SmallEnemyVisualPresenter`, changing only data resource and sprite tint.
5. Update WaveController's support scene constants/pool surface so the visible SmallEnemy variants are available and the old hidden-random SmallEnemy scene is not the only SmallEnemy entry.
6. Run standards lint on changed files and the narrow Godot parse/check needed for the touched scripts and scenes.

## Implementation Notes

- Suggested variant colors: Line keeps the current green/Kappa read, Sweep uses cyan/blue, Pierce uses gold/yellow, and Burst uses purple. Avoid red for SmallEnemy variants because red should not compete with damage flash.
- Sweep is not self-centered. It is `WIDE` with `depth = 1` and `width = 3`, producing the row one step in front of the enemy.
- Pierce can use `LINE` with `line_length = 1`, higher damage than the baseline, and conservative recovery if playtest needs the single-cell hit to feel fair.
- Burst should be a new explicit shape such as `ADJACENT_RING` using `radius = 1`; it should include diagonals and orthogonals around the enemy but not the origin cell.
- Do not keep multiple attacks on a visible SmallEnemy variant's data resource. If an enemy can roll different shapes, its color no longer communicates a stable tactical question.
- The SmallEnemy variant entries can remain a simple scene array, not a weighted spawn system. Child 03a owns the final non-SmallEnemy entries.

## Edge Cases

| Case | Expected Handling |
| ---- | ----------------- |
| Burst origin planning includes the enemy's own cell | The helper excludes `Vector2i.ZERO` offset so the enemy cell is never telegraphed or damaged. |
| Variant takes damage while tinted | Damage flash returns to the variant's base tint, or to stagger tint if stagger is active. |
| Existing code still loads `small_enemy.tscn` | The scene remains valid and behaves as the Line variant rather than a hidden-random mixed variant. |

## Acceptance Criteria

1. Four SmallEnemy variants are readable by color before they attack and each variant uses one stable attack footprint.
2. Line, Sweep, Pierce, and Burst ask distinct tactical questions without adding new SmallEnemy behavior code.
3. Burst attacks the eight adjacent cells around itself and never includes its own occupied cell.
4. The old hidden-random SmallEnemy scene is no longer the only SmallEnemy support entry.
5. The spec leaves support-pool cleanup to child 03a without duplicating that scope.
