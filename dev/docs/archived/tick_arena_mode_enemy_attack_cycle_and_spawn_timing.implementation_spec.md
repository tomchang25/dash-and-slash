# Tick Arena ModeEnemy Attack Cycle And Spawn Timing

Parent Plan: none (standalone spec)

## Goal

Shorten enemy spawn warnings and replace ModeEnemy's multi-tick mode-preview loop with a direct attack-selection cycle. ModeEnemy should read as an Octopus-bodied elite whose selected attack determines both pathing and presentation, then reroll after a resolved attack or completed stagger.

## Summary

Spawn warning batches will resolve after one player-action world tick instead of the current two. The existing queue, population-cap, cell revalidation, and spawn-telegraph ownership remain unchanged.

ModeEnemy will stop selecting TILE, PUFF, or CHARGE through a three-tick ModeChange state. It will instead hold one randomly selected authored attack at a time, with each of its five attack resources receiving equal selection weight. The selected attack is the single source for attack eligibility, attack-origin planning, telegraph timing, damage, detonation behavior, and recovery. A resolved attack selects the next attack immediately before recovery, while a guard break cancels the current action and stagger completion selects the next attack before decision-making resumes.

The enemy scene will use the standard Octopus four-direction sprite sheet through a new ModeEnemy-specific presenter. Tile and puff actions use compact SmallEnemy-like squash/pop feedback, while charge actions use ChargeEnemy-like pullback/lunge feedback. The presenter mirrors gameplay intent only; it never owns combat timing, pathing, facing, or attack selection.

## Requirements

1. Resolve each scheduled enemy spawn batch after one player-action world tick while preserving queueing, population-cap, revalidation, and free-action behavior.
2. Remove ModeEnemy's ModeChange state and color-preview delay so attack selection does not consume an enemy action.
3. Select uniformly from the five authored ModeEnemy attacks, making each attack resource rather than each former mode the random-selection unit.
4. Use the selected attack as the shared input for eligibility, path planning, telegraph, detonation, damage, and recovery so movement cannot target a footprint different from the eventual attack.
5. Select a new attack after a resolved attack and after stagger ends; a guard-broken attack must not resume after stagger.
6. Present ModeEnemy with an owned Octopus sprite and attack-kind-aware visual feedback consistent with the existing SmallEnemy and ChargeEnemy presenter contract.

## Relational Context

- WaveController owns spawn-warning countdown state and receives its clock exclusively from TickEngine world advances; EnemySpawner remains responsible only for instantiation and actor registration, so the timing change belongs in WaveController despite the user-facing feature being enemy spawn timing.
- Free player actions do not emit a world advance and therefore must not decrement the one-tick spawn warning.
- EnemyIdleState remains the shared decision dispatcher and reads ModeEnemy's already selected attack through existing hooks; selection must not become a new state or shared-state special case.
- ModeEnemy owns current attack selection. EnemyTickRuntime still owns committed tiles, countdown, and recovery, while states own decision transitions.
- ModeEnemy selects EnemyData attacks directly. AttackKind chooses the planner and detonation branch; the selected EnemyAttackData supplies footprint and timing. Do not recreate a mode enum or duplicate tuning in script.
- TILE uses shared cell-origin planning, CHARGE uses shared charge-origin planning, and PUFF approaches until its selected radius covers the player. Unreachable geometry keeps the same attack rather than rerolling.
- Resolution clears attack presentation and selects the next attack before recovery. Guard break uses GridEnemy's existing cancellation path; the interrupted selection is overwritten only when stagger ends.
- GridEnemy remains the caller for shared presenter intent. ModeEnemy supplies attack-kind context plus prepare/commit intent; the presenter owns only interruptible transforms and frame feedback, never gameplay timing, pathing, selection, or facing.
- The scene owns persistent presenter/sprite nodes and references a copied feature-owned Octopus texture, never the ignored `res://assets/` source.
- The legacy Polygon2D body remains as the established missing-texture fallback but is hidden when the Octopus texture is valid. Mode colors and preview APIs become obsolete and must not remain as a second visual identity path.

## Scope

### Included

- One-tick spawn warnings and regression updates.
- Direct attack selection, matching pathing, reroll boundaries, and ModeChange cleanup.
- Owned Octopus asset, presenter, scene wiring, and focused verification.

### Excluded

- Spawn weighting, wave composition, attack retuning, other enemy behavior, and animation-driven combat timing.

## Files to Change

| File                                                               | Change Size | Purpose                                                              |
| ------------------------------------------------------------------ | ----------- | -------------------------------------------------------------------- |
| `game/tick_arena/wave/wave_controller.gd`                          | Small       | Use a one-tick spawn warning.                                        |
| `test/unit/test_wave_controller.gd`                                | Medium      | Update countdown/queue regressions.                                  |
| `game/entities/enemies/mode_enemy.gd`                              | Large       | Own direct selection, matching behavior, rerolls, and visual intent. |
| `game/entities/enemies/mode_enemy.tscn`                            | Medium      | Replace ModeChange with Octopus presenter wiring.                    |
| `game/entities/enemies/mode_enemy_visual_presenter.gd`             | Medium      | Add attack-kind-aware feedback.                                      |
| `game/entities/enemies/assets/mode_enemy/octopus_sprite_sheet.png` | Small       | Own the runtime texture.                                             |
| `game/entities/enemies/states/enemy_idle_state.gd`                 | Small       | Remove pre-decision dispatch.                                        |
| `game/entities/enemies/states/enemy_state.gd`                      | Small       | Remove the ModeChange ID.                                            |
| `game/entities/enemies/states/mode_enemy_mode_change_state.gd`     | Small       | Delete the obsolete state.                                           |
| `game/entities/enemies/states/mode_enemy_mode_change_state.gd.uid` | Small       | Delete its UID sidecar.                                              |
| `game/entities/enemies/grid_enemy.gd`                              | Small       | Remove the pre-decision hook.                                        |
| `game/entities/enemies/data/mode_enemy.tres`                       | Small       | Remove mode colors; retain attacks.                                  |
| `data/enemies/definitions/enemy_data.gd`                           | Small       | Remove the unused mode-color field.                                  |
| `test/unit/test_mode_enemy_attack_cycle.gd`                        | Medium      | Cover selection, wiring, and rerolls deterministically.              |

## Execution Outline

1. Set spawn warning to one tick and update initial/queued batch regressions.
2. Add deterministic ModeEnemy cycle coverage, then switch selection and planning to the authored attacks.
3. Add post-resolution and post-stagger rerolls while retaining the selected attack on failed planning/preparation.
4. Delete ModeChange and its shared hooks, then remove obsolete mode-color data.
5. Add the owned Octopus asset, presenter, scene wiring, and hidden-body fallback.
6. Run focused unit coverage and standards lint on all changed files.

## Implementation Notes

### Attack selection and lifecycle

- Use the authored array as the uniform pool: three tile entries, charge, and puff. Ready/setup/reset must leave one valid selection without double-rolling.
- Resolution establishes existing recovery, including its `+1` compensation, then rerolls without consuming an FSM tick. Stagger completion rerolls before Idle resumes.
- Missing EnemyData generates a valid profile from the same five conceptual attacks without restoring modes.

### Planning and commit

- The selected resource drives TILE cells/origins, CHARGE origins/line/landing, and PUFF radius. All kinds commit inline and park in Idle while EnemyTickRuntime freezes timing.

### Presentation

- Set presentation-only AttackKind context on every selection. Tile/puff use compact cues; charge uses facing-aware pullback/lunge; all tweens yield to idle, stagger, reset, or death.
- Copy only Octopus `SpriteSheet.png`, not its `.import`; use nearest filtering, integer scale, and the existing four-by-four frame contract.

## Edge Cases

| Case                                   | Expected Handling                                           |
| -------------------------------------- | ----------------------------------------------------------- |
| Free action during spawn warning       | No world advance means the warning remains pending.         |
| Spawn cell becomes invalid             | Existing resolution relocates or requeues it.               |
| No ideal attack origin is reachable    | Approach/retry with the same attack.                        |
| Guard breaks during telegraph/recovery | Cancel runtime/presentation; reroll only when stagger ends. |
| Octopus texture is invalid             | Report the existing dev error and show Polygon2D fallback.  |
| EnemyData is missing                   | Create a valid fallback attack without ModeChange.          |

## Acceptance Criteria

1. A scheduled spawn batch telegraphs immediately and resolves on the next player-action world tick, while free actions do not advance it.
2. ModeEnemy never enters or displays a ModeChange state and spends no action on attack selection.
3. Each attack cycle holds exactly one authored attack whose footprint and kind govern planning, commit, telegraph, damage, detonation, and recovery.
4. The three tile attacks, charge attack, and puff attack are individually eligible at equal random weight.
5. A resolved attack selects the next attack before recovery completes, and an interrupted attack is replaced when stagger ends rather than resumed.
6. ModeEnemy uses the Octopus sprite with correct four-direction facing and readable move, prepare, commit, damage, stagger, idle, reset, and fallback presentation.
7. Existing tile footprints, puff radius behavior, full-line charge landing, damage values, warning durations, and recovery durations remain unchanged.
