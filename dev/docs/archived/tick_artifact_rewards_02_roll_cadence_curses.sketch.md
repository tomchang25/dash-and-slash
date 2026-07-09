# Tick Artifact Rewards 02: Roll, Cadence, And Curses

Parent Plan: `tick_artifact_rewards.md`

## Goal

Rebuild the reward roll and its wave cadence on top of the artifact data model: flat-random distinct three-choice from a rarity pool, the milestone curse+Major beat with a Minor x2 fallback, and the four enemy-pressure channels re-homed as the curse pool. The point-balancing generator is deleted.

## Summary

- **Complexity target:** The current point-balanced generator carries profiles, target points, rejection sampling, and nested fallback machinery that the artifact three-choice model does not need.
- **Likely direction:** Replace the generator with filtered distinct artifact picks, split by Minor, Major, and curse eligibility. Normal waves offer Minors; milestone waves offer curses first, then Majors with a two-Minor fallback if no Major is eligible.
- **Pressure economy:** Enemy pressure moves out of hidden per-offer pricing and into chosen milestone curses built from the four existing pressure channels.
- **Expected result:** Offers become simple and readable, every visible pick is an artifact, and the old closest-combination fallback disappears instead of being reimplemented.

## Sketch

- **Generator shrinks to a picker.** `WaveRewardChoiceGenerator` likely loses profile logic, per-choice validation against point budgets, retry attempts, best-effect capture, expanded single-effect options, total-points helpers, upside/downside helpers, and the nested fallback. What remains is closer to:

```gdscript
func roll(kind, count, wave_number, context) -> Array[Artifact]:
    var pool := _eligible(kind, wave_number, context)   # filter by kind + the one eligibility predicate
    pool.shuffle()
    return pool.slice(0, count)                          # distinct by construction
```

- Rarity weighting is a later refinement; first pass is the flat shuffle above. `kind` selects Minor / Major / curse by artifact classification and the `is_curse` flag.
- **Cadence likely lives in the run controller**, which already knows milestone-ness. On normal wave clear it opens one Minor three-choice. On milestone clear it opens the curse three-choice, then the Major three-choice; if the Major roll returns empty, it opens a Minor x2 instead.
- Sequencing two overlays back-to-back should reuse the existing pause/continue seam that already gates one reward overlay.
- **Curse pool** is authored alongside the artifact pool as four `is_curse` artifacts, each a single channel contribution on one pressure channel. Percent channels keep their current scale convention.
- **Choice value objects** likely simplify to wrap one artifact. Profile/target-point fields and display-name profile switching delete; the overlay renders artifact name, rarity color, and description lines.
- **Fallback contract:** The Minor x2 fallback is the only designed fallback. An empty Minor pool is a real edge; degrade to disabled "No reward" cards if the existing overlay supports that shape.

## Non-Goals

1. No rarity weight tuning — flat random first.
2. No new curse content beyond the four existing pressure channels.
3. No data-model changes — child 01 owns the artifact and effect shapes.

## Acceptance Criteria

1. Every offer is three, or two for the Major fallback, distinct artifacts of the requested kind; none repeats within an offer.
2. Normal waves show a Minor three-choice; milestone waves show a curse three-choice then a Major three-choice, falling back to a Minor x2 when no Major is eligible.
3. No point-balancing generator code remains; the roll is a filtered shuffle.
4. Enemy pressure reaches a run only via chosen curses; lint and unit tests pass.
