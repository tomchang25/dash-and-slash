# Tick Combat Rework 04a: Major Debug Controls

Skeleton sketch split out during Phase 4 planning; revise against the codebase at phase start. The codebase wins every disagreement.

## Goal

Add debug-panel controls and debug toggles for Major effect state so Smash can be enabled, disabled, and inspected immediately, and later Major effects have a ready debug surface before reward-loop wiring exists.

## Requirements

1. Debug controls can set the mobility payload to Dash or Smash without using rewards, because Smash needs fast manual validation while the reward loop is still deferred.
2. The debug surface clearly shows the active mobility payload and any active Major-effect debug state, so manual playtest does not depend on remembering hidden shortcuts.
3. Debug controls write through the same run-build surfaces that real Major effects use, not through parallel scene-only flags, so debug behavior remains representative of perk behavior.
4. The debug surface provides an extension point for later effect toggles; Phase 04b uses this to add Guard Shredder and Execution debug wiring when those effects exist.
5. Debug controls are gated behind debug mode and must not become production UI.

## Design

This phase exists for testability, not player progression. It should make Major state readable and mutable at will while preserving the same runtime ownership as real rewards. The useful invariant is: if a behavior works through the debug control, it is exercising the same store path a reward will later write.

## Sketch (non-normative)

- Extend the existing debug panel or debug-only tick-arena controls rather than creating player-facing UI.
- Prefer named controls for `Dash payload` and `Smash payload` over cycling through hidden states; active state should be visible.
- Expose a small debug-control registration or update point that Phase 04b can use for Guard Shredder and Execution without redesigning the panel.
- Keep keyboard debug shortcuts only as optional accelerators if they remain useful; the panel should be the source of readable state.

## Non-Goals

1. No implementation of Guard Shredder, Execution, or other new Major effects; Phase 04b owns the first dash-triggered effects and their debug wire.
2. No reward generation, reward application, or next-wave loop; Phase 04c owns that bridge.
3. No production settings or player-facing build-management UI.

## Acceptance Criteria

1. In debug mode, Smash can be turned on and off as the active mobility payload at will.
2. The controls show current Major state clearly enough to support manual playtest.
3. The controls mutate the same run-build state used by real Major effects.
4. The debug surface can accept later Major-effect toggles without replacing the panel.
5. The controls are unavailable outside debug mode.
