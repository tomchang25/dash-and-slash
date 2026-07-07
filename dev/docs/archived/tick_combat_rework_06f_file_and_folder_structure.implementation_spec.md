# Tick Combat Rework 06f: File And Folder Structure

## Goal

Promote the stabilized tick arena from a stage subfolder into a feature-root layout. This pass organizes combat, player, run, wave, reward, view, and HUD code by ownership without changing gameplay behavior.

## Relational Context

- `game/scenes/stages/` currently mixes the legacy arena scene, tick arena scene, wave systems, reward systems, and stage assets; after Phase 6, tick arena is the production game mode rather than a stage experiment.
- `project_structure.md` says game features belong under `game/<feature>/`, shared UI moves to `game/shared/` only when multiple features need it, and reusable non-game logic belongs in `common/` only when it could be reused outside this project.
- Tick combat rules, action flow, run-build truth, wave flow, and reward behavior are game-specific, so they should move under the tick arena feature root rather than `common/`.
- `RunBuild` belongs under the tick arena `run/` folder because it is the run-wide build truth read by combat, wave, and reward systems, not merely a reward pipeline implementation detail.
- The reward pipeline moves under `game/tick_arena/reward/` because the legacy arena is expected to die at cutover and reward behavior is part of the tick arena run loop.
- Resource paths in scenes, preloads, tests, and docs must be repaired as part of the move; behavior must remain unchanged.
- Legacy real-time arena files should not be deleted in this pass unless the cutover/closeout phase explicitly owns that deletion.
- Godot `.uid` companions must move with their scripts/scenes when applicable.

## Scope

### Included

- Move stabilized tick arena code to `game/tick_arena/`.
- Group files into ownership subfolders such as `combat/`, `player/`, `run/`, `view/`, `wave/`, `reward/`, and later `hud/`.
- Update resource paths, preloads, test references, and docs references needed by the move.

### Excluded

- Gameplay behavior changes.
- Legacy arena deletion.
- Final scene-routing cutover.

## Files to Change

| File                                                  | Change Size | Purpose                                                                      |
| ----------------------------------------------------- | ----------- | ---------------------------------------------------------------------------- |
| `game/scenes/stages/tick_arena/*`                     | Large       | Move scene, root, combat, player, and view files into the feature root.      |
| `game/scenes/stages/waves/*`                          | Large       | Move tick-run wave files into the feature root after 6d clarifies ownership. |
| `game/scenes/stages/run_build.gd`                     | Medium      | Move run-build truth into the tick arena run folder.                         |
| `game/scenes/stages/rewards/*`                        | Large       | Move reward pipeline under the tick arena reward folder.                     |
| `test/unit/*`                                         | Medium      | Update script paths and preload references.                                  |
| `dev/docs/plans/*`                                    | Small       | Update living plan/spec references after the move.                           |
| `project.godot` or scene registry files if referenced | Small       | Update only if production routing references moved resources.                |

## Implementation Notes

Target layout:

```txt
game/tick_arena/
  tick_arena.tscn
  tick_arena.gd
  combat/
  player/
  run/
  view/
  wave/
  reward/
  hud/
```

Keep `game/shared/` conservative. Move a file there only when it is genuinely used by more than one feature after legacy cleanup.

Place `RunBuild` in `game/tick_arena/run/`, not `reward/`, because combat and wave systems read it as run truth after rewards have applied.

Move the reward pipeline into `game/tick_arena/reward/`; do not leave it under `game/scenes/stages/rewards/` as a pseudo-shared system once Phase 6 has made tick arena the run-loop owner.

Do not move enemy entity files into the tick arena feature root. Enemy scenes and scripts remain entity content unless a later cutover decides they are no longer shared with any other mode.

## Edge Cases

| Case                                                                  | Expected Handling                                                         |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| A reward file is still used by legacy arena during the branch         | Delay that move or update both call sites without changing behavior.      |
| A scene preload path breaks after moving                              | Repair the preload and verify the scene loads.                            |
| A file looks generic but is tick-design-specific                      | Keep it under `game/tick_arena/`, not `common/`.                          |
| Run-build references are spread across combat, wave, and reward files | Update all references to the `run/` location in the same relocation pass. |

## Acceptance Criteria

1. Tick arena files live under `game/tick_arena/` with ownership-based subfolders including `run/` and `reward/`.
2. Moved scenes and scripts load through updated resource paths.
3. No gameplay behavior changes are introduced by the relocation.
4. Legacy arena deletion remains reserved for the cutover/closeout phase.
