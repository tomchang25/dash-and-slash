# Combat Execution Resistance

## Goal

Keep Execution powerful against ordinary enemies without letting one Major erase bosses or other authored priority targets. Resistant targets convert the instant-kill trigger into a visible high-damage strike that still rewards reaching Stagger.

## Requirements

1. Every boss-role enemy must resist Execution, and any non-boss enemy may opt into the same combat trait without relying on scene identity or one-off hit logic.
2. Execution must continue to kill an ordinary already-Staggered target instantly so the Major retains its core payoff against normal encounters.
3. Against an Execution-resistant already-Staggered target, Execution must deal three times the Mobility's base health damage instead of killing instantly; this replaces the ordinary Stagger multiplier rather than stacking with it, because resistance should cap the effect without nullifying it.
4. Resistant Execution damage must pass through the same defense, prediction, committed-hit, death, and result-feedback rules as other Mobility damage so previews and outcomes cannot diverge.
5. Preview and combat feedback must distinguish resistant triple damage from an instant Execution kill, while a target reduced to zero by the actual triple-damage result still dies normally.

## Design

Execution has two target responses:

| Target response | Already-Staggered Mobility hit |
| --------------- | ------------------------------ |
| Ordinary | Instant Execution kill. |
| Execution-resistant | Three times base Mobility health damage, replacing the normal Stagger multiplier and then resolving through defense. |

Boss encounter identity always enables the resistant response. Other enemy content may author the same response when an enemy's encounter role or future mechanic should not allow instant removal. Resistance belongs to combat behavior, so debug-spawned or reused instances retain the same result and no scene-name comparison decides eligibility.

Prediction shows the triple-damage Execution result and its resulting remaining health or lethal outcome. The committed hit uses that same result. Specialized Execution feedback may still identify that the Major triggered, but it must not claim an instant kill when the resistant damage is nonlethal.

## Non-Goals

1. Do not make bosses immune to Mobility damage, Stagger, Guard Break, side attacks, or back attacks.
2. Do not add percentage-health damage, execute thresholds, phase skipping, or boss-specific damage caps.
3. Do not change Execution eligibility, artifact rarity, reward-pool filtering, or ownership limits.
4. Do not perform the broader player-versus-enemy balance pass in this plan.

## Acceptance Criteria

1. Ordinary already-Staggered enemies still die immediately when Execution triggers.
2. Boss-role and explicitly resistant enemies take the three-times resistant result instead of an automatic kill.
3. Resistant damage replaces rather than multiplies the ordinary Stagger bonus, passes through defense once, and may still kill when the resulting damage reaches zero health.
4. Preview, committed health loss, result labels, and feedback agree for lethal and nonlethal resistant Execution hits.
5. The same resistant enemy behaves consistently whether encountered in an authored wave, spawned through debug tooling, or reused by pooling.
