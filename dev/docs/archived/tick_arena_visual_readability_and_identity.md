# Tick Arena Visual Readability And Identity

## Goal

Establish a readable visual direction for the tick arena so the game reads as grid-based ninja body-position combat instead of a generic cute block roguelite. The plan prioritizes combat readability, state silhouettes, fixed-Mobility class identity, and honest attack presentation before final polish.

## Requirements

1. Visual identity must support the core fantasy of a miniature ninja duel board: directional mobility, guard timing, flanking, and readable enemy intent are more important than decorative Japanese flavor.
2. Enemy presentation must communicate state, facing, and attack intent before adding pattern volume, because unreadable variety would make the tick combat feel like chaos build noise.
3. The baseline small enemy family should become the main content multiplier through readable pattern variants, while special enemy bodies stay reserved for behavior that cannot be expressed through the shared small-body language.
4. Character classes must define starting combat identity through Speed profile, one fixed class-exclusive Mobility, a distinct player body and weapon cue, and Mobility-specific Major eligibility; normal attacks stay on the shared one-cell baseline for the initial class slice.
5. The visual language should avoid copying Demon Lord-style rounded block monsters, sticker-like UI, and pure colored telegraph rectangles while still borrowing the principle of extremely readable grid intent.

## Design

Visual north star: miniature ninja duel board. The board can borrow from dojo, scroll, talisman, lacquer, ink, blade-trail, and tatami language, but every visual choice must first answer whether the player can read the next tactical decision.

Enemy readability hierarchy:

| Priority         | Meaning                                                                                            |
| ---------------- | -------------------------------------------------------------------------------------------------- |
| State            | Idle, moving, preparing, attacking, staggered, and dead should read without relying on text.       |
| Facing           | The player must know which side is front, side, and back because guard/flank payoff depends on it. |
| Attack intent    | Telegraphs and body pose should agree so danger tiles feel authored, not arbitrary.                |
| Pattern identity | Color/mark/weapon variants can multiply content only after state and facing read cleanly.          |

Player/class identity hierarchy:

| Priority          | Meaning                                                                                                                     |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Aim marker        | The tick player has no combat facing, so the visible weapon cue follows the resolved attack aim rather than body direction. |
| Mobility identity | Ninja owns Dash and Viking owns Smash; classes do not share or replace Mobility in the initial model.                       |
| Speed profile     | Ninja fills 20 Speed per eligible action and Viking fills 10 before reward bonuses.                                         |
| Major pool        | Legendary effects extend the selected class's fixed Mobility and never replace it with another class's verb.                |

Every initial class uses the same one-cell cardinal normal attack. Normal-attack footprint variants are frozen in the TODO Draft so class readability can be judged from Mobility, Speed, player silhouette, and Mobility-specific Majors without another simultaneous combat-axis change.

Initial classes:

| Class  | Body identity                      | Weapon/attack cue | Speed fill | Fixed Mobility |
| ------ | ---------------------------------- | ----------------- | ---------- | -------------- |
| Ninja  | Green Ninja                       | Katana            | 20         | Dash           |
| Viking | Shaman body as placeholder Viking | Hammer            | 10         | Smash          |

Child overview:

| Child | Focus                                  | Current document                                                                                 |
| ----- | -------------------------------------- | ------------------------------------------------------------------------------------------------ |
| 01    | Enemy Visual Runtime Scaffold          | `tick_arena_visual_readability_01_enemy_visual_runtime_scaffold.implementation_spec.md`          |
| 02    | Enemy-Specific Visual Presenters       | `tick_arena_visual_readability_02_enemy_specific_visual_presenters.implementation_spec.md`       |
| 03    | SmallEnemy Visible Attack Variants     | `tick_arena_visual_readability_03_small_enemy_visible_attack_variants.implementation_spec.md`    |
| 03a   | Support Pool Identity Cleanup          | `tick_arena_visual_readability_03a_support_pool_identity_cleanup.implementation_spec.md`         |
| 03b   | SmallEnemy Offsets And Palette Swap    | `tick_arena_visual_readability_03b_small_enemy_offsets_palette_swap.implementation_spec.md`      |
| 04    | Mobility-Locked Character Classes      | `tick_arena_visual_readability_04_character_classes.implementation_spec.md`                      |

Recommended landing order: land the initial Ninja/Viking class slice after the enemy readability children, then let the separate enemy-mobility plan own ChargeEnemy, DashEnemy, and Viking Smash Knockback sequencing around one forced-displacement contract. The baseline enemy path should continue to prioritize one readable representative pose per state plus short semantic tween/VFX cues; multi-frame animation is reserved for long windups, player identity, bosses, or special bodies that need custom presentation.

## Non-Goals

1. Do not create a full art bible, final palette, final sprite pipeline, or final card art in this plan.
2. Do not redesign permanent progression, unlock economy, or enemy spawn weighting here.
3. Do not add normal-attack footprint variants or Samurai in the initial class slice; both remain deferred in the TODO Draft.
4. Do not use broad Japanese theming as a substitute for concrete combat readability.

## Acceptance Criteria

1. Enemy bodies communicate state, facing, and attack intent before the game depends on expanded pattern volume.
2. Baseline small enemy variants create multiple tactical questions while staying readable in low enemy counts.
3. Ninja and Viking read as different starting identities through Speed, fixed Mobility, body silhouette, weapon cue, and eligible Majors while sharing the honest one-cell normal attack.
4. A class never replaces its Mobility or rolls another Mobility's exclusive Major effects.
5. The tick arena's screenshots read closer to a readable ninja-grid duel than a generic block roguelite.
