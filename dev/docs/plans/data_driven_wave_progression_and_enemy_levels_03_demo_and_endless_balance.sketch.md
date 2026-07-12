# Data-Driven Wave Progression And Enemy Levels 03: Demo And Endless Balance

Parent Plan: `data_driven_wave_progression_and_enemy_levels.md`

## Goal

Explore the deferred content-authoring and playtest pass that turns the completed wave/group/level systems and production enemy-role roster into a fair ten-wave demo, a fixed endless extension, and deliberately lethal wave-21-plus overtime.

## Summary

This slice begins only after the Enemy Combat Roles And Counterpressure plan establishes the production roster, shared Guard profiles, reactive combat behavior, and role-aware formation vocabulary. It should tune encounter complexity only inside waves 1–10. After demo completion, composition and scheduling freeze; every later difficulty change must be explainable by displayed enemy level or the explicit Guard tier that begins at wave 21.

The stronger HP, damage, and Defense curve segment begins at Level 10, but wave 10 remains the official fair completion target. Later coefficients should make waves 11–20 increasingly unforgiving, while the discrete Guard tier beginning at base wave 21 helps make later overtime rapidly lethal without hidden pressure modifiers.

## Sketch

- Author ten explicit demo wave definitions and one endless template. Avoid per-wave random roster expansion that can obscure whether a difficulty spike came from composition or stats.
- Waves 1–3 should use Thrust and Slash groups to establish core reads. Pattern variety can increase, but overlapping group timing should remain conservative while the player learns facing, Guard, and danger countdowns.
- Waves 4–6 should introduce Ranged enemies in isolated or late groups before combining them with surviving Small enemies. Population headroom, formations, and group thresholds should keep the new distance-pressure grammar readable rather than relying on uniformly random selection.
- Waves 7–9 should introduce committed and positional roles such as Charge and Bomb alongside Mode pressure. Early groups should wait for most of the preceding group to clear; later waves may enter at a nonzero survivor threshold once their grammar is familiar, while population headroom continues to cap simultaneous information.
- Wave 10 should stage support pressure followed by the distinct boss-placeholder group. Its level offset and timing should create a finale without introducing mechanics the player could not have learned in waves 1–9.
- The endless template should use the full demo roster and one fixed reviewed group order. It should not clone the unique boss finale unless the authored endless grammar explicitly uses the placeholder as an ordinary elite role; the template itself remains identical for every endless wave.
- Normal enemies should use level equal to wave, with stable group offsets for stronger roles. The content pass should verify that an offset reads as the same relative threat at waves 10, 15, and 20 rather than being magnified unpredictably by the curve.
- Initial tuning should evaluate HP, damage, and Defense curves plus role-based Guard separately at representative levels and waves 1, 4, 7, 9, 10, 11, 15, 20, 21, 25, and 26. Record time-to-kill, hits-to-player-death, Guard breaks per kill, and effective damage after Defense before combining the systems.
- Damage should be the main Level 10-plus accelerator. At wave 10, avoid unavoidable one-hit deaths from full health; across waves 11–20, reduce the number of mistakes a build can survive; at wave 21 and above, allow common enemy attack chains or a major missed telegraph to end a run rapidly.
- HP and discrete Guard tiers should keep high-level enemies relevant without making each wave a prolonged cleanup exercise. If kill time rises faster than danger, reduce HP growth or Guard tier steps before raising player output.
- Defense should remain the shallowest curve because the current nonlinear mitigation compounds perceived durability with HP and Guard. Inspect effective player damage, not the displayed Defense number alone.
- Playtests should separate encounter failures from numerical failures. Any difficulty increase after wave 10 caused by group count, timing, cap, roster drift, or a hidden modifier is a content defect under the fixed-grammar and level-only contracts.
- Candidate files to inspect: authored wave resources created from Child 01 schemas, enemy Level 1 data, the progression profile, role Guard profiles from the Enemy Combat Roles And Counterpressure plan, combat projection/debug readouts, and unit or simulation fixtures for representative levels and waves.

## Non-Goals

1. No creation or redesign of enemy mechanics, bespoke boss behavior, post-demo group escalation, or enemy-pressure rewards; this child consumes the completed production roster.
2. No guarantee that wave 21-plus runs remain fair or consistently survivable.
3. No rebalance of player artifacts or design of replacement trade-off curses.
4. No final leaderboard, score, or meta-progression system for endless survival.

## Acceptance Criteria

1. Waves 1–10 deliver the parent plan's roster progression and a fair, readable demo finale using explicit authored groups.
2. Wave 11 onward uses one unchanged encounter template, with observed difficulty differences attributable only to enemy level and the explicit Guard tier beginning at wave 21.
3. Representative stat projections and Guard tiers remain numerically valid beyond wave 21 without overflow, negative values, or invulnerable Defense behavior.
4. Level 10 begins the stronger growth segment without making the official wave-10 completion target unfair.
5. Playtests support waves 11–20 as increasingly unforgiving mastery play and wave 21 onward as intentionally rapid-death overtime.
6. HP, Guard tiers, and Defense do not turn endless waves into cleanup attrition before Damage delivers the intended lethal pressure.
