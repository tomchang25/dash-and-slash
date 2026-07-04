# Reward Effect Rework — Duplicate-Effect Fallback Fix

## Goal

Fix a reward-roll fallback path that can present the same effect twice within one reward option, so every offered option's effect list is guaranteed unique the same way the primary roll path already guarantees today.

## Requirements

1. A single reward option's effect list must never contain two entries for the same underlying effect, regardless of which internal roll path produced it. The primary roll path already enforces this by tracking picked effect ids as it builds a choice; a secondary fallback path, used when the primary roll can't hit its target point budget within its attempt limit, does not — it can independently select two different stack levels of the same effect as if they were unrelated candidates.
2. Two different options offered side by side in the same choice screen may still share the same effect. This is existing, accepted behavior and stays unchanged.

## Design

The fallback path works by expanding every candidate effect into one entry per stack level it could take, then searching combinations of those expanded entries for the one closest to the target point budget. That expansion is exactly why the bug exists: two entries in the search space can share the same underlying effect at different stack levels, and the combination search has no reason to know that picking both at once is invalid.

The fix must reject any combination that contains two entries for the same effect, without losing the fallback's ability to treat different stack levels of one effect as alternative candidates for a single slot — i.e. stack level 1 and stack level 3 of "Attack Range" are both valid choices for one slot, they're just never both valid together in the same option.

## Sketch (non-normative)

In `wave_reward_choice_generator.gd`, the combination-building loops inside `_fallback_choice()` iterate a flat list produced by `_expanded_single_effect_options()`. Add an early-exit guard before accepting a candidate into a partial combination, checking it against the effect ids already chosen so far — the same shape as `_roll_effects_for_profile()`'s existing `picked_ids` tracking:

```gdscript
for b in range(a + 1, options.size()):
    if options[b].definition.effect_id == options[a].definition.effect_id:
        continue
    ...
```

For the deeper `c`/`d` loops, check against every effect id already accumulated in the partial combination (a small local id list), not just the immediately preceding index, since a duplicate could come from any earlier slot in the combination.

Names, exact loop shape, and helper extraction are illustrative — follow whatever the file's current structure supports with the smallest correct diff.

## Acceptance Criteria

1. Forcing the fallback path with a small effect pool (including at least one effect with more than one available stack level) and an unreachable target point budget produces an option whose effects never repeat the same effect identity.
2. Reward generation that does not hit the fallback path is unaffected.
