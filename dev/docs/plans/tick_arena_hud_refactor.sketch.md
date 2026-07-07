# Tick Arena HUD Refactor

Parent Plan: none (standalone sketch)

## Goal

Refactor the tick arena HUD into a single readable combat information layer after the run loop, rewards, speed meter, and mobility refunds all exist. This turns the minimal truth displays from earlier phases into a durable player-facing HUD without changing combat rules.

## Summary

- **Timing:** This standalone sketch is gated on the tick artifact rewards plan shipping, because that plan reshapes build inspection into an artifact list plus stacked-effect summary. The HUD pass should absorb and polish that panel instead of building a duplicate summary first.
- **Refactor shape:** Treat this as a consolidation pass, not a new mechanic phase. Existing truth displays become one coherent combat information layer, while duplicated message/status surfaces are reduced.
- **HUD priority:** Always-visible decision state comes first; build inspection can be expandable or compact so the player does not parse a full card ledger during active danger.
- **Expected result:** The player can read combat state, Speed readiness, mobility-refund feedback, wave/build state, and applied artifacts from one durable HUD surface, while debug controls remain visually separate.

## Requirements

1. The HUD shows every decision-critical tick-combat state in one coherent layout: HP, tick count, active aim/mobility mode, Dash/Smash cooldowns, Speed meter readiness, current wave, and short combat messages.
2. Applied reward effects are grouped into a readable run-build summary by artifact rarity/display name and summed effect totals, so the player can audit their build after choices close.
3. Speed meter visibility graduates from the minimal truth display into the HUD's normal visual language; the ready state for the next eligible move or normal attack remains impossible to miss.
4. Mobility Free Action feedback is represented as a HUD/combat message state, distinct from Speed meter spends, so the two free-action sources do not blur together.
5. Debug-only controls stay visually separate from player-facing HUD state and remain gated by `Debug.enabled`.
6. The reward overlay can remove any duplicated effect-title text once the persistent run-build summary exists, keeping reward choices concise while preserving post-choice inspectability.

## Sketch

- Introduce a small HUD presenter/control under the tick arena scene that receives plain state snapshots from the arena root rather than reading combat owners directly.
- Replace the current monolithic stats label with grouped areas: survival/time, action state, cooldowns, Speed, wave/build, and transient feedback.
- Reuse the artifact rewards inspection model once it exists: render applied artifacts grouped by rarity/display name, plus summed build effect totals.
- Move "NEXT MOVE/ATTACK FREE" from plain text into a stable meter component with a ready state and spend flash.
- Add a separate "MOBILITY REFUND" or equivalent feedback beat for the Mobility Free Action Major; do not reuse the Speed meter ready/spend visual for it.
- Keep debug buttons in the debug panel, not in the player HUD, and preserve their active-state labels for testing.

## Non-Goals

1. No new combat mechanics, reward effects, or balance changes.
2. No final art pass; layout and clarity matter, but bespoke art assets can follow later.
3. No manual terrain-targeting UI or new reward-card selection flow.

## Acceptance Criteria

1. The tick arena HUD exposes all current combat-critical state without relying on debug controls or hidden memory.
2. The player can inspect applied artifacts and current build totals after choosing rewards, grouped by readable names and stack counts.
3. Speed meter spends and Mobility Free Action refunds are visually distinguishable.
4. Reward choices stay concise because persistent build inspection no longer depends on verbose choice-card text.
5. Debug-only controls remain gated and visually separate from the player HUD.
