# Tick Arena Visual Readability 03a: Support Pool Identity Cleanup

Parent Plan: `tick_arena_visual_readability_and_identity.md`

## Goal

Clean up normal support enemy identity by freezing PuffEnemy out of default support spawns and moving ChargeEnemy onto a Skull body instead of a Kappa color variant.

## Summary

PuffEnemy currently overlaps the planned Burst SmallEnemy identity: a close-range area threat that pressures the player away from standing beside the enemy. For the next readability pass, that tactical role should move into the visible SmallEnemy variant family so early support waves teach one consistent Kappa-body pattern language.

ChargeEnemy should also leave the Kappa family. The four SmallEnemy variants use Kappa body color to communicate attack pattern, so ChargeEnemy should not remain KappaRed. It should use `assets/Ninja Adventure - Asset Pack/Actor/Monster/Skull/SpriteSheet.png`, making charge read as a separate body/silhouette while preserving its charge telegraph, VFX, movement, damage, and recovery.

This is a freeze and identity cleanup, not a deletion. PuffEnemy remains in the repository as a parked special-enemy prototype with its chase, windup, active-zone, and recheck behavior intact. The final normal support pool after child 03 and this spec should be the four visible SmallEnemy variants plus Skull ChargeEnemy.

## Relational Context

- WaveController owns support enemy scene selection through its preloaded scene constants and support scene pool.
- PuffEnemy owns a distinct multi-tick zone behavior; this spec does not delete, simplify, or migrate that behavior.
- SmallEnemy Burst, specified in child 03, becomes the close surround-pressure support identity for this visual pass.
- ChargeEnemy remains a separate enemy body and behavior. Changing its sprite to Skull must not change charge pathing, telegraph, damage, VFX, or recovery.
- Freezing PuffEnemy must not affect ModeEnemy, elite spawns, wave count scaling, population cap logic, spawn warnings, or EnemySpawner.

## Scope

### Included

- Remove PuffEnemy from the normal support enemy scene pool.
- Replace ChargeEnemy's KappaRed scaffold texture with `Monster/Skull/SpriteSheet.png`.
- Finalize the normal support pool as the four child-03 SmallEnemy variants plus Skull ChargeEnemy.
- Leave PuffEnemy code, scene, data, and references available for future explicit reintroduction.

### Excluded

- Deleting PuffEnemy files or tests.
- Reworking PuffEnemy visuals, presenter wiring, attack data, or active-zone rules.
- Changing ChargeEnemy charge logic, data, telegraph, VFX, damage, or recovery.
- Adding weighted spawn pools or wave-specific spawn rules.
- Changing ModeEnemy or elite wave behavior.

## Files to Change

| File | Change Size | Purpose |
| ---- | ----------- | ------- |
| `game/entities/enemies/charge_enemy.tscn` | Small | Replace the KappaRed scaffold texture with Monster/Skull while preserving the existing presenter and data wiring. |
| `game/tick_arena/wave/wave_controller.gd` | Small | Remove PuffEnemy from the support scene pool and keep the final normal support pool to the four SmallEnemy variants plus ChargeEnemy. |

## Execution Outline

1. Update ChargeEnemy's scene texture to `assets/Ninja Adventure - Asset Pack/Actor/Monster/Skull/SpriteSheet.png` without touching charge behavior or data.
2. Update WaveController's support enemy pool so PuffEnemy is not chosen for normal support spawns.
3. If child 03 lands in the same branch, finalize the pool as the four SmallEnemy variant scenes plus ChargeEnemy.
4. Keep PuffEnemy files untouched and do not remove its scene unless a later cleanup explicitly deletes the parked prototype.
5. Run standards lint on the changed files and narrow Godot parse/check for WaveController and ChargeEnemy scene loading.

## Implementation Notes

- If this cleanup lands before child 03, the temporary support pool can be the current SmallEnemy scene plus ChargeEnemy. Once child 03 lands, the final pool must be the four SmallEnemy variant scenes plus ChargeEnemy.
- Keep the change local to support scene selection and ChargeEnemy scene presentation. Do not add a general spawn-weighting abstraction in this small spec.
- Do not use red Kappa tinting to identify ChargeEnemy. Charge should read primarily through Skull silhouette plus the existing charge presenter/VFX language.

## Edge Cases

| Case | Expected Handling |
| ---- | ----------------- |
| Future code still references PuffEnemy directly | The scene and script remain valid because this spec only removes default support spawning. |
| Child 03 changes the support pool in the same branch | The final pool must still exclude PuffEnemy and include Skull ChargeEnemy. |
| ChargeEnemy texture changes body family | Charge behavior, telegraph, VFX, and recovery remain unchanged; only the visual texture changes. |

## Acceptance Criteria

1. Normal support waves no longer spawn PuffEnemy.
2. PuffEnemy remains available in the repository for future deliberate reintroduction.
3. ChargeEnemy reads as a Skull-bodied enemy rather than a red Kappa-family variant.
4. Wave progression, spawn warnings, milestone elite spawning, and support spawn counts are unchanged aside from the enemy kind selected.
