# Tick Arena Visual Readability And Identity

## Goal

Establish a readable visual direction for the tick arena so the game reads as grid-based ninja body-position combat instead of a generic cute block roguelite. The plan prioritizes combat readability, state silhouettes, and class identity before final polish.

## Requirements

1. Visual identity must support the core fantasy of a miniature ninja duel board: directional mobility, guard timing, flanking, and readable enemy intent are more important than decorative Japanese flavor.
2. Enemy presentation must communicate state, facing, and attack intent before adding pattern volume, because unreadable variety would make the tick combat feel like chaos build noise.
3. The baseline small enemy family should become the main content multiplier through readable pattern variants, while special enemy bodies stay reserved for behavior that cannot be expressed through the shared small-body language.
4. Character classes should define starting combat identity through Speed profile, normal attack shape, default mobility payload, and one class-locked perk; they are not just weapon skins.
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

| Priority            | Meaning                                                                                                                 |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Aim marker          | The tick player has no combat facing, so the visible weapon/marker points at current aim rather than body direction.    |
| Mobility fantasy    | Each class should make one main mobility style feel intentional, such as fast chain dash, counter dash, or heavy smash. |
| Normal attack shape | Class attack shape should change tactical questions, not merely damage numbers.                                         |
| Perk                | A class-locked perk should reinforce the mobility fantasy and avoid general roguelite soup.                             |

Child overview:

| Child | Focus                                  | Current document                                                                                 |
| ----- | -------------------------------------- | ------------------------------------------------------------------------------------------------ |
| 01    | Enemy Visual Runtime Scaffold          | `tick_arena_visual_readability_01_enemy_visual_runtime_scaffold.implementation_spec.md`          |
| 02    | Enemy-Specific Visual Presenters | `tick_arena_visual_readability_02_enemy_specific_visual_presenters.implementation_spec.md` |
| 03    | SmallEnemy Visible Attack Variants     | `tick_arena_visual_readability_03_small_enemy_visible_attack_variants.implementation_spec.md`    |
| 03a   | Support Pool Identity Cleanup          | `tick_arena_visual_readability_03a_support_pool_identity_cleanup.implementation_spec.md`         |
| 03b   | SmallEnemy Offsets And Palette Swap    | `tick_arena_visual_readability_03b_small_enemy_offsets_palette_swap.implementation_spec.md`      |
| 04    | Character Classes                      | `tick_arena_visual_readability_04_character_classes.sketch.md`                                   |

Recommended landing order: first prove the enemy visual runtime scaffold on the baseline small enemy body with Ninja Adventure-style 16x16 source sprites rendered at integer scale, then turn the scaffold into a shared semantic presenter contract with enemy-specific presenter implementations, then clean up the support pool identity by freezing PuffEnemy and moving ChargeEnemy onto a Skull body while expanding the small-body language into visible attack variants, then tighten the small-body variant implementation with local offset footprints and palette-swapped identity colors, then add character classes once enemies and telegraphs can support differentiated player kits. The baseline enemy path should prioritize one readable representative pose per state plus short semantic tween/VFX cues; multi-frame animation is reserved for long windups, player identity, bosses, or special bodies that need custom presentation.

## Non-Goals

1. Do not create a full art bible, final palette, final sprite pipeline, or final card art in this plan.
2. Do not redesign reward economy, permanent progression, or enemy spawn weighting here.
3. Do not add new combat rules only for visual distinction; visual work must express the existing tick-combat identity first.
4. Do not use broad Japanese theming as a substitute for concrete combat readability.

## Acceptance Criteria

1. Enemy bodies communicate state, facing, and attack intent before the game depends on expanded pattern volume.
2. Baseline small enemy variants can create multiple tactical questions while staying readable in low enemy counts.
3. Character class concepts are framed as bundled starting identities centered on mobility fantasy and attack shape.
4. The tick arena's screenshots read closer to a readable ninja-grid duel than a generic block roguelite.
