# Tick Combat Rework 07: All HUD Refactor

Skeleton sketch written ahead of the phase; revise against the codebase at phase start. The codebase wins every disagreement.

## Goal

Refactor the tick arena HUD into a single readable combat information layer after the run loop, rewards, speed meter, and mobility refunds all exist. This phase turns the minimal truth displays from earlier phases into a durable player-facing HUD without changing combat rules.

## Requirements

1. The HUD shows every decision-critical tick-combat state in one coherent layout: HP, tick count, active aim/mobility mode, Dash/Smash cooldowns, Speed meter readiness, current wave, and short combat messages.
2. Applied reward effects are grouped into a readable run-build summary by tier and display name, using effect metadata rather than ad hoc card text, so the player can audit their build after choices close.
3. Speed meter visibility graduates from the phase 05 minimal truth display into the HUD's normal visual language; the ready state for the next eligible move or normal attack remains impossible to miss.
4. Mobility Free Action feedback is represented as a HUD/combat message state, distinct from Speed meter spends, so the two "free action" sources do not blur together.
5. Debug-only controls stay visually separate from player-facing HUD state and remain gated by `Debug.enabled`.
6. The reward overlay can remove any duplicated effect-title text once the persistent run-build summary exists, keeping reward choices concise while preserving post-choice inspectability.

## Design

- Treat this as a consolidation pass, not a new mechanic phase. Phase 05 must still ship minimal Speed meter truth; phase 07 makes it pleasant, consistent, and extensible.
- HUD density should stay playtest-oriented: always-visible decision state first, expandable or compact build summary second. The player should not need to parse a full card ledger during active danger.
- Existing message/status surfaces should be reduced rather than multiplied. If two labels tell the same truth, the refactor should pick one owner and remove the duplicate.

## Sketch (non-normative)

- Introduce a small HUD presenter/control under the tick arena scene that receives plain state snapshots from the arena root rather than reading combat owners directly.
- Replace the current monolithic stats label with grouped areas: survival/time, action state, cooldowns, Speed, wave/build, and transient feedback.
- Add a run-build summary model that records applied `WaveRewardEffect` instances or display entries at apply time; render grouped Minor/Major entries using `definition.display_name` and stack counts.
- Move "NEXT MOVE/ATTACK FREE" from plain phase 05 text into a stable meter component with a ready state and spend flash.
- Add a separate "MOBILITY REFUND" or equivalent feedback beat for the Mobility Free Action Major; do not reuse the Speed meter ready/spend visual for it.
- Keep debug buttons in the debug panel, not in the player HUD, and preserve their active-state labels for testing.

## Non-Goals

1. No new combat mechanics, reward effects, or balance changes.
2. No final art pass; layout and clarity matter, but bespoke art assets can follow later.
3. No manual terrain-targeting UI or new reward-card selection flow.

## Acceptance Criteria

1. The tick arena HUD exposes all current combat-critical state without relying on debug controls or hidden memory.
2. The player can inspect applied Major and Minor rewards after choosing them, grouped by readable effect names and stack counts.
3. Speed meter spends and Mobility Free Action refunds are visually distinguishable.
4. Reward choices stay concise because persistent build inspection no longer depends on verbose choice-card text.
5. Debug-only controls remain gated and visually separate from the player HUD.
