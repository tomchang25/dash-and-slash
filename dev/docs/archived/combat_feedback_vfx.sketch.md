# Combat Feedback VFX

## Goal

Add lightweight combat feedback for charge movement, shielded hits, guard breaks, and unshielded damage so players can read whether their attacks were blocked, broke guard, or dealt full damage.

## Requirements

1. Charge enemies show a front wind-break effect and dash motion effect so their high-threat movement is readable before and during the rush.
2. Hits against an unbroken guard show shield feedback on or near the enemy so players understand the hit was blocked or reduced.
3. Guard break shows a distinct break effect so players can immediately identify the punish window.
4. Hits after guard break or against unshielded enemies show a blood or damage burst effect so full damage reads differently from blocked damage.
5. Effects should be short-lived and attached to the combat event position so feedback helps targeting rather than becoming persistent visual noise.
6. The first version should use simple generated/tweened effects before investing in final art assets.

## Design

The key distinction is blocked, broken, and full-damage feedback. Blocked feedback should feel defensive and cool-colored or shield-shaped. Guard break should feel like shield fragments or a sharp flash. Full damage should feel warmer and more physical. Charge wind effects should point along the enemy's facing and appear slightly ahead of the body so the player can read direction before the charge crosses the grid.

## Sketch (non-normative)

Suggested event mapping:

| Combat event                | First-pass effect                                         |
| --------------------------- | --------------------------------------------------------- |
| Charge warning/charge start | Forward wind slash or streak at the enemy front           |
| Charge active movement      | Short trail or dash streak following the charge direction |
| Guarded hit                 | Shield spark/icon flash attached to enemy                 |
| Guard break                 | Shield shatter burst plus brief stagger color pulse       |
| Full damage hit             | Small blood/damage burst at hit side                      |

Suggested implementation steps:

1. Add a tiny reusable effect helper or scene for burst-style one-shot VFX.
2. Trigger charge wind feedback from the charge enemy's warning and active charge transitions.
3. Trigger shielded-hit feedback from the guarded-hit branch.
4. Trigger guard-break feedback from the guard break signal.
5. Trigger full-damage feedback from the branch where damage is not reduced by guard.
6. Prefer pooled or self-freeing one-shot nodes so repeated hits do not leak nodes.

## Non-Goals

1. No final sprite-sheet animation pass.
2. No audio rebalance beyond using existing hit/block/break sounds if they already exist.
3. No changes to guard math, damage values, enemy AI, or player attack timing.

## Acceptance Criteria

1. A charge enemy visibly communicates its rush direction before and during the charge.
2. Hitting an enemy guard produces shield feedback instead of looking like full damage.
3. Breaking guard produces a distinct effect that is readable without watching the health or guard bars.
4. Damaging a staggered or unguarded enemy produces a different full-damage hit effect.
5. Effects clean themselves up and do not remain in the scene after their short lifetime.
