# Tick Artifact Rewards 02: Roll, Cadence, And Curses

## Goal

Rebuild the reward roll and its wave cadence on top of the artifact data model: flat-random distinct three-choice from a rarity pool, the milestone curse+Major beat with a Minor ×2 fallback, and the four enemy-pressure channels re-homed as the curse pool. The point-balancing generator is deleted.

## Requirements

1. A reward offer is three distinct artifacts rolled flat-random from the eligible pool of the requested kind (Minor, Major, or curse); no offer repeats an artifact.
2. Normal waves offer a Minor three-choice; milestone waves offer a curse three-choice plus a Major three-choice, the Major choice falling back to two Minors when the Major pool is empty.
3. Enemy pressure enters a run only through chosen curses drawn from the four existing pressure channels, not through any per-offer price.
4. The point-balancing generator — profiles, target points, rejection sampling, and the nested combination fallback — no longer exists.

## Design

The curse pool is the four pressure channels (future enemy count, enemy health, enemy damage, enemy defense) expressed as `is_curse` artifacts. Their magnitudes are authored directly rather than derived from a point budget. Milestone detection reuses the existing every-fifth-wave rule that already schedules the milestone elite, so the curse+Major beat needs no new cadence clock.

## Sketch (non-normative)

- **Generator shrinks to a picker.** `WaveRewardChoiceGenerator` loses `roll_choices`'s profile logic, `_roll_choice`, `_is_valid_choice`, `_fallback_choice`, `_capture_best_effects`, `_expanded_single_effect_options`, all `_total_points`/`_upside`/`_downside` helpers, and `MAX_ROLL_ATTEMPTS`. What remains:

```gdscript
func roll(kind, count, wave_number, context) -> Array[Artifact]:
    var pool := _eligible(kind, wave_number, context)   # filter by kind + the one eligibility predicate
    pool.shuffle()
    return pool.slice(0, count)                          # distinct by construction
```

  Rarity weighting is a later refinement; first pass is the flat shuffle above. `kind` selects Minor / Major / curse by the artifact's rarity-or-`is_curse` classification.

- **Cadence lives in the run controller**, which already knows milestone-ness. On normal wave clear it opens one Minor three-choice (today's flow). On milestone clear it opens the curse three-choice, then the Major three-choice; if `roll(MAJOR, 3, ...)` returns empty, it opens a Minor ×2 instead. Sequencing two overlays back-to-back reuses the existing pause/continue seam that already gates one reward overlay.

- **Curse pool** is authored alongside the artifact pool as four `is_curse` artifacts, each a single `ChannelArtifactEffect` on one pressure channel (percent channels keep `unit_scale = 0.01`). They are excluded from the Minor/Major pools by the `is_curse` flag and only surface in the curse roll.

- **Choice value objects.** `WaveRewardChoice` (today wraps profile + target points + effects) simplifies to wrap one artifact; profile/target-points fields and `_make_display_name`'s profile switch delete. The overlay renders artifact name + rarity color + description lines.

- **Fallback contract.** The Minor ×2 fallback is the only fallback; the old closest-combination search is gone. An empty Minor pool (all owned) is a real edge — degrade to "No reward" cards, the overlay already handles disabled slots.

## Non-Goals

1. No rarity weight tuning — flat random first.
2. No new curse content beyond the four existing pressure channels.
3. No data-model changes — child 01 owns the artifact and effect shapes.

## Acceptance Criteria

1. Every offer is three (or two, for the Major fallback) distinct artifacts of the requested kind; none repeats within an offer.
2. Normal waves show a Minor three-choice; milestone waves show a curse three-choice then a Major three-choice, falling back to a Minor ×2 when no Major is eligible.
3. No point-balancing generator code remains; the roll is a filtered shuffle.
4. Enemy pressure reaches a run only via chosen curses; lint and unit tests pass.
