# Tick Arena Visual Readability 02: Small Enemy Pattern Director

Parent Plan: `tick_arena_visual_readability_and_identity.md`

## Goal

Explore making SmallEnemy the main spawn body and content multiplier through readable attack-pattern identities, after the enemy sprite readability scaffold gives those variants enough visual language to stay clear.

## Summary

This child should come after the sprite scaffold. The direction is to add roughly six to eight SmallEnemy pattern identities through attack data and body/mark color language, keeping SmallEnemy at about 60 percent or more of base spawns. This gives the game tactical variety without immediately adding many new enemy scenes.

Codebase context gathered so far suggests SmallEnemy already selects one attack profile from authored enemy data, and the shared attack data supports line, wide, square, and full-line cell shapes. The later implementation spec should verify whether additional identity metadata belongs in enemy data, spawn entries, or separate scene variants.

## Sketch

- Candidate shape: define a small set of named SmallEnemy pattern identities, each pairing one attack profile with a readable body color/mark/silhouette accent.
- Pattern identities should ask different tactical questions: lane denial, short wide threat, close square pressure, long line pressure, delayed guard bait, flank-punishable stance, and other simple geometry variants.
- Avoid "random attack every enemy" if it makes silhouettes lie. A player should learn that a visible variant usually means a stable threat family.
- Current attack data can likely carry much of the mechanical variety through cell shape and tuning, but the later spec should verify whether pattern identity needs display metadata such as color, marker, or spawn label.
- Spawn weighting belongs near this child but should not be swallowed by it unless the later spec finds the current uniform support selection too small to test pattern mix. If weighting grows, it can become its own child or borrow the existing Enemy Spawn Ratio Data Drive draft.
- Pattern count should start with readable coverage, not completionism. Six good variants are better than eight that blur together.
- Candidate files to inspect at spec time: `game/entities/enemies/data/small_enemy.tres`, enemy attack data definitions, SmallEnemy scene/script, wave support spawn selection, and any spawn-planner assumptions about enemy scene identity.

## Non-Goals

1. No final sprite polish beyond the identity marks needed to distinguish pattern families.
2. No boss or elite redesign.
3. No broad enemy spawn economy rewrite unless the implementation spec deliberately scopes it.
4. No character class work in this child.

## Acceptance Criteria

1. SmallEnemy variants produce multiple readable tactical questions from the same main enemy body.
2. Pattern identity is visible before the attack detonates and does not depend on memorizing hidden data.
3. SmallEnemy remains the dominant support enemy family, supporting low-count readable waves.
4. Expanded pattern volume does not make telegraphs, facing, or guard decisions harder to parse.
