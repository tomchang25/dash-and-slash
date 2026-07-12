# Data-Driven Wave Progression And Enemy Levels 03: Demo And Endless Balance

Parent Plan: `data_driven_wave_progression_and_enemy_levels.md`

## Goal

Explore the content-authoring and playtest pass that turns the new wave/group/level systems into a fair ten-wave demo, a fixed endless extension, and a deliberately lethal wave-20-plus curve.

## Summary

This slice should tune encounter complexity only inside waves 1–10. After demo completion, composition and scheduling freeze; every later difficulty change must be explainable by the displayed enemy level and explicit reward pressure.

Balance should treat wave 10 completion rate and cause of death as primary signals. Wave 20 is not another fairness milestone: it marks the point where completed builds enter overtime and ordinary positioning or telegraph mistakes may be fatal.

## Sketch

- Author ten explicit demo wave definitions and one endless template. Avoid per-wave random roster expansion that can obscure whether a difficulty spike came from composition or stats.
- Waves 1–3 should use Small-enemy groups to establish core reads. Pattern variety can increase, but overlapping group timing should remain conservative while the player learns facing, Guard, and danger countdowns.
- Waves 4–6 should introduce Charge enemies as authored reinforcements. Early Charge groups should wait for most of the preceding Small group to clear; later waves may enter them at a nonzero survivor threshold once the committed-line grammar is familiar.
- Waves 7–9 should introduce Mode enemies in isolated or late groups before combining them with surviving support enemies. Population headroom and group thresholds should cap simultaneous information rather than relying on uniformly random selection.
- Wave 10 should stage support pressure followed by the distinct boss-placeholder group. Its level offset and timing should create a finale without introducing mechanics the player could not have learned in waves 1–9.
- The endless template should use the full demo roster and one fixed reviewed group order. It should not clone the unique boss finale unless the authored endless grammar explicitly uses the placeholder as an ordinary elite role; the template itself remains identical for every endless wave.
- Normal enemies should use level equal to wave, with stable group offsets for stronger roles. The content pass should verify that an offset reads as the same relative threat at waves 10, 15, and 20 rather than being magnified unpredictably by the curve.
- Initial tuning should evaluate HP, damage, Guard, and Defense separately at representative levels 1, 4, 7, 10, 11, 15, 19, and 20. Record time-to-kill, hits-to-player-death, Guard breaks per kill, and effective damage after Defense before combining the curves.
- Damage should be the main post-demo accelerator. At wave 10, avoid unavoidable one-hit deaths from full health; across waves 11–19, reduce the number of mistakes a build can survive; at wave 20 and above, allow common enemy attack chains or a major missed telegraph to end a run rapidly.
- HP and Guard should keep high-level enemies relevant without making each wave a prolonged cleanup exercise. If kill time rises faster than danger, reduce their endless/lethal coefficients before raising player output.
- Defense should remain the shallowest curve because the current nonlinear mitigation compounds perceived durability with HP and Guard. Inspect effective player damage, not the displayed Defense number alone.
- Reward-driven pressure should be tested both absent and near expected upper stacks. The baseline curve must meet the target without requiring curses, while curse-heavy runs may enter lethal territory earlier in an explicit, explainable way.
- Playtests should separate encounter failures from numerical failures. Any difficulty increase after wave 10 caused by group count, timing, cap, or roster drift is a content defect under the fixed-grammar contract.
- Candidate files to inspect: authored wave resources created by child 01, enemy Level 1 tuning resources/scenes, the progression profile, reward-pressure artifacts, combat projection/debug readouts, and unit or simulation fixtures for representative levels.

## Non-Goals

1. No new enemy mechanics, bespoke boss behavior, or post-demo group escalation.
2. No guarantee that wave 20-plus runs remain fair or consistently survivable.
3. No broad rebalance of player artifacts except where a specific interaction makes the target curve impossible to evaluate.
4. No final leaderboard, score, or meta-progression system for endless survival.

## Acceptance Criteria

1. Waves 1–10 deliver the parent plan's roster progression and a fair, readable demo finale using explicit authored groups.
2. Wave 11 onward uses one unchanged encounter template, with observed difficulty differences attributable only to enemy level or explicit reward pressure.
3. Representative stat projections remain numerically valid beyond wave 20 without overflow, negative values, or invulnerable Defense behavior.
4. Playtests support wave 10 as the official completion target, waves 11–19 as mastery play, and wave 20 onward as intentionally rapid-death overtime.
5. HP, Guard, and Defense do not turn endless waves into cleanup attrition before Damage delivers the intended lethal pressure.
