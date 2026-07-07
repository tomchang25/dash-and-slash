# Tick Arena Structure Consolidation

## Goal

Consolidate the tick arena's internal structure after the phased tick-combat conversion: deduplicate the planning math copied across the action/preview ownership seam, make the run-scoped build store reset in place, and unify the cross-module combat contracts — all with zero player-facing behavior change, because the doctrine accumulated phase by phase now costs more upkeep and bug risk than it buys.

The reward-side cleanups that once lived here (the channel-effect ceremony collapse and the roll-fallback rewrite) have moved to the tick artifact rewards plan, which restructures the whole reward system rather than polishing the doomed point generator. This plan now covers only the combat and run-loop mechanical cleanups.

## Requirements

1. The aiming/planning math and the player combat base numbers used by both the committed-action path and the preview path exist exactly once, because the current duplicated copies are the one place where a single-sided edit silently makes the preview lie about what a commit will do. This is the "later cleanup can merge pure helpers" pass the original ownership split explicitly deferred.
2. The run-scoped build store is constructed once per arena scene and resets in place on restart; no collaborator is ever re-pointed at a replacement store, eliminating the restart re-wiring chain where one missed holder is a silent stale-state bug.
3. Tick combat speaks one hit-angle vocabulary end to end, and the verb and hit-outcome contracts that cross module boundaries are typed values instead of stringly-keyed dictionaries, so a typo'd key or missing default fails loudly at parse time instead of silently at runtime.

## Design

This is a pure structural refactor. The behavior-preservation guardrail for every child: a full run before and after must be observably identical — same numbers, same offers, same feedback text, same telegraph behavior.

### Child overview

| Child | Focus                                                                                                                 | Document form       |
| ----- | --------------------------------------------------------------------------------------------------------------------- | ------------------- |
| 01    | Shared plan math: merge the duplicated pure planning helpers and base-number constants into shared rules/planner code | implementation spec |
| 03    | Run store in-place reset: build store lives once per scene, restart clears it in place                                | implementation spec |
| 04    | Combat contracts: single hit-angle enum, typed verb and hit-outcome values, adapter deletion                          | implementation spec |

Child numbering keeps its original 01/03/04 labels; 02 (reward ceremony) and 05 (roll fallback) moved to the tick artifact rewards plan. Children land one at a time, each as its own reviewable change. Recommended order: 01 → 04 (combat-side seams stabilize first, and 04 reshapes the outcome values 01's shared math produces), then 03 (run-loop wiring). The `GuardDamageProfile` dash-flag inversion is carved into 04, since it reshapes the same take-hit contract.

### Backing documents

Child documents live alongside this plan as `tick_arena_consolidation_0N_*.implementation_spec.md` / `.sketch.md`. Sketches are optional exploration notes for child slices; implementation always runs from an implementation spec written against the live codebase when that child is next to land.

## Non-Goals

1. No HUD refactor — phase 7 of the parent tick combat rework owns that.
2. No merging of the action/preview/run controller split — the ownership boundaries stay; only side-effect-free math stops being duplicated across them.
3. No entity-layer cleanup (legacy player entity, enemy base-class mixing) — that overlaps the in-flight enemy ownership rework and the cutover closeout, and is parked as its own future main-plan draft.
4. No typing of the view-facing preview/danger payload dictionaries — they are heterogeneous display payloads consumed by one view, not cross-system contracts.
5. No reward-system changes — the artifact rewards plan owns the whole reward restructure, including the channel-effect collapse and the roll rewrite that once lived here.
6. No balance or design-number changes of any kind.

## Acceptance Criteria

1. A full run — waves, rewards, majors, death, restart — plays identically before and after the whole flow, including debug-panel behavior.
2. Changing any player combat base number or plan rule is a one-place edit, and preview badges always match committed results after that edit.
3. Restarting never re-points any collaborator at a new store, and a restarted run starts from default build state with no inherited rewards, majors, payload overrides, or triggers.
4. Verb handling and hit resolution contain no stringly-keyed lookups with silent defaults, and exactly one hit-angle vocabulary exists.
5. Standards lint and the unit test suite pass after every child, with tests updated where they asserted the old wiring.
