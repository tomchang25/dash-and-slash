# Tick Arena Consolidation 05: Reward Roll Fallback

## Goal

Replace the reward generator's give-up fallback — four hand-unrolled nested loops over expanded effect options, marked with a cleanup TODO — with one bounded recursive best-combination search that keeps the same contract in a fraction of the code.

## Requirements

1. The fallback contract is unchanged: when rejection sampling fails, return the combination of distinct-id effect options closest in total points to the target, with at most the profile's maximum effect count.
2. Tie-breaking order may differ from today, because the current order is an artifact of loop nesting, not a designed rule; everything else about the result distribution is preserved.
3. The `TODO, need cleanup this mess logic` marker disappears because the mess does.

## Sketch (non-normative)

Depth-first search over the expanded options, replacing `_fallback_choice`'s a/b/c/d loops and retiring `_capture_best_effects` / `_shares_effect_id`:

```gdscript
func _best_combo(options, start_index, slots_left, current, target, best) -> void:
    for i in range(start_index, options.size()):
        var option := options[i]
        if _id_in(option, current):
            continue
        current.append(option)
        var distance := absf(_points_of(current) - target)
        if distance < best.distance:
            best.distance = distance
            best.effects = current.duplicate()
        if slots_left > 1:
            _best_combo(options, i + 1, slots_left - 1, current, target, best)
        current.pop_back()
```

- `_fallback_choice` shrinks to: build expanded options, run `_best_combo` with `slots_left = _max_effect_count(profile)`, wrap the best list in a choice.
- Worst-case work is the same combinatorial space as today, so no performance regression is possible; an optional early return on `distance == 0` (exact match) is a free win.
- Options with duplicate effect ids exist by construction (one option per stack count), so the distinct-id check stays inside the search, same as today.

## Non-Goals

1. No change to rejection sampling, profile validity rules, or the effect pool (child 02 owns the pool's shape).

## Acceptance Criteria

1. When rejection sampling fails, the fallback still returns a non-empty choice whose total points are at least as close to the target as today's result for the same inputs.
2. Generator behavior on the happy path is untouched.
3. Lint and unit tests pass, and no cleanup TODO remains in the generator.
