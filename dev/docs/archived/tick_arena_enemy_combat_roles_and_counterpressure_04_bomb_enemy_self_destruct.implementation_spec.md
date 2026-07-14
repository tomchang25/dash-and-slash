# Tick Arena Enemy Combat Roles And Counterpressure 04: Bomb Enemy Self-Destruct

Parent Plan: `tick_arena_enemy_combat_roles_and_counterpressure.md`

## Goal

Add a guardless Bomb role that turns close pursuit into a readable kill-or-evade deadline, then removes itself through normal enemy death and wave bookkeeping.

## Summary

The standalone Puff enemy becomes Bomb with no Puff identity or runtime legacy left behind. Bomb has base HP 50, Defense 0, tick speed 75, and a base 50-damage self-destruct. It approaches until the player enters its eight-cell adjacent ring, locks the in-bounds cells within Manhattan distance four of its commit cell (a diamond where a diagonal step costs two), and detonates after three normal world advances; free actions do not shorten the fuse.

Bomb has no Guard component or Staggered state. Killing it during the fuse cancels the locked threat, while a surviving Bomb damages the player only if the player's post-action cell remains inside the locked footprint, then kills itself even on a miss. The self-kill goes through `Health` so TickEngine removal, wave population, completion, and the shared death presentation remain authoritative.

LanternRed becomes Bomb's owned sprite asset and uses the existing directional presenter scaffold. A Bomb-specific presenter adds a slow fuse blink during windup and a faster final-tick blink, with complete cleanup on cancellation, death, detonation, and reset. The standard danger fill/countdown and existing full-footprint detonation flash remain the only attack-area presentation; this child does not introduce a BombAttack VFX system or special telegraph payload.

Mode keeps its current square area attack behavior under neutral `AREA` vocabulary. All standalone Puff files, identifiers, enum names, comments, presenter wording, radial windup support, and active-zone-only data fields are removed or renamed rather than retained as compatibility aliases.

## Relational Context

- `BombEnemy` decides when adjacency permits commitment, while its inherited `EnemyTickRuntime` remains the sole owner of the locked footprint and three-step countdown; enemy states must not own fuse counters, timers, or attack phases.
- `TickEngine` calls detonation before funded enemy actions on each normal world advance. Bomb reads the player's post-action cell through that engine stage, so Speed-spent free actions neither decrement the fuse nor grant Bomb an unfunded action.
- `BombEnemy` computes the centered Manhattan-distance-four diamond once from its commit cell and stores that snapshot in `EnemyTickRuntime`; later player movement changes hit membership but never recenters or retargets the explosion.
- `TickArena` reads Bomb's ordinary `{cells, ticks}` danger payload and forwards detonation cells to the existing grid flash. Bomb must not add a danger kind, custom telegraph channel, or parallel area-VFX owner.
- `BombEnemyVisualPresenter` owns only LanternRed frame and fuse-blink presentation. Bomb gameplay invokes the existing prepare/commit/idle semantic presenter contract; the presenter never owns countdown, damage, footprint, or death state.
- Bomb resolves player damage through `TickEngine.damage_player()` before killing itself through `Health`; the resulting `Enemy.died` signal remains the only write into `WaveController` alive counts, TickEngine registration, boss/group bookkeeping, and wave completion.
- A null `EnemyData.guard_profile` plus an omitted Guard scene node makes the shared hit snapshot report `has_guard = false`; `TickHitResolver` then applies full HP damage, while Guard Shredder, Stagger, protection, and shield presentation remain inactive without Bomb-specific branches.
- `EnemyAttackData.AttackKind.AREA` replaces the existing `PUFF` enum slot and is consumed by both Bomb data and Mode's surviving square-area selection. Mode keeps its behavior; no compatibility enum or Puff-named authored identifier remains.
- The Bomb scene depends on a feature-owned copy of LanternRed under `game/entities/enemies/assets/bomb_enemy/`; it must never reference the ignored root vendor `assets/` tree or copy its `.import` sidecar.

## Scope

### Included

- Replace standalone Puff script, scene, data, tests, and identifiers with Bomb.
- Add the guardless three-tick locked self-destruct lifecycle and Bomb-specific fuse blinking.
- Preserve Mode's area behavior while removing Puff terminology and obsolete standalone-zone support.
- Add one fixed Wave 1 Bomb test group after the initial weighted support group, with population headroom for all four enemies.
- Add focused data, countdown, footprint, disarm, detonation-order, self-death, and cleanup coverage.

### Excluded

- Final Bomb wave composition, counts, spawn bands, and formations; child 07 owns production integration after the fixed Wave 1 manual-test entry.
- Custom Bomb telegraph cells, danger payloads, explosion particles, smoke, persistent hazards, chain reactions, ally damage, collision damage, or bespoke audio.
- Changes to Mode's attack geometry or timing beyond neutral vocabulary migration.
- Final HP, damage-growth, Defense-growth, or encounter balance beyond the confirmed level-one Bomb values.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `data/enemies/definitions/enemy_attack_data.gd` | Medium | Replace Puff attack vocabulary with neutral area vocabulary and remove obsolete active-zone-only fields. |
| `game/entities/enemies/puff_enemy.gd` -> `game/entities/enemies/bomb_enemy.gd` | Large | Replace the multi-tick Puff zone with Bomb adjacency commitment, a locked Manhattan-distance-four fuse footprint, detonation, and self-death behavior. |
| `game/entities/enemies/puff_enemy.tscn` -> `game/entities/enemies/bomb_enemy.tscn` | Large | Rebuild the concrete guardless Bomb wiring around LanternRed, the shared intent states, status bars, and death path. |
| `game/entities/enemies/data/puff_enemy.tres` -> `game/entities/enemies/data/bomb_enemy.tres` | Medium | Author Bomb identity, HP 50, Defense 0, no Guard profile, and the 50-damage three-tick Manhattan-distance-four area attack. |
| `game/entities/enemies/bomb_enemy_visual_presenter.gd` | Medium | Add Bomb-specific slow and final-tick fuse blink presentation on the shared presenter contract. |
| `game/entities/enemies/assets/bomb_enemy/lantern_red_sprite_sheet.png` | Small | Own the LanternRed runtime source asset within the enemy feature. |
| `common/gameplay/vfx/combat_feedback_vfx.gd` | Small | Remove obsolete Puff radial windup style, constants, and pulse branch. |
| `game/entities/enemies/mode_enemy.gd` | Small | Migrate the surviving Mode square-area planning and fallback selection to `AREA` terminology. |
| `game/entities/enemies/mode_enemy_visual_presenter.gd` | Small | Remove Puff wording from the presentation contract while preserving behavior. |
| `game/entities/enemies/data/mode_enemy.tres` | Small | Rename the authored Mode area subresource and identifier without changing its values. |
| `game/entities/enemies/data/mode_boss.tres` | Small | Rename the placeholder boss area subresource and identifier without changing its values. |
| `data/waves/default_wave_catalog.tres` | Small | Add one deterministic Wave 1 Bomb test group and concurrent-population headroom. |
| `test/unit/test_enemy_progression_data.gd` | Medium | Replace Puff production expectations with Bomb level-one and guardless scene assertions. |
| `test/unit/test_mode_enemy_attack_cycle.gd` | Small | Verify neutral area vocabulary preserves Mode selection and planning semantics. |
| `test/unit/test_bomb_enemy_self_destruct.gd` | Large | Cover commitment, locked countdown, disarm, hit/miss detonation, self-death ordering, and presentation cleanup seams. |
| `test/unit/test_wave_controller.gd` | Small | Lock the deterministic Wave 1 Bomb test entry without broadening weighted-roster assertions. |

## Execution Outline

1. Migrate shared attack vocabulary from Puff to Area, update Mode code/resources/tests in the same beat, and remove obsolete Puff-only data and radial windup support without changing Mode behavior.
2. Move the standalone Puff script/data/scene identities to Bomb, move the script's `.gd.uid` sidecar with it so Godot references retain UID continuity, and replace the old zone lifecycle with the shared committed-footprint countdown and normal death path.
3. Copy LanternRed into Bomb-owned assets without its vendor `.import` sidecar, wire the standard directional sprite scaffold, and add the Bomb presenter fuse lifecycle.
4. Add one fixed Wave 1 Bomb group after the initial weighted support group, increase Wave 1's population cap to four, and assert that manual-test entry separately from the weighted-role roster check.
5. Update progression/resource coverage for HP 50, Defense 0, no Guard, base damage 50, and speed 75, then add focused Bomb runtime tests for countdown, locked cells, early death, detonation, and bookkeeping order.
6. Search active runtime code, resources, scenes, and tests for stale Puff identities, run the standards linter on every touched file, and leave runtime timing and visual readability for manual Godot confirmation.

## Implementation Notes

- Keep `AREA` in the current serialized enum position formerly occupied by `PUFF` so Mode `.tres` values do not silently change meaning. Rename Mode's `attack_puff`/`mode_puff` identities to area equivalents and remove compatibility aliases.
- Remove the standalone `PuffPhase`, active-zone rechecks, expand/shrink body VFX, `WindupStyle.PUFF`, and the obsolete `active_duration` and `recheck_interval` data fields. Retain generic fields still consumed by another attack kind.
- Bomb's level-one values are HP 50, Defense 0, speed 75, and damage 50. HP and outgoing damage continue through the existing wave projection; the authored damage is not a bypass around the shared multiplier.
- Commit when the player is horizontally, vertically, or diagonally adjacent. Use the authored Manhattan radius of four to lock only in-bounds cells around Bomb's current cell; diagonal movement costs two, and Bomb facing does not select or orient the symmetric footprint.
- At detonation, preserve the locked cells long enough to resolve player damage and emit the existing detonation flash, clear attack/presenter state idempotently, then self-kill. Do not enter recovery or allow a dead Bomb into the later action stage.
- The Bomb scene omits Guard and Staggered nodes rather than carrying disabled legacy components. Keep Idle, Reposition, FaceOnce, and Dead as the existing intent/interrupt states; the pending runtime attack freezes movement after commitment.
- Copy only LanternRed's source PNG from the vendor tree, wire it with the existing four-by-four `DirectionalSpriteFrameView`, and let Godot generate the destination import metadata.
- Implement the fuse blink inside `BombEnemyVisualPresenter`: normal prepare feedback loops slowly, the inherited last-tick commit cue replaces it with a faster blink, and idle/reset/death cleanup restores neutral transform and opacity. Keep it from racing the base damage-flash tint.
- Do not add a Bomb-specific detonation signal or footprint effect. The existing cell flash already covers every locked cell and remains authoritative at clipped arena edges.
- The manual-test catalog entry is a fixed second Wave 1 group with one-tick warning and an immediate-overlap condition. Wave 1 keeps its existing three weighted support enemies and gains population cap four, so Bomb appears reliably after that support batch without entering weighted or endless composition.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Player uses a free Speed action during the fuse | The visible count and Bomb state do not advance. |
| Player leaves after commitment | The footprint stays at the original Bomb cell and misses if the new player cell is outside it. |
| Bomb commits beside an arena edge | Only in-bounds cells in the Manhattan-distance-four diamond warn, flash, and participate in hit membership. |
| Bomb dies on the player action that would otherwise advance the final fuse step | Death unregisters it before detonation, clears the warning/blink, and deals no explosion damage. |
| Detonation misses or the player survives/lethally dies | Bomb still self-kills after the damage attempt and reports one normal enemy death. |
| Reset or run cleanup interrupts a pending Bomb | Locked cells and fuse presentation clear once without a later detonation. |
| A player hit carries Guard-specific Major triggers | Bomb takes ordinary full HP damage and never triggers Guard Break, Stagger, protection, or Guard-only feedback. |

## Acceptance Criteria

1. Bomb approaches at speed 75, commits only from the adjacent ring, visibly locks a Manhattan-distance-four diamond explosion for three normal world advances, and cannot move or retarget during the fuse.
2. A level-one Bomb has 50 HP, 0 Defense, no Guard, and a base 50-damage explosion; previews and resolved hits never show blocked, Guard Break, Stagger, or protection behavior.
3. Killing Bomb before detonation immediately disarms its warning and fuse presentation, while a surviving Bomb resolves against the locked footprint and then dies exactly once through normal wave bookkeeping.
4. LanternRed presents Bomb's directional actions, blinks throughout windup, accelerates on the final tick, and returns to a clean visual state after cancellation, death, detonation, or reset.
5. The ordinary danger countdown and existing full-footprint detonation flash communicate Bomb's complete attack area without a special telegraph or BombAttack VFX architecture.
6. Mode retains its established square area attack behavior under neutral Area vocabulary, and active runtime code, scenes, resources, and tests retain no standalone Puff identity or compatibility path.
7. Every fresh run exposes exactly one Bomb through Wave 1's fixed test group, while weighted and endless roster composition remains unchanged.
