# Reward Effect Rework — Major Effect Scaffold

## Goal

Add a run-wide capacity cap and a mutual-exclusivity check for behavior-changing (Major) effects, as a specialization within the Phase 3 effect hierarchy and store — not a parallel system — wired end-to-end through the one placeholder Major effect that exists today. No real behavior-changing effect is implemented. Depends on Phase 3, which owns the store and the effect hierarchy this extends.

## Relational Context

- Major effects are the same effect objects introduced in Phase 3, distinguished through a real `MajorEffect` intermediate base class: they carry an exclusivity-group identifier (empty means no group, never conflicts) and, when applied, register in the same run-scoped `RunBuild` store that minor numeric effects use — not a separate player-side array or parallel reward system.
- `RunBuild` is the run-scoped store currently created by the arena and injected into `Player`, `WaveController`, and `WaveRewardContext`. It owns the Major records and rules. `Player` may expose thin passthroughs for Major capacity/conflict/count queries, but must not duplicate or separately own Major state.
- The run-wide cap (four) and the empty-group convention come from the design document's already-settled Major/Minor rules — do not invent different values.
- The roll's per-effect eligibility step (`is_applicable(context)` from Phase 3) is where a full or conflicting Major is filtered out before being offered — the same seam terrain effects use to check candidate availability. `MajorEffect.is_applicable` reads the injected run store through the context/player boundary and rejects if the store is at the cap, or if the effect's non-empty exclusivity group already has a member. This is a pre-offer filter, not a post-pick rejection, and it generalizes to any future Major without further wiring — a real behavior-changing effect only needs to fill in its exclusivity group.
- The placeholder Major effect's `apply` today does nothing (its old switch arm was a no-op). After this change it extends `MajorEffect` and registers itself in `RunBuild`, so the cap is enforced end-to-end even though the placeholder still changes no gameplay behavior beyond occupying one of the four slots.
- Ability-behavior overrides (swapping what an ability does) and event-triggered effect hooks are explicitly out of scope. This phase builds only the capacity/conflict bookkeeping — the store's Major side records which behavior-changing effects are active and enforces the cap and exclusivity, nothing more.

## Scope

### Included

- A Major specialization in the Phase 3 effect hierarchy carrying an exclusivity group.
- Cap (four) and exclusivity-group checks on the applied-effect store's Major side.
- The Major `is_applicable` pre-offer filter reading the store through the context bundle.
- Wiring the placeholder Major effect's `apply` to register in the store.
- A synthetic/placeholder-driven test proving both the cap and the exclusivity check reject correctly.

### Excluded

- Any real behavior-changing effect.
- Ability-override or triggered-effect data shapes.
- Any change to the placeholder's (nonexistent) gameplay behavior.

## Files to Change

| File                                                             | Change Size | Purpose                                                                                                      |
| ---------------------------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------ |
| `game/scenes/stages/rewards/effects/major_effect.gd`             | Small       | New Major intermediate base that carries exclusivity group, owns Major eligibility, and registers on apply.  |
| `game/scenes/stages/rewards/effects/major_placeholder_effect.gd` | Small       | Extend `MajorEffect` so the existing placeholder occupies a Major slot without adding gameplay behavior.     |
| `game/scenes/stages/run_build.gd`                                | Small       | Major-side registration, capacity query, count query, and exclusivity-group query alongside numeric entries. |
| `game/entities/player/player.gd`                                 | Small       | Thin passthroughs to the injected `RunBuild` for Major capacity/conflict/count queries.                      |
| `game/scenes/stages/rewards/wave_reward_choice_generator.gd`     | Small       | The placeholder Major definition gains its exclusivity group (empty for the placeholder itself).             |
| New test file under `test/unit/`                                 | Small       | Prove cap, empty-group behavior, and exclusivity-group rejection using placeholder/synthetic identifiers.    |

## Implementation Notes

- The pre-offer filter lives entirely in `MajorEffect.is_applicable`, not in the placeholder effect and not in `WaveRewardChoiceGenerator`, so it applies to every future Major with no generator edits.
- `RunBuild` should store Major records as Major records (effect id plus exclusivity group or equivalent), not as fake numeric channels. Numeric `record()` / `total()` behavior must remain unchanged for minor stat and enemy-pressure projection.
- The store's Major-side registration returns success/failure rather than silently no-op'ing, so a rejected add is observable to callers and to tests, even though the pre-offer filter should mean a conflicting add is never actually attempted in normal play.

## Edge Cases

| Case                                                                      | Expected Handling                                                                    |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Two Major effects with different non-empty exclusivity groups.            | Both allowed — the check is per group, not one-behavior-effect-at-a-time.            |
| A Major effect with an empty exclusivity group (the placeholder's state). | Never conflicts on exclusivity; only the cap can reject it.                          |
| The cap is already reached.                                               | Rejected regardless of exclusivity group, including a group with no existing member. |

## Acceptance Criteria

1. No more than four Major effects can be active on one player in one run at a time.
2. Two Major effects sharing an exclusivity group can never both be active on the same player at once.
3. Both are demonstrable today via the placeholder Major effect and synthetic conflicting identifiers, with no real behavior-changing effect existing yet.
