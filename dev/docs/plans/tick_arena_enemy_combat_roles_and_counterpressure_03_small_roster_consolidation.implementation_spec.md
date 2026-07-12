# Tick Arena Enemy Combat Roles And Counterpressure 03: Small Roster Consolidation

Parent Plan: `tick_arena_enemy_combat_roles_and_counterpressure.md`

## Goal

Replace the four interchangeable Small production variants with Thrust and Slash, two clearly named melee identities that teach forward-lane and lateral-sweep positioning. Park Pierce and Burst safely while removing them from authored production composition.

## Summary

The existing base Small scene and Line resource become Thrust: a locked three-cell forward lane. The existing Sweep scene and resource become Slash: a locked three-cell row immediately in front. Both keep shared `SmallEnemy` behavior, the Small Guard profile, and the standard attack controller rather than gaining role-specific scripts.

Production catalog entries and tests move to the two names. Pierce and Burst scenes, resources, and palettes remain loadable as parked content, but no default wave or production-roster assertion may select them. This child does not decide final counts, wave composition, or Bomb/Ranged additions.

## Relational Context

- `SmallEnemy` owns shared planning, telegraph lifecycle, and its selected `EnemyAttackData`; role identity comes from scene-assigned `EnemyData`, not new subclasses.
- `EnemyAttackController` transforms authored local offsets into the committed footprint used by preview, warning, and detonation. Thrust and Slash retain current Line and Sweep offsets rather than introducing new geometry code.
- `default_wave_catalog.tres` is the current production composition authority. Removing entries there prevents weighted expansion from selecting parked Pierce or Burst scenes.
- WaveController fixtures use scene preloads as generic spawn identities. Rename those references with production assets without changing group-scheduling assertions.
- Child 01 owns Guard profile migration and lands first. This child consumes its Small assignments rather than restoring per-enemy max-Guard tuning.

## Scope

### Included

- Rename Line/Sweep authored scene and data identities to Thrust/Slash.
- Preserve their exact attack offsets and shared behavior.
- Remove Pierce/Burst from default catalog and production-roster tests while leaving parked assets loadable.

### Excluded

- Bomb/Ranged scenes, formations, final demo/endless composition, and numeric wave balance.
- Deletion of parked Pierce/Burst files, palette materials, or historical documents.
- Separate Thrust/Slash scripts, player attack changes, and visual-system redesign.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `game/entities/enemies/small_enemy.tscn` → `game/entities/enemies/thrust_enemy.tscn` | Medium | Rename base Line scene to Thrust identity. |
| `game/entities/enemies/small_enemy_sweep.tscn` → `game/entities/enemies/slash_enemy.tscn` | Small | Rename Sweep variant to Slash identity. |
| `game/entities/enemies/data/small_enemy_line.tres` → `game/entities/enemies/data/thrust_enemy.tres` | Small | Rename data, identifier, and display name while keeping three forward offsets. |
| `game/entities/enemies/data/small_enemy_sweep.tres` → `game/entities/enemies/data/slash_enemy.tres` | Small | Rename data, identifier, and display name while keeping three-cell forward row. |
| `data/waves/default_wave_catalog.tres` | Medium | Replace Thrust/Slash references and remove Pierce/Burst from every weighted group. |
| `test/unit/test_enemy_progression_data.gd` | Medium | Update production-resource and scene assertions for active Small identities. |
| `test/unit/test_enemy_attack_controller.gd` | Small | Name footprint regressions after Thrust and Slash. |
| `test/unit/test_wave_controller.gd` | Medium | Update scene preloads and fixtures without changing scheduling assertions. |

## Execution Outline

1. Rename active resources and scenes, updating root names, identifiers, display labels, and inheritance references while preserving shared Small behavior.
2. Repoint catalog and tests to Thrust/Slash, then remove Pierce/Burst from every default weighted entry.
3. Verify exact footprints and catalog selection boundaries, leaving parked assets untouched and loadable.

## Implementation Notes

- Thrust retains `(1,0)`, `(2,0)`, `(3,0)`. Slash retains `(1,-1)`, `(1,0)`, `(1,1)`. Keep explicit custom offsets; do not replace them with generic LINE/WIDE defaults.
- Keep current green base presentation for Thrust and Sweep palette presentation for Slash unless the rename only requires reference rewiring. Their visual difference remains role identity, not a new presenter architecture.
- Use Godot-aware moves/renames so scene/resource references remain valid. Update catalog ext-resources and direct test preloads in the same change.
- Leave Pierce/Burst scenes, data, and palettes in place. They must have no default-catalog or production-roster expectation after this child.
- Do not rebuild the provisional catalog into final wave 4–9 scheduling here; the deferred balance and later formation children own that authored pass.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| A footprint test loads renamed data | It observes former Line/Sweep ordered cells for every cardinal facing. |
| Weighted expansion runs after migration | It can choose Thrust, Slash, Charge, and existing non-Small entries, never Pierce or Burst. |
| A parked Pierce/Burst scene is instantiated by isolated fixture | It remains loadable until an explicit cleanup scope deletes it. |
| A later child adds Bomb or Ranged | It adds its own assets/catalog entries without changing shared Thrust/Slash behavior. |

## Acceptance Criteria

1. Production Small encounters expose only Thrust and Slash, both using shared Small behavior and the Small Guard profile.
2. Thrust and Slash show the former Line/Sweep locked footprints in preview, warning, and detonation.
3. Default catalog composition and production tests never select Pierce or Burst, while parked assets still load.
