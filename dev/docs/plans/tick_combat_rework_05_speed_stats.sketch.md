# Tick Combat Rework 05: Speed Stats

Skeleton sketch written ahead of the phase; revise against the codebase at phase start. The codebase wins every disagreement.

## Goal

Turn player speed into three independent, data-driven stats projected from the applied-effect store and offered as Minor rewards — movement (free-step meter), attack speed (windup reduction), and mobility cooldown — without ever making a displayed telegraph lie.

## Requirements

1. Free-step meter (movement speed): each executed verb charges a meter; when full, the next verb consumes the charge and advances the world by zero time (enemies gain no energy). The meter's fill state is public, visible UI, so whether the next action is free is always predictable — this is what keeps forward previews truthful.
2. Windup reduction (attack speed): stacks accumulate points; accumulated points reduce windup ticks of windup-bearing actions at thresholds, floor zero. Quantized payoff, smooth stacking.
3. Mobility cooldown: minus one cooldown tick per stack, floored at 1 — a zero-cost mobility verb is Major territory ("dash costs no time"), never a stackable Minor.
4. All three are store projections on the existing reward-store architecture (new channels, no store redesign), read at verb/windup/cooldown time so mid-run changes apply immediately.
5. Telegraph and outcome previews account for the meter state when labeling danger timing, preserving the "display is always the simulated truth" contract.

## Design

Initial curves (all tuned in playtest):

- Free-step fill: +10% per executed verb per stack, capped at 50% (at cap, one free step every two actions at most). Base fill without picks is 0 — no free steps until the player invests.
- Windup reduction: every 3 points remove one windup tick, floor 0. Kept coarse deliberately: Smash's base windup is only 1 tick, so a single cheap Minor must not erase it.
- Meter presentation: a visible charge pip on/near the player (decision over the previously deferred invisible-energy option — the pickup needs to feel like it changed something the moment it is chosen; the deferred list item closes with this phase).

Enemy-side speed does not change here. If any actor ever exceeds baseline speed (acting twice in one player action), the loud double-move preview rule from the design document becomes mandatory before shipping it.

## Sketch (non-normative)

- `RunBuild` channels: `move_charge_rate`, `windup_reduction_points`, `mobility_cooldown_reduction`; three new Minor effect objects on the existing per-effect-object pattern.
- The free step implements as the engine skipping the world-advance for that verb (stages 2-3 do not run; tick counter policy decided at spec time — likely counts as a tick for cooldown purposes but not for enemy energy).
- Meter state lives on the player actor; the HUD pip and the engine both read it.

## Non-Goals

1. No enemy speed rewards or debuff effects — enemy speed stays fixed per-kind tuning.
2. No continuous attack-speed percentages; quantization is the accepted trade (design document 3.3).

## Acceptance Criteria

1. Each of the three Minors stacks within its own domain with visible effect, and picking any of them never changes what a displayed telegraph promised.
2. A full meter visibly signals the free step before it happens, and the free step demonstrably gives enemies no action.
3. Windup reduction respects the floor of zero and the cooldown reduction respects the floor of one.
