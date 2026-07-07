# Tick Arena Structure Consolidation

## Goal

Consolidate the tick arena's internal structure after the phased tick-combat conversion: deduplicate the planning math copied across the action/preview ownership seam, collapse reward-effect class ceremony, make the run-scoped build store reset in place, and unify the cross-module combat contracts — all with zero player-facing behavior change, because the doctrine accumulated phase by phase now costs more upkeep and bug risk than it buys.

## Requirements

1. The aiming/planning math and the player combat base numbers used by both the committed-action path and the preview path exist exactly once, because the current duplicated copies are the one place where a single-sided edit silently makes the preview lie about what a commit will do. This is the "later cleanup can merge pure helpers" pass the original ownership split explicitly deferred.
2. The run-scoped build store is constructed once per arena scene and resets in place on restart; no collaborator is ever re-pointed at a replacement store, eliminating the restart re-wiring chain where one missed holder is a silent stale-state bug.
3. Reward effects whose entire behavior is "record a signed total on one channel of the build store" are instances of one parameterized definition instead of one subclass per channel; subclassing remains only where behavior genuinely differs (Major registration, payload overrides, trigger activation).
4. The legacy real-time-player seam leaves the reward pipeline: the reward context no longer carries a legacy player reference and the last player-gated effect (attack range) leaves the pool, because the legacy arena scene is already deleted and the tick arena filters that effect out of every offer anyway.
5. Tick combat speaks one hit-angle vocabulary end to end, and the verb and hit-outcome contracts that cross module boundaries are typed values instead of stringly-keyed dictionaries, so a typo'd key or missing default fails loudly at parse time instead of silently at runtime.
6. The reward roll's give-up fallback becomes a single bounded best-combination search with the same contract as today — closest total points wins, no duplicate effects, respects the profile's count limit — replacing the four-level nested enumeration currently marked as a cleanup TODO.

## Design

This is a pure structural refactor. The behavior-preservation guardrail for every child: a full run before and after must be observably identical — same numbers, same offers, same feedback text, same telegraph behavior. The only tolerated observable difference is tie-breaking order inside the reward fallback search, which today is an artifact of loop nesting rather than a designed rule.

### Child overview

| Child | Focus | Document form |
| ----- | ----- | ------------- |
| 01 | Shared plan math: merge the duplicated pure planning helpers and base-number constants into shared rules/planner code | implementation spec |
| 02 | Reward ceremony: one parameterized channel effect, applier middleman removed, legacy player seam deleted | sketch |
| 03 | Run store in-place reset: build store lives once per scene, restart clears it in place | implementation spec |
| 04 | Combat contracts: single hit-angle enum, typed verb and hit-outcome values, adapter deletion | sketch |
| 05 | Reward roll fallback: single bounded combination search | sketch |

Children land strictly one at a time, each as its own reviewable change. Recommended order: 01 → 04 (combat-side seams stabilize first, and 04 reshapes the outcome values 01's shared math produces), then 03 (run-loop wiring), then 02 → 05 (reward-side, where 02 shrinks the surface 05 reworks). Order deviations are fine when a child is blocked, except 05 must follow 02.

### Backing documents

Child documents live alongside this plan as `tick_arena_consolidation_0N_*.implementation_spec.md` / `.sketch.md`. Sketches are non-normative per the sketch standard; the codebase wins every disagreement at implementation time.

## Non-Goals

1. No HUD refactor — phase 7 of the parent tick combat rework owns that.
2. No merging of the action/preview/run controller split — the ownership boundaries stay; only side-effect-free math stops being duplicated across them.
3. No entity-layer cleanup (legacy player entity, enemy base-class mixing) — that overlaps the in-flight enemy ownership rework and the cutover closeout, and is parked as its own future main-plan draft.
4. No typing of the view-facing preview/danger payload dictionaries — they are heterogeneous display payloads consumed by one view, not cross-system contracts.
5. No balance, pool, or design-number changes of any kind.

## Acceptance Criteria

1. A full run — waves, rewards, majors, death, restart — plays identically before and after the whole flow, including debug-panel behavior.
2. Changing any player combat base number or plan rule is a one-place edit, and preview badges always match committed results after that edit.
3. Restarting never re-points any collaborator at a new store, and a restarted run starts from default build state with no inherited rewards, majors, payload overrides, or triggers.
4. The reward pool offers the same choices as today from the player's perspective; the only removed definition is one that could never be offered in the tick arena.
5. Verb handling and hit resolution contain no stringly-keyed lookups with silent defaults, and exactly one hit-angle vocabulary exists.
6. Standards lint and the unit test suite pass after every child, with tests updated where they asserted the old wiring.
